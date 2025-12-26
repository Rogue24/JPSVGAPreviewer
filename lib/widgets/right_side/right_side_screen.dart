import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/models/display_mode.dart';
import 'package:svga_previewer/view_models/animation_view_model.dart';
import 'package:svga_previewer/widgets/right_side/animation_preview.dart';
import 'package:svga_previewer/widgets/right_side/frame_preview.dart';
import 'package:svga_previewer/widgets/right_side/svga_info_bar.dart';
import 'package:svgaplayer_flutter/player.dart';

class RightSideScreen extends StatelessWidget {
  final SVGAAnimationController controller;
  
  const RightSideScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimationViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          children: _buildWidgets(viewModel.mode),
        );
      },
    );
  }

  List<Widget> _buildWidgets(DisplayMode mode) {
    List<Widget> list = [const SVGAInfoBar()]; // 文件信息栏
    if (mode == DisplayMode.showTop) {
      list.add(Expanded(child: AnimationPreview(controller: controller),)); // 动画播放区域
    } else if (mode == DisplayMode.showBottom) {
      list.add(Container(height: 1, color: Colors.grey.shade800,)); // 分隔线
      list.add(const Expanded(child: FramePreview(),)); // 图片预览区域
    } else {
      list.add(Expanded(child: AnimationPreview(controller: controller),)); // 动画播放区域
      list.add(Container(height: 1, color: Colors.grey.shade800,)); // 分隔线
      list.add(const Expanded(child: FramePreview(),)); // 图片预览区域
    }
    return list;
  }

  // Column+Stack方式:
  // return Column(
  //   children: [
  //     // 文件信息栏
  //     const SVGAInfoBar(),
  //     Expanded(
  //       child: LayoutBuilder(
  //         builder: (context, constraints) {
  //           final fullHeight = constraints.maxHeight;
  //           return Consumer<AnimationViewModel>(
  //             builder: (context, viewModel, child) {
  //               final mode = viewModel.mode;
  //               return Stack(
  //                 children: _buildPreviews(mode, fullHeight,),
  //               );
  //             }
  //           );
  //         },
  //       )
  //     ),
  //   ],
  // );

  // Column+Stack方式:
  // List<Widget> _buildPreviews(DisplayMode mode, double fullHeight) {
  //   final halfHeight = (fullHeight - 1) / 2;
  //   if (mode == DisplayMode.showTop) {
  //     return  [
  //       _buildBottom(halfHeight),
  //       _buildTop(fullHeight),
  //     ];
  //   } else if (mode == DisplayMode.showBottom) {
  //     return  [
  //       _buildTop(halfHeight),
  //       _buildBottom(fullHeight),
  //     ];
  //   } else {
  //     return [
  //       _buildTop(halfHeight),
  //       _buildLine(halfHeight),
  //       _buildBottom(halfHeight),
  //     ];
  //   }
  // }
  // 
  // Widget _buildTop(double height) {
  //   return Positioned(
  //     top: 0,
  //     left: 0,
  //     right: 0,
  //     height: height,
  //     child: AnimationPreview(controller: _controller),
  //   );
  // }
  // 
  // Widget _buildLine(double top) {
  //   return Positioned(
  //     top: top,
  //     left: 0,
  //     right: 0,
  //     height: 1,
  //     child: Container(height: 1, color: Colors.grey.shade800,),
  //   );
  // }
  // 
  // Widget _buildBottom(double height) {
  //   return Positioned(
  //     bottom: 0,
  //     left: 0,
  //     right: 0,
  //     height: height,
  //     child: const FramePreview(),
  //   );
  // }
}