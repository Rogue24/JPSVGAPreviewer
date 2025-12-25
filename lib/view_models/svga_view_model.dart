import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:ui';
import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:archive/archive.dart';

enum DisplayMode {
  showAll,
  showTop,
  showBottom,
}

enum AnimationType {
  svga,
  lottie,
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
  File? _lottieFile; // Lottie 文件
  AnimationType? _animationType; // 当前动画类型
  String? _currentFileName;
  String? _lottieImagesDir; // Lottie 图片资源临时目录
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
  
  // 下载相关
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;
  String? _downloadedFilePath;
  CancelToken? _downloadCancelToken;

  List<File> get frames => _frames;
  List<FrameInfo> get frameInfos => _frameInfos;
  int get currentFrameIndex => _currentFrameIndex;
  bool get isDragging => _isDragging;
  File? get currentFrame => _frames.isNotEmpty ? _frames[_currentFrameIndex] : null;
  FrameInfo? get currentFrameInfo => _frameInfos.isNotEmpty ? _frameInfos[_currentFrameIndex] : null;
  File? get svgaFile => _svgaFile;
  File? get lottieFile => _lottieFile;
  String? get lottieImagesDir => _lottieImagesDir; // Lottie 图片资源目录
  AnimationType? get animationType => _animationType;
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
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get downloadError => _downloadError;

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
    _lottieFile = null;
    _animationType = null;
    _currentFileName = null;
    _svgaFileSizeBytes = 0;
    _lottieImagesDir = null;
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
    
    // 取消并重置下载状态
    _downloadCancelToken?.cancel('clearState');
    _downloadCancelToken = null;
    _isDownloading = false;
    _downloadProgress = 0.0;
    _downloadError = null;
    await _removeDownloadedFile();
    
    print('内存状态已清理');
    
    try {
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory('${tempDir.path}/svga_frames');
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
        print('临时目录已删除');
      }
      final lottieFramesDir = Directory('${tempDir.path}/lottie_frames');
      if (await lottieFramesDir.exists()) {
        await lottieFramesDir.delete(recursive: true);
        print('Lottie临时目录已删除');
      }
      final lottieExtractedDir = Directory('${tempDir.path}/lottie_extracted');
      if (await lottieExtractedDir.exists()) {
        await lottieExtractedDir.delete(recursive: true);
        print('Lottie提取目录已删除');
      }
      
