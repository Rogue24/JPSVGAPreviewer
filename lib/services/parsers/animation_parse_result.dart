import 'dart:io';
import 'package:svga_previewer/models/animation_metadata.dart';
import 'package:svga_previewer/models/frame_info.dart';
import 'package:svga_previewer/models/animation_type.dart';

/// 动画解析结果
/// 封装解析后的动画数据，包括元数据、文件引用和帧信息
class AnimationParseResult {
  /// 动画类型
  final AnimationType animationType;
  
  /// 动画元数据
  final AnimationMetadata metadata;
  
  /// 动画文件引用（SVGA 文件或 Lottie JSON 文件）
  final File? animationFile;
  
  /// 帧文件列表
  final List<File> frames;
  
  /// 帧信息列表
  final List<FrameInfo> frameInfos;
  
  /// Lottie 图片资源目录（仅 Lottie 格式）
  final String? lottieImagesDir;

  AnimationParseResult({
    required this.animationType,
    required this.metadata,
    this.animationFile,
    required this.frames,
    required this.frameInfos,
    this.lottieImagesDir,
  });
}

