import 'package:svga_previewer/services/parsers/animation_parse_result.dart';

/// 动画解析器接口
/// 定义统一的动画文件解析接口，支持不同格式的动画文件解析
abstract class AnimationParser {
  /// 判断是否可以解析指定文件
  /// 
  /// [filePath] 文件路径
  /// 返回 true 如果可以解析，否则返回 false
  bool canParse(String filePath);

  /// 解析动画文件
  /// 
  /// [filePath] 文件路径
  /// 返回解析结果，包含元数据、帧信息等
  Future<AnimationParseResult> parse(String filePath);
}

