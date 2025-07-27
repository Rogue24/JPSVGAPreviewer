import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/view_models/svga_view_model.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'dart:io';

class SVGAPreview extends StatefulWidget {
  final SVGAAnimationController controller;
  final File file;
  final Size preferredSize;
  
  const SVGAPreview({super.key, required this.controller, required this.file, required this.preferredSize});
  
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
      print("SVGAPreview didUpdateWidget: SVGA文件【已】变化");
      _loadSVGA();
    } else {
      print("SVGAPreview didUpdateWidget: SVGA文件【未】变化");
    }
  }
  
  Future<void> _loadSVGA() async {
    try {
      widget.controller.reset();
      final parser = SVGAParser(); // 如果使用的是const parser，这里会是同一个实例
      print("SVGAPreview parser.hashCode: ${parser.hashCode}");
      final videoItem = await parser.decodeFromBuffer(
        await widget.file.readAsBytes(),
      );
      if (mounted) {
        print("SVGAPreview 开始播放");
        widget.controller.videoItem = videoItem;
        
        // 初始化播放速度控制
        final viewModel = Provider.of<SVGAViewModel>(context, listen: false);
        viewModel.initializeControllerForSpeed(widget.controller);
        
        widget.controller.repeat();
      }
    } catch (e) {
      print('SVGAPreview 加载SVGA文件失败: $e');
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
    return Consumer<SVGAViewModel>(
      builder: (context, viewModel, child) {
        return Container(
          width: widget.preferredSize.width,
          height: widget.preferredSize.height,
          decoration: BoxDecoration(
            color: viewModel.previewBackgroundColor,
            borderRadius: viewModel.showBorder ? BorderRadius.circular(6) : null,
          ),
          clipBehavior: viewModel.allowDrawingOverflow ? Clip.none : Clip.hardEdge,
          child: SVGAImage(
            widget.controller, 
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high, 
            // allowDrawingOverflow: viewModel.allowDrawingOverflow,
            preferredSize: widget.preferredSize,
          ),
        );
      }
    );
  }
} 