      // 清理临时 JSON 文件（lottie_*.json）
      try {
        final tempDirList = await tempDir.list().toList();
        for (final entity in tempDirList) {
          if (entity is File && entity.path.contains('lottie_') && entity.path.endsWith('.json')) {
            await entity.delete();
            print('删除临时 JSON 文件: ${entity.path}');
          }
          // 同时清理可能存在的 images 目录（在 JSON 文件旁边）
          if (entity is Directory && entity.path.contains('lottie_') && path.basename(entity.path) == 'images') {
            await entity.delete(recursive: true);
            print('删除临时 images 目录: ${entity.path}');
          }
        }
      } catch (e) {
        print('清理临时 JSON 文件失败: $e');
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

  // 通用的动画文件处理方法，根据文件扩展名自动识别类型
  Future<void> processAnimationFile(String filePath, {bool clearBeforeProcess = true}) async {
    final ext = path.extension(filePath).toLowerCase();
    if (ext == '.svga') {
      await processSVGAFile(filePath, clearBeforeProcess: clearBeforeProcess);
    } else if (ext == '.json' || ext == '.lottie' || filePath.toLowerCase().endsWith('.json.gz')) {
      await processLottieFile(filePath, clearBeforeProcess: clearBeforeProcess);
    } else if (ext == '.zip') {
      // 检测 ZIP 文件是否为 Lottie 格式
      try {
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        if (_isLottieZip(archive)) {
          await processLottieFile(filePath, clearBeforeProcess: clearBeforeProcess);
        } else {
          throw Exception('ZIP 文件不是有效的 Lottie 格式（未找到 data.json）');
        }
      } catch (e) {
        if (e.toString().contains('不是有效的 Lottie 格式')) {
          rethrow;
        }
        throw Exception('无法读取 ZIP 文件: $e');
      }
    } else {
      throw Exception('不支持的文件格式: $ext');
    }
  }

  Future<void> processSVGAFile(String filePath, {bool clearBeforeProcess = true}) async {
    print('开始处理新的SVGA文件: ${path.basename(filePath)}');
    
    try {
      if (clearBeforeProcess) {
        await clearState();
      }
      
      _animationType = AnimationType.svga;
      imageCache.clear();
      imageCache.clearLiveImages();
      print('图片缓存已清空');

      _currentFileName = path.basename(filePath);
      
      // 获取SVGA文件大小
      _svgaFile = File(filePath);
      if (_svgaFile != null && await _svgaFile!.exists()) {
         _svgaFileSizeBytes = await _svgaFile!.length();
        print('SVGA文件大小: $_svgaFileSizeBytes bytes ($svgaFileSizeText)');
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
      
      final parser = const SVGAParser();
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

  // 检测 ZIP 文件是否为 Lottie 格式
  bool _isLottieZip(Archive archive) {
    for (final file in archive) {
      final fileName = file.name.toLowerCase();
      if (fileName == 'data.json' || 
          (fileName.endsWith('.json') && fileName.contains('data'))) {
        return true;
      }
    }
    return false;
  }

  // 复制目录
  Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    
    await for (final entity in source.list(recursive: false)) {
      final targetPath = path.join(target.path, path.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }

  // 提取 ZIP 文件中的图片资源到临时目录
  Future<String?> _extractLottieImages(Archive archive, String tempDirPath) async {
    final imagesDir = Directory('$tempDirPath/images');
    bool hasImages = false;
    
    for (final file in archive) {
      final fileName = file.name;
      // 检查是否是 images/ 文件夹中的文件
      if (fileName.toLowerCase().startsWith('images/') && !file.isFile) {
        continue; // 跳过目录条目
      }
      
      if (fileName.toLowerCase().startsWith('images/')) {
        hasImages = true;
        // 创建目录结构
        final targetPath = path.join(tempDirPath, fileName);
        final targetFile = File(targetPath);
        final targetDir = targetFile.parent;
        
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        
        // 写入文件
        if (file.content is List<int>) {
          await targetFile.writeAsBytes(file.content as List<int>);
          print('提取图片资源: $fileName -> $targetPath');
        }
      }
    }
    
    if (hasImages) {
      return imagesDir.path;
    }
    return null;
  }

  // 读取 Lottie 文件内容（支持 .json, .lottie, .json.gz, .zip）
  Future<String> _readLottieContent(String filePath, {bool extractImages = true}) async {
    final ext = path.extension(filePath).toLowerCase();
    final file = File(filePath);
    
    if (ext == '.gz' || filePath.toLowerCase().endsWith('.json.gz')) {
      // 处理 .json.gz 文件
      final bytes = await file.readAsBytes();
      final gzipDecoder = GZipDecoder();
      final decompressed = gzipDecoder.decodeBytes(bytes);
      return utf8.decode(decompressed);
    } else if (ext == '.lottie' || ext == '.zip') {
      // 处理 .lottie 或 .zip 文件（ZIP 格式）
      print('开始处理 ZIP 格式文件: $filePath');
      final bytes = await file.readAsBytes();
      print('ZIP 文件大小: ${bytes.length} bytes');
      
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
        print('ZIP 文件解压成功，包含 ${archive.length} 个文件');
      } catch (e) {
        print('ZIP 文件解压失败: $e');
        throw Exception('无法解压 ZIP 文件: $e');
      }
      
      // 列出所有文件
      print('ZIP 文件内容:');
      for (final file in archive) {
        print('  - ${file.name} (${file.isFile ? "文件" : "目录"})');
      }
      
      // 检测是否为 Lottie 格式
      if (ext == '.zip' && !_isLottieZip(archive)) {
        throw Exception('ZIP 文件不是有效的 Lottie 格式（未找到 data.json）');
      }
      
      // 提取图片资源（如果存在）
      if (extractImages) {
        final tempDir = await getTemporaryDirectory();
        final lottieTempDir = Directory('${tempDir.path}/lottie_extracted');
        if (await lottieTempDir.exists()) {
          await lottieTempDir.delete(recursive: true);
        }
        await lottieTempDir.create(recursive: true);
        
        _lottieImagesDir = await _extractLottieImages(archive, lottieTempDir.path);
        if (_lottieImagesDir != null) {
          print('已提取图片资源到: $_lottieImagesDir');
        } else {
          print('ZIP 文件中没有图片资源');
        }
      }
      
      // 优先查找 data.json 文件（标准 Lottie ZIP 格式）
      String? jsonContent;
      for (final file in archive) {
        final fileName = file.name;
        if (fileName == 'data.json') {
          jsonContent = utf8.decode(file.content as List<int>);
          print('找到 data.json 文件，大小: ${jsonContent.length} 字符');
          break;
        }
      }
      
      // 如果找不到 data.json，查找 animations/animation.json（.lottie 新格式）
      if (jsonContent == null) {
        print('未找到 data.json，查找 animations/animation.json...');
        for (final file in archive) {
          final fileName = file.name;
          if (fileName == 'animations/animation.json' || 
              (fileName.startsWith('animations/') && fileName.endsWith('.json'))) {
            jsonContent = utf8.decode(file.content as List<int>);
            print('找到动画 JSON 文件: ${file.name}，大小: ${jsonContent.length} 字符');
            break;
          }
        }
      }
      
      // 如果还是找不到，查找其他 JSON 文件（向后兼容，但排除 manifest.json）
      if (jsonContent == null) {
        print('未找到标准动画文件，查找其他 JSON 文件（排除 manifest.json）...');
        for (final file in archive) {
          final fileName = file.name;
          if (fileName.toLowerCase().endsWith('.json') && 
              !fileName.toLowerCase().contains('manifest')) {
            jsonContent = utf8.decode(file.content as List<int>);
            print('找到 JSON 文件: ${file.name}，大小: ${jsonContent.length} 字符');
            break;
          }
        }
      }
      
      if (jsonContent == null) {
        throw Exception('在 ZIP 文件中未找到 JSON 文件');
      }
      
      return jsonContent;
    } else {
      // 直接读取 .json 文件
      return await file.readAsString();
    }
  }

  Future<void> processLottieFile(String filePath, {bool clearBeforeProcess = true}) async {
    print('开始处理新的Lottie文件: ${path.basename(filePath)}');
    
    try {
      if (clearBeforeProcess) {
        await clearState();
      }
      
      _animationType = AnimationType.lottie;
      imageCache.clear();
      imageCache.clearLiveImages();
      print('图片缓存已清空');

      _currentFileName = path.basename(filePath);
      
      // 获取原始文件大小
      final originalFile = File(filePath);
      if (await originalFile.exists()) {
        _svgaFileSizeBytes = await originalFile.length();
        print('Lottie文件大小: $_svgaFileSizeBytes bytes ($svgaFileSizeText)');
      }
      
      // 读取 Lottie JSON 内容（同时提取图片资源）
      print('开始读取 Lottie 文件内容...');
      String jsonString = await _readLottieContent(filePath, extractImages: true);
      print('JSON 内容长度: ${jsonString.length} 字符');
      
      // 如果是 ZIP 格式（.lottie 或 .zip），需要将 JSON 保存到临时文件
      final ext = path.extension(filePath).toLowerCase();
      String? targetImagesDirPath; // 保存目标图片目录路径，供后续使用
      
      if (ext == '.lottie' || ext == '.zip') {
        // 解析 JSON 以检查和修复图片路径
        Map<String, dynamic> jsonData = json.decode(jsonString);
        
        // 检查并修复 assets 中的图片路径
        // 只有在确实提取到了 images 文件夹时才修复路径
        if (jsonData.containsKey('assets') && _lottieImagesDir != null) {
          final assets = jsonData['assets'] as List<dynamic>?;
          if (assets != null) {
            print('检查 assets 中的图片路径，共 ${assets.length} 个资源...');
            bool hasImages = false;
            for (var asset in assets) {
              if (asset is Map<String, dynamic>) {
                final p = asset['p'] as String?; // 图片文件名
                final u = asset['u'] as String?; // 图片路径（目录）
                
                // 检查是否是图片资源（有 p 字段且是图片格式）
                if (p != null && (p.toLowerCase().endsWith('.png') || 
                                  p.toLowerCase().endsWith('.jpg') || 
                                  p.toLowerCase().endsWith('.jpeg'))) {
                  hasImages = true;
                  // 确保路径是 images/（相对于 JSON 文件）
                  String newPath = 'images/';
                  
                  // 如果原路径不是 images/，更新它
                  if (u != newPath) {
                    asset['u'] = newPath;
                    print('更新图片路径: ${u ?? "(空)"} -> $newPath (文件: $p)');
                  } else {
                    print('图片路径已正确: $newPath$p');
                  }
                }
              }
            }
            if (hasImages) {
              // 重新编码 JSON
              jsonString = json.encode(jsonData);
              print('已修复 JSON 中的图片路径');
            } else {
              print('未找到图片资源引用');
            }
          }
        } else if (jsonData.containsKey('assets')) {
          print('JSON 包含 assets，但未提取到 images 文件夹，保持原始路径');
        }
        
        // 创建临时 JSON 文件
        final tempDir = await getTemporaryDirectory();
        final lottieJsonFile = File('${tempDir.path}/lottie_${DateTime.now().millisecondsSinceEpoch}.json');
        await lottieJsonFile.writeAsString(jsonString);
        print('已将 Lottie JSON 保存到临时文件: ${lottieJsonFile.path}');
        
        // 如果提取了图片资源，需要先复制图片，然后再设置 _lottieFile
        if (_lottieImagesDir != null) {
          // 注意：Lottie 库会自动在 JSON 文件所在目录查找 images/ 文件夹
          // 所以我们需要将 images 文件夹复制到 JSON 文件所在目录
          final jsonDir = lottieJsonFile.parent;
          final targetImagesDir = Directory('${jsonDir.path}/images');
          targetImagesDirPath = targetImagesDir.path; // 保存路径供后续使用
          
          if (await Directory(_lottieImagesDir!).exists()) {
            // 如果目标目录已存在，先删除
            if (await targetImagesDir.exists()) {
              await targetImagesDir.delete(recursive: true);
            }
            
            // 复制图片目录（必须在设置 _lottieFile 之前完成）
            print('开始复制图片资源...');
            print('源目录: $_lottieImagesDir');
            print('目标目录: ${targetImagesDir.path}');
            await _copyDirectory(Directory(_lottieImagesDir!), targetImagesDir);
            print('已将图片资源复制到: ${targetImagesDir.path}');
            
            // 验证图片是否复制成功
            if (await targetImagesDir.exists()) {
              final imageFiles = await targetImagesDir.list().toList();
              print('图片目录包含 ${imageFiles.length} 个文件/目录');
              for (final file in imageFiles.take(5)) {
                if (file is File) {
                  print('  - ${file.path} (${await file.length()} bytes)');
                }
              }
            } else {
              print('警告: 目标图片目录不存在: ${targetImagesDir.path}');
            }
          } else {
            print('警告: 源图片目录不存在: $_lottieImagesDir');
          }
        } else {
          print('未提取到图片资源，跳过图片复制');
        }
        
        // 图片复制完成后再设置 _lottieFile，确保 Lottie 库能找到图片
        _lottieFile = lottieJsonFile;
        print('已设置 Lottie 文件引用: ${_lottieFile!.path}');
      } else {
        // 直接使用原始文件
        _lottieFile = originalFile;
        print('使用原始 JSON 文件: ${originalFile.path}');
      }
      
      // 解析 JSON
      print('开始解析 JSON 数据...');
      Map<String, dynamic> lottieData;
      try {
        lottieData = json.decode(jsonString) as Map<String, dynamic>;
        print('JSON 解析成功，包含 ${lottieData.length} 个键');
      } catch (e) {
        print('JSON 解析失败: $e');
        print('JSON 内容前 500 字符: ${jsonString.substring(0, jsonString.length > 500 ? 500 : jsonString.length)}');
        rethrow;
      }
      
      // 解析 Lottie 信息
      print('开始解析 Lottie 动画信息...');
      print('JSON 键列表: ${lottieData.keys.toList()}');
      
      final width = (lottieData['w'] as num?)?.toDouble() ?? 0.0;
      final height = (lottieData['h'] as num?)?.toDouble() ?? 0.0;
      final frameRate = (lottieData['fr'] as num?)?.toDouble() ?? 60.0;
      final inPoint = (lottieData['ip'] as num?)?.toInt() ?? 0;
      final outPoint = (lottieData['op'] as num?)?.toInt() ?? 0;
      
      print('原始值 - w: $width, h: $height, fr: $frameRate, ip: $inPoint, op: $outPoint');
      
      _frameWidth = width.toInt();
      _frameHeight = height.toInt();
      _fps = frameRate > 0 ? frameRate : 60.0; // 确保 FPS 不为 0
      _totalFrames = outPoint > inPoint ? (outPoint - inPoint) : 0;
      // 计算时长，避免除以 0
      if (_totalFrames > 0 && _fps > 0) {
        _duration = _totalFrames / _fps;
      } else {
        _duration = 0.0;
      }
      
      print('Lottie信息: ${_frameWidth}x${_frameHeight}, FPS: $_fps, 总帧数: $_totalFrames, 时长: $_duration秒');
      
      // 验证关键信息
      if (_frameWidth == 0 || _frameHeight == 0) {
        print('警告: 宽度或高度为 0，可能是 JSON 格式问题');
      }
      if (_totalFrames == 0) {
        print('警告: 总帧数为 0，可能是 JSON 格式问题');
      }
      
      // 立即通知 UI 更新尺寸信息，这样预览组件就能使用正确的尺寸
      notifyListeners();
      
      // 创建临时目录
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory('${tempDir.path}/lottie_frames');
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
      }
      await framesDir.create(recursive: true);
      print('创建新的临时目录: ${framesDir.path}');
      
      // 提取帧和图片资源
      final List<File> tempFrames = [];
      final List<FrameInfo> tempFrameInfos = [];
      double totalFileSizeBytes = 0;
      
      print('开始处理 Lottie 图片资源...');
      
      // 如果提取了图片资源，将这些图片添加到帧列表中
      // 优先使用复制后的目标目录，如果没有则使用原始提取目录
      String? imagesDirToUse = targetImagesDirPath ?? _lottieImagesDir;
      
      if (imagesDirToUse != null && await Directory(imagesDirToUse).exists()) {
        print('开始加载 images 文件夹中的图片...');
        print('使用图片目录: $imagesDirToUse');
        final imageFiles = await Directory(imagesDirToUse).list().toList();
        
        // 过滤出图片文件并按文件名排序
        final imageFileList = imageFiles
            .whereType<File>()
            .where((file) {
              final ext = path.extension(file.path).toLowerCase();
              return ext == '.png' || ext == '.jpg' || ext == '.jpeg' || ext == '.webp';
            })
            .toList();
        
        // 按文件名排序
        imageFileList.sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));
        
        print('找到 ${imageFileList.length} 个图片文件');
        
        for (var imageFile in imageFileList) {
          try {
            // 读取图片信息
            final bytes = await imageFile.readAsBytes();
            final codec = await instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            
            // 计算内存占用
            final frameMemoryMB = (frame.image.width * frame.image.height * 4) / (1024 * 1024);
            _memoryUsage += frameMemoryMB;
            
            // 获取文件大小
            final fileSizeBytes = await imageFile.length();
            totalFileSizeBytes += fileSizeBytes;
            
            // 添加到帧列表
            tempFrames.add(imageFile);
            
            // 创建帧信息
            final frameInfo = FrameInfo(
              file: imageFile,
              fileSizeBytes: fileSizeBytes,
              memoryUsageMB: frameMemoryMB,
              width: frame.image.width,
              height: frame.image.height,
            );
            tempFrameInfos.add(frameInfo);
            
            print('添加图片: ${path.basename(imageFile.path)} (${frame.image.width}x${frame.image.height}, ${frameInfo.fileSizeText})');
          } catch (e) {
            print('处理图片 ${imageFile.path} 时出错: $e');
          }
        }
      }
      
      if (tempFrames.isEmpty) {
        print('未能从Lottie文件中提取到任何图片');
      } else {
        print('成功加载了 ${tempFrames.length} 个图片文件');
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
      print('处理Lottie文件时出错: $e');
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

  Future<void> downloadFromUrl(String url) async {
    if (_isDownloading) return;
    
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      _downloadError = '无效的URL（仅支持 http/https）';
      _downloadProgress = 0.0;
      _isDownloading = false;
      notifyListeners();
      return;
    }

    await clearState();

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadError = null;
    notifyListeners();

    _downloadCancelToken = CancelToken();

    try {
      final host = uri.host;
      
      // DNS 解析日志
      try {
        print('开始DNS解析: $host');
        final addresses = await InternetAddress.lookup(host);
        print('DNS解析结果: ${addresses.map((a) => a.address).join(", ")}');
      } catch (e) {
        print('DNS解析失败: $e');
        print('提示: 这是系统 DNS 配置问题，请检查：');
        print('  1. 系统设置 → 网络 → 高级 → DNS');
        print('  2. 确保有可用的 DNS 服务器（如 8.8.8.8, 1.1.1.1）');
        print('  3. 刷新 DNS 缓存: sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder');
      }

      final tempDir = await getTemporaryDirectory();
      final downloadDir = Directory('${tempDir.path}/svga_downloads');
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
      await downloadDir.create(recursive: true);

      // 根据 URL 判断文件类型
      final urlLower = url.toLowerCase();
      String fileExtension = '.svga';
      if (urlLower.contains('.jpg') || urlLower.contains('.jpeg')) {
        fileExtension = '.jpg';
      } else if (urlLower.contains('.png')) {
        fileExtension = '.png';
      } else if (urlLower.contains('.gif')) {
        fileExtension = '.gif';
      } else if (urlLower.contains('.webp')) {
        fileExtension = '.webp';
      } else if (urlLower.contains('.svga')) {
        fileExtension = '.svga';
      } else if (urlLower.contains('.json') && !urlLower.contains('.json.gz')) {
        fileExtension = '.json';
      } else if (urlLower.contains('.lottie')) {
        fileExtension = '.lottie';
      } else if (urlLower.contains('.json.gz')) {
        fileExtension = '.json.gz';
      } else if (urlLower.contains('.zip')) {
        fileExtension = '.zip';
      }

      final savePath = path.join(
        downloadDir.path,
        'download_${DateTime.now().millisecondsSinceEpoch}$fileExtension',
      );

      print('开始下载: $url');
      print('检测到文件类型: $fileExtension');
      print('保存路径: $savePath');

      final dio = Dio();
      
      // 使用 Dio 下载
      await dio.download(
        url,
        savePath,
        cancelToken: _downloadCancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status >= 200 && status < 400,
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': uri.origin,
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total;
            if (received % 100000 == 0 || received == total) {
              print('下载进度: ${(received / 1024).toStringAsFixed(1)} KB / ${(total / 1024).toStringAsFixed(1)} KB (${(_downloadProgress * 100).toStringAsFixed(1)}%)');
            }
          } else {
            _downloadProgress = 0.0;
          }
          notifyListeners();
        },
      );
      
      print('下载成功');

      // 文件大小日志
      final downloadedFile = File(savePath);
      if (await downloadedFile.exists()) {
        final fileSize = await downloadedFile.length();
        print('下载完成，文件大小: $fileSize bytes (${(fileSize / 1024).toStringAsFixed(1)} KB)');
      } else {
        print('警告: 下载文件不存在: $savePath');
      }

      _downloadProgress = 1.0;
      _downloadedFilePath = savePath;
      _isDownloading = false;
      notifyListeners();

      // 根据文件类型决定是否解析
      if (fileExtension == '.svga') {
        // SVGA 文件，进行解析
        try {
          print('开始解析SVGA文件...');
          await processSVGAFile(savePath, clearBeforeProcess: false);
          _downloadError = null;
          print('SVGA文件解析成功');
          // 解析成功，文件已由 processSVGAFile 处理，不需要删除
          _downloadedFilePath = null; // 清除引用，避免后续清理时删除
        } catch (e) {
          print('SVGA解析失败: $e');
          _downloadError = '解析失败: $e';
          notifyListeners();
          // 解析失败，删除下载的文件
          await _removeDownloadedFile();
        }
      } else if (fileExtension == '.json' || fileExtension == '.lottie' || fileExtension == '.json.gz' || fileExtension == '.zip') {
        // Lottie 文件或 ZIP 文件，进行解析
        try {
          print('开始解析Lottie/ZIP文件...');
          // processAnimationFile 会自动检测 ZIP 文件是否为 Lottie 格式
          await processAnimationFile(savePath, clearBeforeProcess: false);
          _downloadError = null;
          print('Lottie/ZIP文件解析成功');
          // 解析成功，文件已由 processLottieFile 处理，不需要删除
          _downloadedFilePath = null; // 清除引用，避免后续清理时删除
        } catch (e) {
          print('Lottie/ZIP解析失败: $e');
          _downloadError = '解析失败: $e';
          notifyListeners();
          // 解析失败，删除下载的文件
          await _removeDownloadedFile();
        }
      } else {
        // 图片文件，只显示成功信息
        print('图片文件下载成功，文件类型: $fileExtension');
        _downloadError = null;
        _downloadedFilePath = null; // 图片文件不需要保留引用
        notifyListeners();
        // 可以选择保留文件用于测试，或者立即删除
        // await _removeDownloadedFile(); // 如果需要立即删除，取消注释
      }
    } on DioException catch (e) {
      print('下载异常 (DioException): ${e.type} - ${e.message}');
      print('响应状态: ${e.response?.statusCode}');
      print('响应数据: ${e.response?.data}');
      if (CancelToken.isCancel(e)) {
        print('下载已取消');
        _downloadError = '下载已取消';
      } else {
        print('下载失败详情: ${e.toString()}');
        // 检查是否是 DNS 解析失败
        final errorMsg = e.message ?? e.toString();
        if (errorMsg.contains('Failed host lookup') || errorMsg.contains('nodename nor servname')) {
          _downloadError = 'DNS 解析失败\n请检查系统 DNS 配置:\n1. 系统设置 → 网络 → 高级 → DNS\n2. 添加 DNS: 8.8.8.8 或 1.1.1.1\n3. 刷新缓存: sudo dscacheutil -flushcache';
        } else {
          _downloadError = '下载失败: $errorMsg';
        }
      }
      _isDownloading = false;
      notifyListeners();
      // 下载失败，删除下载的文件
      await _removeDownloadedFile();
    } catch (e, stackTrace) {
      print('下载异常 (其他): $e');
      print('堆栈跟踪: $stackTrace');
      // 检查是否是 DNS 解析失败
      final errorStr = e.toString();
      if (errorStr.contains('Failed host lookup') || errorStr.contains('nodename nor servname')) {
        _downloadError = 'DNS 解析失败\n请检查系统 DNS 配置:\n1. 系统设置 → 网络 → 高级 → DNS\n2. 添加 DNS: 8.8.8.8 或 1.1.1.1\n3. 刷新缓存: sudo dscacheutil -flushcache';
      } else {
        _downloadError = '下载失败: $e';
      }
      _isDownloading = false;
      notifyListeners();
      // 下载失败，删除下载的文件
      await _removeDownloadedFile();
    } finally {
      _downloadCancelToken = null;
      print('下载流程结束');
    }
  }

  Future<void> cancelDownload() async {
    if (_isDownloading && _downloadCancelToken != null && !_downloadCancelToken!.isCancelled) {
      _downloadCancelToken!.cancel('用户取消');
    }
  }

  // 清理下载状态（用于重新打开对话框时）
  void clearDownloadState() {
    _isDownloading = false;
    _downloadProgress = 0.0;
    _downloadError = null;
    _downloadCancelToken?.cancel('clearDownloadState');
    _downloadCancelToken = null;
    notifyListeners();
  }

  Future<void> _removeDownloadedFile() async {
    if (_downloadedFilePath == null) return;
    try {
      final file = File(_downloadedFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('删除下载文件失败: $e');
    } finally {
      _downloadedFilePath = null;
    }
  }

  @override
  void dispose() {
    _speedChangeDebounceTimer?.cancel();
    super.dispose();
  }
} 