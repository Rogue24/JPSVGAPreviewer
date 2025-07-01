import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'dart:io';

class SVGAPreview extends StatefulWidget {
  final SVGAAnimationController controller;
  final File file;
  
  const SVGAPreview({super.key, required this.controller, required this.file});
  
  @override
  State<SVGAPreview> createState() => _SVGAPreviewState();
}

class _SVGAPreviewState extends State<SVGAPreview> {
  
  @override
  void initState() {
    super.initState();
    _loadSVGA();
  }

  @override
  void didUpdateWidget(SVGAPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _loadSVGA();
    }
  }
  
  Future<void> _loadSVGA() async {
    try {
      widget.controller.reset();
      final parser = SVGAParser(); // 如果使用的是const parser，这里会是同一个实例
      print("jpjpjp parser.hashCode: ${parser.hashCode}");
      final videoItem = await parser.decodeFromBuffer(
        await widget.file.readAsBytes(),
      );
      if (mounted) {
        widget.controller.videoItem = videoItem;
        widget.controller.repeat();
      }
    } catch (e) {
      print('jpjpjp 加载SVGA文件失败: $e');
    }
  }
  
  @override
  void dispose() {
    // 一旦Widget中展示的数据发生变化，就会销毁现在这个Widget，然后重新构建整个Widget，因此：
    // ❌ 不能在这里释放controller，因为它是由父组件管理的
    // widget.controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SVGAImage(
          widget.controller, 
          preferredSize: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
} 