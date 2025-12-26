import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/view_models/animation_view_model.dart';
import 'package:svga_previewer/widgets/left_side/left_side_screen.dart';
import 'package:svga_previewer/widgets/right_side/right_side_screen.dart';
import 'package:svgaplayer_flutter/player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
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
              child: LeftSideScreen(controller: _controller),
            ),
            // 右侧预览区域
            Expanded(
              child: Container(
                color: Colors.transparent,
                child: RightSideScreen(controller: _controller),
              ),
            ),
          ],
        ),
        // 拖拽提示遮罩
        _buildMaskToast(),
      ],
    );
  }

  Widget _buildMaskToast() {
    return Consumer<AnimationViewModel>(
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
    );
  }
}