import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:svga_previewer/models/animation_metadata.dart';
import 'package:svga_previewer/models/animation_type.dart';
import 'package:svga_previewer/models/display_mode.dart';
import 'package:svga_previewer/models/frame_info.dart';
import 'package:svga_previewer/services/file_downloader.dart';
import 'package:svga_previewer/services/parsers/animation_parser.dart';
import 'package:svga_previewer/services/parsers/lottie_parser.dart';
import 'package:svga_previewer/services/parsers/svga_parser.dart';
import 'package:svga_previewer/services/temp_file_manager.dart';
import 'package:svga_previewer/services/user_preferences_manager.dart';
import 'package:svga_previewer/utils/file_type_detector.dart';

/// 动画视图模型
/// 负责管理动画预览器的状态，协调各个服务模块完成文件解析、下载等功能
class AnimationViewModel extends ChangeNotifier {
  // 解析器实例
  final List<AnimationParser> _parsers = [
    SVGAParser(),
    LottieParser(),
  ];

  // 文件下载器
  final FileDownloader _downloader = FileDownloader();

  // 状态数据
  List<File> _frames = [];
  List<FrameInfo> _frameInfos = [];
  int _currentFrameIndex = 0;
  bool _isDragging = false;
  File? _animationFile;
  AnimationType? _animationType;
  String? _currentFileName;
  String? _lottieImagesDir;
  AnimationMetadata? _metadata;

  // UI 设置
  Color _previewBackgroundColor = Colors.transparent;
  bool _showBorder = true;
  DisplayMode _mode = DisplayMode.showAll;
  bool _allowDrawingOverflow = true;
  double _playbackSpeed = 1.0;

  // 下载状态
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;

  // Lottie 播放控制（通过回调函数实现）
  VoidCallback? _lottiePlayCallback;
  VoidCallback? _lottiePauseCallback;
  Function(double)? _lottieSeekCallback;
  bool _lottieIsPlaying = false;
  double _lottieCurrentValue = 0.0;
  int _lottieTotalFrames = 0;

  // Getters
  List<File> get frames => _frames;
  List<FrameInfo> get frameInfos => _frameInfos;
  int get currentFrameIndex => _currentFrameIndex;
  bool get isDragging => _isDragging;
  File? get currentFrame =>
      _frames.isNotEmpty ? _frames[_currentFrameIndex] : null;
  FrameInfo? get currentFrameInfo =>
      _frameInfos.isNotEmpty ? _frameInfos[_currentFrameIndex] : null;
  File? get svgaFile =>
      _animationType == AnimationType.svga ? _animationFile : null;
  File? get lottieFile =>
      _animationType == AnimationType.lottie ? _animationFile : null;
  String? get lottieImagesDir => _lottieImagesDir;
  AnimationType? get animationType => _animationType;
  String? get currentFileName => _currentFileName;
  int get svgaFileSizeBytes => _metadata?.fileSizeBytes ?? 0;
  String get svgaFileSizeText => _metadata?.fileSizeText ?? '0B';
  double get fps => _metadata?.fps ?? 0.0;
  double get duration => _metadata?.duration ?? 0.0;
  double get memoryUsage => _metadata?.memoryUsageMB ?? 0.0;
  double get totalFileSizeMB => _metadata?.totalFileSizeMB ?? 0.0;
  int get totalFrames => _metadata?.totalFrames ?? 0;
  int get frameWidth => _metadata?.width ?? 0;
  int get frameHeight => _metadata?.height ?? 0;
  Color get previewBackgroundColor => _previewBackgroundColor;
  bool get showBorder => _showBorder;
  DisplayMode get mode => _mode;
  bool get allowDrawingOverflow => _allowDrawingOverflow;
  double get playbackSpeed => _playbackSpeed;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get downloadError => _downloadError;

  // Lottie 播放状态
  bool get lottieIsPlaying => _lottieIsPlaying;
  double get lottieCurrentValue => _lottieCurrentValue;
  int get lottieTotalFrames => _lottieTotalFrames;

  /// 从缓存加载用户偏好设置
  Future<void> loadUserPreferences() async {
    final prefs = await UserPreferencesManager.loadPreferences();
    _mode = prefs.mode;
    _showBorder = prefs.showBorder;
    _previewBackgroundColor = prefs.backgroundColor;
    notifyListeners();
  }

  /// 保持向后兼容性的方法
  Future<void> loadModeFromCache() async {
    await loadUserPreferences();
  }

  /// 清理所有状态
  Future<void> clearState() async {
    print('开始清理状态...');
    _frames.clear();
    _frameInfos.clear();
    _currentFrameIndex = 0;
    _animationFile = null;
    _animationType = null;
    _currentFileName = null;
      _lottieImagesDir = null;
      _metadata = null;
      _playbackSpeed = 1.0;

      // 清理 Lottie 控制回调
      _lottiePlayCallback = null;
      _lottiePauseCallback = null;
      _lottieSeekCallback = null;
      _lottieIsPlaying = false;
      _lottieCurrentValue = 0.0;
      _lottieTotalFrames = 0;

    // 取消下载
    _downloader.cancel();
    _isDownloading = false;
    _downloadProgress = 0.0;
    _downloadError = null;

    print('内存状态已清理');

    // 清理临时文件
    await TempFileManager.clearAllTempFiles();

    notifyListeners();
    print('状态清理完成');
  }

  /// 设置拖拽状态
  void setDragging(bool value) {
    _isDragging = value;
    notifyListeners();
  }

  /// 设置当前帧索引
  void setCurrentFrameIndex(int index) {
    if (index >= 0 && index < _frames.length) {
      _currentFrameIndex = index;
      notifyListeners();
    }
  }

