import 'dart:io';

/// 帧信息类
/// 封装单个帧的详细信息，包括文件、大小、内存占用和尺寸
class FrameInfo {
  /// 帧文件
  final File file;
  
  /// 文件大小（字节）
  final int fileSizeBytes;
  
  /// 内存占用（MB）
  final double memoryUsageMB;
  
  /// 帧宽度（像素）
  final int width;
  
  /// 帧高度（像素）
  final int height;
  
  FrameInfo({
    required this.file,
    required this.fileSizeBytes,
    required this.memoryUsageMB,
    required this.width,
    required this.height,
  });
  
  /// 获取文件大小的文本表示
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

