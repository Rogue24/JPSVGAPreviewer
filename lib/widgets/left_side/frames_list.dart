import 'package:flutter/material.dart';
import 'package:svga_previewer/view_models/animation_view_model.dart';

class FramesList extends StatelessWidget {
  final AnimationViewModel viewModel;

  const FramesList({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: ValueKey(viewModel.currentFileName),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8, // 调整比例以容纳更多文字信息
      ),
      itemCount: viewModel.frames.length,
      itemBuilder: (context, index) {
        final frameInfo = viewModel.frameInfos.isNotEmpty ? viewModel.frameInfos[index] : null;
        return InkWell(
          onTap: () => viewModel.setCurrentFrameIndex(index),
          child: Container(
            decoration: BoxDecoration(
              border: index == viewModel.currentFrameIndex
                  ? Border.all(
                      color: Colors.deepPurpleAccent.shade200,
                      width: 2,
                    )
                  : null,
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
                  child: Column(
                    children: [
                      Text(
                        '图 ${index + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (frameInfo != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          frameInfo.fileSizeText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: Colors.orange),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}