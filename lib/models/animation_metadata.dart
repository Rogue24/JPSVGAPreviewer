
/// 动画元数据
/// 封装动画的基本信息，包括尺寸、帧率、时长等
class AnimationMetadata {
  /// 动画宽度（像素）
  final int width;
  
  /// 动画高度（像素）
  final int height;
  
  /// 帧率（FPS）
  final double fps;
  
  /// 总帧数
  final int totalFrames;
  
  /// 动画时长（秒）
  final double duration;
  
  /// 文件大小（字节）
  final int fileSizeBytes;
  
  /// 内存占用（MB）
  final double memoryUsageMB;
  
  /// 临时文件总大小（MB）
  final double totalFileSizeMB;

  AnimationMetadata({
    required this.width,
    required this.height,
    required this.fps,
    required this.totalFrames,
    required this.duration,
    this.fileSizeBytes = 0,
    this.memoryUsageMB = 0.0,
    this.totalFileSizeMB = 0.0,
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

  /// 创建副本并更新部分字段
  AnimationMetadata copyWith({
    int? width,
    int? height,
    double? fps,
    int? totalFrames,
    double? duration,
    int? fileSizeBytes,
    double? memoryUsageMB,
    double? totalFileSizeMB,
  }) {
    return AnimationMetadata(
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      totalFrames: totalFrames ?? this.totalFrames,
      duration: duration ?? this.duration,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      memoryUsageMB: memoryUsageMB ?? this.memoryUsageMB,
      totalFileSizeMB: totalFileSizeMB ?? this.totalFileSizeMB,
    );
  }
}

