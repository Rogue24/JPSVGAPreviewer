import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/models/animation_type.dart';
import 'package:svga_previewer/models/display_mode.dart';
import 'package:svga_previewer/view_models/animation_view_model.dart';
import 'package:svga_previewer/widgets/left_side/background_color_bar.dart';
import 'package:svga_previewer/widgets/left_side/display_mode_bar.dart';
import 'package:svga_previewer/widgets/left_side/frames_list.dart';
import 'package:svga_previewer/widgets/left_side/svga_control_bar.dart';
import 'package:svga_previewer/widgets/left_side/toggle_border_bar.dart';
import 'package:svgaplayer_flutter/player.dart';
import 'package:flutter/cupertino.dart';

class LeftSideScreen extends StatelessWidget {
  final SVGAAnimationController controller;
  
  const LeftSideScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimationViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          children: _buildWidgets(viewModel, controller),
        );
      },
    );
  }
  
  List<Widget> _buildWidgets(AnimationViewModel viewModel, SVGAAnimationController controller) {
    List<Widget> list = [
      // 动画图片列表
      Expanded(
        child: ClipRect(
          child: viewModel.frames.isEmpty
            ? _buildPlaceholder(viewModel)
            : FramesList(viewModel: viewModel,),
        ),
      ),
    ]; 
    if ((viewModel.svgaFile != null || viewModel.lottieFile != null) && viewModel.mode != DisplayMode.showBottom) {
      // 进度控制栏
      list.add(SVGAControlBar(viewModel: viewModel, controller: controller));
    }
    // 边框选项栏
    list.add(ToggleBorderBar(viewModel: viewModel));
    // 背景色选项栏
    list.add(BackgroundColorBar(viewModel: viewModel));
    // 排版选项栏
    list.add(DisplayModeBar(viewModel: viewModel, controller: controller));
    // 底部间距
    list.add(const SizedBox(height: 4));
    return list;
  }

  Widget _buildPlaceholder(AnimationViewModel viewModel) {
    // 判断是否有加载的动画文件
    final hasAnimationFile = viewModel.svgaFile != null || viewModel.lottieFile != null;
    
    if (!hasAnimationFile) {
      return const Center(
        child: Text('拖放SVGA/Lottie/ZIP文件到这里\n或点击右下角按钮打开文件'),
      );
    } else {
      // 根据动画类型显示不同的提示
      final animationType = viewModel.animationType;
      final fileType = animationType == AnimationType.lottie ? 'Lottie' : 'SVGA';
      return Center(
        child: Text('该$fileType文件并未包含图片\n🎨🚫', textAlign: TextAlign.center,),
      );
    }
  }
}