  /// 通用的动画文件处理方法，根据文件扩展名自动识别类型
  Future<void> processAnimationFile(String filePath,
      {bool clearBeforeProcess = true}) async {
    if (clearBeforeProcess) {
      await clearState();
    }

    // 查找合适的解析器
    AnimationParser? parser;
    for (final p in _parsers) {
      if (p.canParse(filePath)) {
        parser = p;
        break;
      }
    }

    // 如果是 ZIP 文件，需要先检测是否为 Lottie 格式
    if (parser == null && path.extension(filePath).toLowerCase() == '.zip') {
      try {
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        if (FileTypeDetector.isLottieZip(archive)) {
          parser = LottieParser();
        } else {
          throw Exception('ZIP 文件不是有效的 Lottie 格式（未找到 data.json）');
        }
      } catch (e) {
        if (e.toString().contains('不是有效的 Lottie 格式')) {
          rethrow;
        }
        throw Exception('无法读取 ZIP 文件: $e');
      }
    }

    if (parser == null) {
      final ext = path.extension(filePath).toLowerCase();
      throw Exception('不支持的文件格式: $ext');
    }

    // 解析文件
    try {
      final result = await parser.parse(filePath);

      // 更新状态
      _animationType = result.animationType;
      _animationFile = result.animationFile;
      _frames = result.frames;
      _frameInfos = result.frameInfos;
      _currentFrameIndex = 0;
      _currentFileName = path.basename(filePath);
      _metadata = result.metadata;
      _lottieImagesDir = result.lottieImagesDir;

      print('帧数组已更新，长度: ${_frames.length}');

      Future.microtask(() {
        notifyListeners();
        print('UI更新完成');
      });
    } catch (e) {
      print('处理动画文件时出错: $e');
      await clearState();
      rethrow;
    }
  }

  /// 设置预览背景颜色
  Future<void> setPreviewBackgroundColor(Color color) async {
    _previewBackgroundColor = color;
    notifyListeners();
    await UserPreferencesManager.saveBackgroundColor(color);
  }

  /// 设置边框显示
  Future<void> setShowBorder(bool value) async {
    _showBorder = value;
    notifyListeners();
    await UserPreferencesManager.saveShowBorder(value);
  }

  /// 设置显示模式
  Future<void> setMode(DisplayMode mode) async {
    _mode = mode;
    notifyListeners();
    await UserPreferencesManager.saveMode(mode);
  }

  /// 设置是否允许绘制溢出
  void setAllowDrawingOverflow(bool value) {
    _allowDrawingOverflow = value;
    notifyListeners();
  }

  /// 设置播放速度
  void setPlaybackSpeed(double speed) {
    if (speed < 0.1 || speed > 10.0) {
      print('警告：播放速度设置超出有效范围 (0.1 - 10.0)，当前速度保持不变。');
      return;
    }
    if (_playbackSpeed == speed) return;

    _playbackSpeed = speed;
    print("播放速度已设置: ${speed}x");
    notifyListeners();
  }

  /// 注册 Lottie 播放控制回调
  void registerLottieCallbacks({
    VoidCallback? onPlay,
    VoidCallback? onPause,
    Function(double)? onSeek,
  }) {
    _lottiePlayCallback = onPlay;
    _lottiePauseCallback = onPause;
    _lottieSeekCallback = onSeek;
  }

  /// 更新 Lottie 播放状态
  void updateLottiePlayState(bool isPlaying, double currentValue, int totalFrames) {
    _lottieIsPlaying = isPlaying;
    _lottieCurrentValue = currentValue;
    _lottieTotalFrames = totalFrames;
    notifyListeners();
  }

  /// 控制 Lottie 播放/暂停
  void toggleLottiePlay() {
    if (_lottieIsPlaying) {
      _lottiePauseCallback?.call();
    } else {
      _lottiePlayCallback?.call();
    }
  }

  /// 控制 Lottie 跳转到指定位置
  void seekLottie(double value) {
    _lottieSeekCallback?.call(value);
  }

  /// 从 URL 下载文件
  Future<void> downloadFromUrl(String url) async {
    if (_isDownloading) return;

    await clearState();

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadError = null;
    notifyListeners();

    try {
      final downloadedPath = await _downloader.download(
        url,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
        onError: (error) {
          _downloadError = error;
          _isDownloading = false;
          notifyListeners();
        },
      );

      if (downloadedPath == null) {
        // 错误已在 onError 回调中处理
        return;
      }

      _downloadProgress = 1.0;
      _isDownloading = false;
      notifyListeners();

      // 根据文件类型决定是否解析
      if (FileTypeDetector.isSupportedAnimationFile(downloadedPath)) {
        try {
          print('开始解析下载的文件...');
          await processAnimationFile(downloadedPath, clearBeforeProcess: false);
          _downloadError = null;
          print('文件解析成功');
        } catch (e) {
          print('解析失败: $e');
          _downloadError = '解析失败: $e';
          notifyListeners();
        }
      } else {
        print('下载的文件不是支持的动画格式');
        _downloadError = null;
        notifyListeners();
      }
    } catch (e) {
      print('下载异常: $e');
      _downloadError = '下载失败: $e';
      _isDownloading = false;
      notifyListeners();
    }
  }

  /// 取消下载
  Future<void> cancelDownload() async {
    _downloader.cancel();
  }

  /// 清理下载状态（用于重新打开对话框时）
  void clearDownloadState() {
    _isDownloading = false;
    _downloadProgress = 0.0;
    _downloadError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _downloader.cancel();
    super.dispose();
  }
}

