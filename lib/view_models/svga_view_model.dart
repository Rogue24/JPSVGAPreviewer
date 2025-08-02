import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:ui';
import 'dart:async';

enum DisplayMode {
  showAll,
  showTop,
  showBottom,
}

// 帧信息类
class FrameInfo {
  final File file;
  final int fileSizeBytes;
  final double memoryUsageMB;
  final int width;
  final int height;
  
  FrameInfo({
    required this.file,
    required this.fileSizeBytes,
    required this.memoryUsageMB,
    required this.width,
    required this.height,
  });
  
  String get fileSizeText {
    if (fileSizeBytes < 1024) {
      return '${fileSizeBytes}B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}

// SVGA视图模型，用于管理状态
class SVGAViewModel extends ChangeNotifier {
  static const _mode_key = 'user_mode';
  static const _show_border_key = 'show_border';
  static const _background_color_key = 'background_color';

  List<File> _frames = [];
  List<FrameInfo> _frameInfos = []; // 帧信息列表
  int _currentFrameIndex = 0;
  bool _isDragging = false;
  File? _svgaFile;
  String? _currentFileName;
  int _svgaFileSizeBytes = 0; // SVGA文件大小
  double _fps = 0;  
  double _duration = 0;  
  double _memoryUsage = 0;  
  double _totalFileSizeMB = 0; // 临时文件总大小
  int _totalFrames = 0;
  int _frameWidth = 0;
  int _frameHeight = 0;
  Color _previewBackgroundColor = Colors.transparent;
  bool _showBorder = true;  // 是否显示边框
  DisplayMode _mode = DisplayMode.showAll;
  bool _allowDrawingOverflow = true; // 是否允许绘制溢出
  double _playbackSpeed = 1.0; // 播放速度，默认1.0倍速
  
  // 播放速度控制相关
  Timer? _speedChangeDebounceTimer; // 防抖计时器

  List<File> get frames => _frames;
  List<FrameInfo> get frameInfos => _frameInfos;
  int get currentFrameIndex => _currentFrameIndex;
  bool get isDragging => _isDragging;
  File? get currentFrame => _frames.isNotEmpty ? _frames[_currentFrameIndex] : null;
  FrameInfo? get currentFrameInfo => _frameInfos.isNotEmpty ? _frameInfos[_currentFrameIndex] : null;
  File? get svgaFile => _svgaFile;
  String? get currentFileName => _currentFileName;
  int get svgaFileSizeBytes => _svgaFileSizeBytes;
  String get svgaFileSizeText {
    if (_svgaFileSizeBytes < 1024) {
      return '${_svgaFileSizeBytes}B';
    } else if (_svgaFileSizeBytes < 1024 * 1024) {
      return '${(_svgaFileSizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(_svgaFileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
  double get fps => _fps;
  double get duration => _duration;
  double get memoryUsage => _memoryUsage;
  double get totalFileSizeMB => _totalFileSizeMB;
  int get totalFrames => _totalFrames;
  int get frameWidth => _frameWidth;
  int get frameHeight => _frameHeight;
  Color get previewBackgroundColor => _previewBackgroundColor;
  bool get showBorder => _showBorder;
  DisplayMode get mode => _mode;
  bool get allowDrawingOverflow => _allowDrawingOverflow;
  double get playbackSpeed => _playbackSpeed;

  // 从缓存加载用户偏好设置
  Future<void> loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 加载显示模式
    final modeString = prefs.getString(_mode_key);
    if (modeString != null) {
      _mode = DisplayMode.values.firstWhere(
        (e) => e.name == modeString,
        orElse: () => DisplayMode.showAll,
      );
    }
    
    // 加载边框显示设置，默认为true
    _showBorder = prefs.getBool(_show_border_key) ?? true;
    
    // 加载背景颜色设置，默认为透明
    final colorValue = prefs.getInt(_background_color_key);
    if (colorValue != null) {
      _previewBackgroundColor = Color(colorValue);
    } else {
      _previewBackgroundColor = Colors.transparent;
    }

    notifyListeners();
  }

  // 保持向后兼容性的方法
  Future<void> loadModeFromCache() async {
    await loadUserPreferences();
  }

  // 清理所有状态
  Future<void> clearState() async {
    print('开始清理状态...');
    _frames.clear();
    _frameInfos.clear();
    _currentFrameIndex = 0;
    _svgaFile = null;
    _currentFileName = null;
    _svgaFileSizeBytes = 0;
    _fps = 0;
    _duration = 0;
    _memoryUsage = 0;
    _totalFileSizeMB = 0;
    _totalFrames = 0;
    
    // 清理播放速度控制相关资源
    _speedChangeDebounceTimer?.cancel();
    _speedChangeDebounceTimer = null;
    
    // 重置播放速度为默认值
    _playbackSpeed = 1.0;
    
    print('内存状态已清理');
    
    try {
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory('${tempDir.path}/svga_frames');
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
        print('临时目录已删除');
      }
    } catch (e) {
      print('清理临时目录失败: $e');
    }
    
    notifyListeners();
    print('状态清理完成');
  }

  void setDragging(bool value) {
    _isDragging = value;
    notifyListeners();
  }

  void setCurrentFrameIndex(int index) {
    if (index >= 0 && index < _frames.length) {
      _currentFrameIndex = index;
      notifyListeners();
    }
  }

  Future<void> processSVGAFile(String filePath) async {
    print('开始处理新的SVGA文件: ${path.basename(filePath)}');
    
    try {
      await clearState();
      
      imageCache.clear();
      imageCache.clearLiveImages();
      print('图片缓存已清空');

      _currentFileName = path.basename(filePath);
      
      // 获取SVGA文件大小
      _svgaFile = File(filePath);
      if (_svgaFile != null && await _svgaFile!.exists()) {
         _svgaFileSizeBytes = await _svgaFile!.length();
        print('SVGA文件大小: $_svgaFileSizeBytes bytes (${svgaFileSizeText})');
      }
     
      
      notifyListeners();
      
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory('${tempDir.path}/svga_frames');
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
      }
      await framesDir.create(recursive: true);
      print('创建新的临时目录: ${framesDir.path}');

      print('设置新的SVGA文件路径: ${_svgaFile?.path}');
      
      final parser = SVGAParser();
      final videoItem = await parser.decodeFromBuffer(
        await File(filePath).readAsBytes(),
      );
      print('SVGA文件解析完成');

      final images = videoItem.images;
      
      _totalFrames = videoItem.params.frames;
      _fps = videoItem.params.fps.toDouble();
      _duration = _totalFrames / _fps;
      print('FPS: $_fps, 持续时间: $_duration秒');

      _frameWidth = videoItem.params.viewBoxWidth.toInt();
      _frameHeight = videoItem.params.viewBoxHeight.toInt();

      final List<File> tempFrames = [];
      final List<FrameInfo> tempFrameInfos = [];
      double totalFileSizeBytes = 0;

      print('开始提取帧图片，总数：${images.length}');
      var index = 0;
      for (var entry in images.entries) {
        if (entry.value.isNotEmpty) {
          try {
            final codec = await instantiateImageCodec(Uint8List.fromList(entry.value));
            final frame = await codec.getNextFrame();
            final byteData = await frame.image.toByteData(format: ImageByteFormat.png);
            
            if (byteData != null) {
              final frameFile = File('${framesDir.path}/${entry.key}');
              await frameFile.writeAsBytes(byteData.buffer.asUint8List());
              print('成功写入帧 $index 到文件: ${frameFile.path}');
              
              // 计算内存占用
              final frameMemoryMB = (frame.image.width * frame.image.height * 4) / (1024 * 1024);
              _memoryUsage += frameMemoryMB;
              
              // 获取文件大小
              final fileSizeBytes = await frameFile.length();
              totalFileSizeBytes += fileSizeBytes;
              
              print('当前帧内存占用: ${frameMemoryMB.toStringAsFixed(2)} MB，文件大小: $fileSizeBytes bytes');
              
              if (await frameFile.exists()) {
                tempFrames.add(frameFile);
                
                // 创建帧信息
                final frameInfo = FrameInfo(
                  file: frameFile,
                  fileSizeBytes: fileSizeBytes,
                  memoryUsageMB: frameMemoryMB,
                  width: frame.image.width,
                  height: frame.image.height,
                );
                tempFrameInfos.add(frameInfo);
                
                print('添加第 ${index + 1} 帧到临时数组，文件大小: ${frameInfo.fileSizeText}');
              } else {
                print('警告：帧文件未成功创建: ${frameFile.path}');
              }
              index++;
            }
          } catch (e) {
            print('处理帧 $index 时出错: $e');
          }
        }
      }

      if (tempFrames.isEmpty) {
        print('未能从SVGA文件中提取到任何图片');
      } else {
        print('成功提取了 ${tempFrames.length} 帧图片');
        _totalFileSizeMB = totalFileSizeBytes / (1024 * 1024);
        print('临时文件总大小: ${_totalFileSizeMB.toStringAsFixed(1)} MB');
      }
      imageCache.clear();
      imageCache.clearLiveImages();
      print('再次清空图片缓存');
      
      _frames = List.from(tempFrames);
      _frameInfos = List.from(tempFrameInfos);
      _currentFrameIndex = 0;
      print('帧数组已更新，长度: ${_frames.length}');
      
      Future.microtask(() {
        notifyListeners();
        print('UI更新完成');
      });
    } catch (e) {
      print('处理SVGA文件时出错: $e');
      print(e.toString());
      await clearState();
    }
  }

  Future<void> setPreviewBackgroundColor(Color color) async {  // 更新方法名
    _previewBackgroundColor = color;
    notifyListeners();
    
    // 保存到本地存储
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_background_color_key, color.value);
  }

  Future<void> setShowBorder(bool value) async {
    _showBorder = value;
    notifyListeners();
    
    // 保存到本地存储
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_show_border_key, value);
  }

  Future<void> setMode(DisplayMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mode_key, mode.name);
  }

  void setAllowDrawingOverflow(bool value) {
    _allowDrawingOverflow = value;
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    if (speed < 0.1 || speed > 10.0) { // 添加参数验证
      print('警告：播放速度设置超出有效范围 (0.1 - 10.0)，当前速度保持不变。');
      return;
    }
    if (_playbackSpeed == speed) return; // 避免重复设置相同速度
    
    _playbackSpeed = speed;
    print("播放速度已设置: ${speed}x");
    notifyListeners(); // 通知UI更新，UI组件负责应用速度到controller
  }

  @override
  void dispose() {
    _speedChangeDebounceTimer?.cancel();
    super.dispose();
  }
} 