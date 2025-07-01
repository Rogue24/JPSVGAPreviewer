import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svgaplayer_flutter/player.dart';
import '../view_models/svga_view_model.dart';
import 'package:flutter/cupertino.dart';

class FramesList extends StatelessWidget {
  final SVGAAnimationController controller;
  
  const FramesList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Consumer<SVGAViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          children: [
            Expanded(
              child: ClipRect(
                child: viewModel.frames.isEmpty
                    ? getPlaceholderWidget(viewModel.svgaFile == null)
                    : GridView.builder(
                        key: ValueKey(viewModel.currentFileName),
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: viewModel.frames.length,
                        itemBuilder: (context, index) {
                          return InkWell(
                            onTap: () => viewModel.setCurrentFrameIndex(index),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: index == viewModel.currentFrameIndex
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey.shade800,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Image.file(
                                      viewModel.frames[index],
                                      key: ValueKey('frame_${viewModel.currentFileName}_$index'),
                                      fit: BoxFit.contain,
                                      cacheWidth: null,
                                      cacheHeight: null,
                                      gaplessPlayback: false,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    color: Colors.black45,
                                    child: Text(
                                      '图 ${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),

            // 进度控制栏
            // Container(
            //   padding: const EdgeInsets.all(8),
            //   decoration: BoxDecoration(
            //     color: Theme.of(context).scaffoldBackgroundColor,  // 使用 Scaffold 的默认背景色
            //     border: Border(
            //       top: BorderSide(
            //         color: Colors.grey.shade800,
            //         width: 1,
            //       ),
            //     ),
            //   ),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Text('当前帧: ${controller.currentFrame}', style: const TextStyle(fontSize: 12)),
            //       const SizedBox(height: 8),
            //       Container(
            //         color: Colors.amber,
            //         child: const Padding(
            //           padding: EdgeInsets.all(2), 
            //           child: Text('临时占位的，之后放一个可以拖拽的进度条', style: TextStyle(fontSize: 12, color: Colors.black87)),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),

            // 开关选项栏
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,  // 使用 Scaffold 的默认背景色
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade800,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Text('显示边框:', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  Transform.scale(
                    scale: 0.7,
                    child: CupertinoSwitch(
                      value: viewModel.showBorder,
                      onChanged: viewModel.setShowBorder,
                      activeColor: Colors.blue.shade200,
                    ),
                  ),
                ],
              ),
            ),

            // 背景选项栏
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,  // 使用 Scaffold 的默认背景色
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade800,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('背景颜色:', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ColorButton(
                        color: Colors.transparent,
                        isSelected: viewModel.previewBackgroundColor == Colors.transparent,
                        onTap: () => viewModel.setPreviewBackgroundColor(Colors.transparent),
                      ),
                      _ColorButton(
                        color: Colors.black,
                        isSelected: viewModel.previewBackgroundColor == Colors.black,
                        onTap: () => viewModel.setPreviewBackgroundColor(Colors.black),
                      ),
                      _ColorButton(
                        color: Colors.white,
                        isSelected: viewModel.previewBackgroundColor == Colors.white,
                        onTap: () => viewModel.setPreviewBackgroundColor(Colors.white),
                      ),
                      _ColorButton(
                        color: Colors.grey,
                        isSelected: viewModel.previewBackgroundColor == Colors.grey,
                        onTap: () => viewModel.setPreviewBackgroundColor(Colors.grey),
                      ),
                      _ColorButton(
                        color: Colors.blue,
                        isSelected: viewModel.previewBackgroundColor == Colors.blue,
                        onTap: () => viewModel.setPreviewBackgroundColor(Colors.blue),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 排版选项栏
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,  // 使用 Scaffold 的默认背景色
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade800,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('排版模式:', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(width: 10),
                      _ModeButton(
                        mode: DisplayMode.showAll, 
                        isSelected: viewModel.mode == DisplayMode.showAll, 
                        onTap: () => viewModel.setMode(DisplayMode.showAll)
                      ),
                      const SizedBox(width: 12),
                      _ModeButton(
                        mode: DisplayMode.showTop, 
                        isSelected: viewModel.mode == DisplayMode.showTop, 
                        onTap: () => viewModel.setMode(DisplayMode.showTop),
                      ),
                      const SizedBox(width: 12),
                      _ModeButton(
                        mode: DisplayMode.showBottom, 
                        isSelected: viewModel.mode == DisplayMode.showBottom, 
                        onTap: () => viewModel.setMode(DisplayMode.showBottom),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget getPlaceholderWidget(bool isEmptySvga) {
    if (isEmptySvga) {
      return const Center(
        child: Text('拖放SVGA文件到这里\n或点击右下角按钮打开文件'),
      );
    } else {
      return const Center(
        child: Text('该SVGA文件并未包含图片\n🎨🚫', textAlign: TextAlign.center,),
      );
    }
  }
}

class _ModeButton extends StatelessWidget {
  final DisplayMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color color = isSelected ? Colors.blue.shade300 : Colors.grey.shade800;

    IconData? icon;
    switch (mode) {
      case DisplayMode.showAll:
        icon = Icons.vertical_align_center;
        break;
      case DisplayMode.showTop:
        icon = Icons.vertical_align_bottom;
        break;
      case DisplayMode.showBottom:
        icon = Icons.vertical_align_top;
        break;
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          border: Border.all(
            color: color,  
            width: 1.5,           
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Center(
          child: Icon(
            icon,         
            color: color,
            size: 15,
          ),
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade800,
            width: isSelected ? 3 : 2,
          ),
        ),
        child: color == Colors.transparent ? Center(
          child: Transform.rotate(
            angle: -0.785398,
            child: Container(
              width: 28,
              height: 2,
              color: Colors.red,
            ),
          ),
        ) : null,
      ),
    );
  }
} 