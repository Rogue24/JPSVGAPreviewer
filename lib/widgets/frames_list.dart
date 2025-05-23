import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/svga_view_model.dart';
import 'package:flutter/cupertino.dart';

class FramesList extends StatelessWidget {
  const FramesList({super.key});

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