import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/view_models/svga_view_model.dart';
import 'package:svga_previewer/widgets/animation_preview.dart';
import 'package:svga_previewer/widgets/frame_preview.dart';
import 'package:svga_previewer/widgets/frames_list.dart';
import 'package:svga_previewer/widgets/svga_info_bar.dart';
import 'package:svgaplayer_flutter/player.dart';

class JPMainScreen extends StatefulWidget {
  const JPMainScreen({super.key});

  @override
  State<JPMainScreen> createState() => _JPMainScreenState();
}

class _JPMainScreenState extends State<JPMainScreen> with SingleTickerProviderStateMixin {
  late SVGAAnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
  }

  @override
  void dispose() {
    // ✅ 正确地在父组件中释放controller
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            // 左侧帧列表
            Container(
              width: 200,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Colors.grey.shade800,
                    width: 1,
                  ),
                ),
              ),
              child: FramesList(controller: _controller),
            ),
            // 右侧预览区域
            Expanded(
              child: Container(
                color: Colors.transparent,
                child: Consumer<SVGAViewModel>(
                  builder: (context, viewModel, child) {
                    return Column(
                      children: _buildPreviews(viewModel.mode),
                    );
                  },
                ),
                // Column+Stack方式:
                // child: Column(
                //   children: [
                //     // 文件信息栏
                //     const SVGAInfoBar(),
                //     Expanded(
                //       child: LayoutBuilder(
                //         builder: (context, constraints) {
                //           final fullHeight = constraints.maxHeight;
                //           return Consumer<SVGAViewModel>(
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
                // ),
              ),
            ),
          ],
        ),
        // 拖拽提示遮罩
        Consumer<SVGAViewModel>(
          builder: (context, viewModel, child) {
            if (!viewModel.isDragging) return const SizedBox();
            return Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Text(
                  '释放以打开 SVGA 文件',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildPreviews(DisplayMode mode) {
    List<Widget> list = [const SVGAInfoBar()]; // 文件信息栏
    if (mode == DisplayMode.showTop) {
      list.add(Expanded(child: AnimationPreview(controller: _controller),)); // 动画播放区域
    } else if (mode == DisplayMode.showBottom) {
      list.add(Container(height: 1, color: Colors.grey.shade800,)); // 分隔线
      list.add(const Expanded(child: FramePreview(),)); // 图片预览区域
    } else {
      list.add(Expanded(child: AnimationPreview(controller: _controller),)); // 动画播放区域
      list.add(Container(height: 1, color: Colors.grey.shade800,)); // 分隔线
      list.add(const Expanded(child: FramePreview(),)); // 图片预览区域
    }
    return list;
  }
  
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