import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/view_models/animation_view_model.dart';
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
  Duration? _originalDuration; // 保存原始duration
  double _currentAppliedSpeed = 1.0; // 当前已应用的速度
  
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
      final parser = const SVGAParser(); // 如果使用的是const parser，这里会是同一个实例
      print("SVGAPreview parser.hashCode: ${parser.hashCode}");
      final videoItem = await parser.decodeFromBuffer(
        await widget.file.readAsBytes(),
      );
      if (mounted) {
        print("SVGAPreview 开始播放");
        widget.controller.videoItem = videoItem;
        
        // 保存原始duration
        if (widget.controller.duration != null) {
          _originalDuration = widget.controller.duration!;
          print("保存原始duration: ${_originalDuration!.inMilliseconds}ms");
        }
        
        // 应用当前播放速度
        final viewModel = Provider.of<AnimationViewModel>(context, listen: false);
        _applyPlaybackSpeed(viewModel.playbackSpeed);
        
        widget.controller.repeat();
      }
    } catch (e) {
      print('SVGAPreview 加载SVGA文件失败: $e');
    }
  }

  /// 应用播放速度到controller
  void _applyPlaybackSpeed(double speed) {
    if (_originalDuration == null) {
      print("原始duration未保存，跳过速度应用");
      return;
    }
    
    if (_currentAppliedSpeed == speed) {
      return; // 已经应用了相同的速度，跳过
    }
    
    try {
      // 基于原始duration计算新duration
      final newDuration = Duration(
        milliseconds: (_originalDuration!.inMilliseconds / speed).round(),
      );
      
      // 保存当前播放状态
      final wasAnimating = widget.controller.isAnimating;
      final currentValue = widget.controller.value;
      
      // 停止当前动画
      if (wasAnimating) {
        widget.controller.stop();
      }
      
      // 设置新的duration
      widget.controller.duration = newDuration;
      
      // 恢复播放位置
      widget.controller.value = currentValue;
      
      // 如果之前在播放，继续播放
      if (wasAnimating) {
        widget.controller.repeat();
      }
      
      _currentAppliedSpeed = speed;
      print("SVGAPreview 成功应用播放速度: ${speed}x, 新duration: ${newDuration.inMilliseconds}ms");
    } catch (e) {
      print("SVGAPreview 应用播放速度失败: $e");
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
    return Consumer<AnimationViewModel>(
      builder: (context, viewModel, child) {
        // 监听播放速度变化并自动应用
        if (_originalDuration != null && viewModel.playbackSpeed != _currentAppliedSpeed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyPlaybackSpeed(viewModel.playbackSpeed);
          });
        }
        
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