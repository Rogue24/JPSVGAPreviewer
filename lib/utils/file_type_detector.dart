import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

/// 文件类型检测工具
/// 用于检测和判断动画文件的类型
class FileTypeDetector {
  /// 检测文件是否为支持的动画格式
  /// 
  /// 支持的格式：
  /// - .svga: SVGA 格式
  /// - .json: Lottie JSON 格式
  /// - .lottie: Lottie ZIP 格式
  /// - .json.gz: GZIP 压缩的 Lottie JSON
  /// - .zip: 可能是 Lottie 格式的 ZIP 文件
  static bool isSupportedAnimationFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.svga' ||
        ext == '.json' ||
        ext == '.lottie' ||
        filePath.toLowerCase().endsWith('.json.gz') ||
        ext == '.zip';
  }

  /// 检测 ZIP 文件是否为 Lottie 格式
  /// 
  /// 通过检查 ZIP 文件中是否包含 data.json 或 animations/animation.json 来判断
  /// 
  /// [archive] ZIP 归档对象
  /// 返回 true 如果是 Lottie 格式，否则返回 false
  static bool isLottieZip(Archive archive) {
    for (final file in archive) {
      final fileName = file.name.toLowerCase();
      // 支持根目录和嵌套目录中的 data.json
      if (fileName == 'data.json' ||
          fileName.endsWith('/data.json') ||
          (fileName.endsWith('.json') &&
              fileName.contains('data') &&
              !fileName.contains('manifest'))) {
        return true;
      }
    }
    return false;
  }

  /// 根据文件路径获取动画类型
  /// 
  /// [filePath] 文件路径
  /// 返回动画类型字符串：'svga' 或 'lottie'
  static String? getAnimationType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    if (ext == '.svga') {
      return 'svga';
    } else if (ext == '.json' ||
        ext == '.lottie' ||
        filePath.toLowerCase().endsWith('.json.gz') ||
        ext == '.zip') {
      return 'lottie';
    }
    return null;
  }

  /// 检测文件扩展名
  /// 
  /// [filePath] 文件路径
  /// 返回小写的文件扩展名（包含点号）
  static String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }
}

