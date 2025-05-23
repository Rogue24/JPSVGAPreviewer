import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/svga_view_model.dart';
import 'dart:ui' as ui show Image;

class FramePreview extends StatelessWidget {
  const FramePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SVGAViewModel>(
      builder: (context, viewModel, child) {
        return Stack(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              child: Center(
                child: viewModel.currentFrame == null
                    ? const Text('无预览内容')
                    : Container(
                        decoration: BoxDecoration(
                          color: viewModel.previewBackgroundColor,
                          border: viewModel.showBorder ? Border.all(
                            color: Colors.grey.shade800,
                            width: 1,
                          ) : null,
                          borderRadius: viewModel.showBorder ? BorderRadius.circular(4) : null,
                        ),
                        child: Image.file(
                          viewModel.currentFrame!,
                          key: ValueKey('preview_${viewModel.currentFileName}_${viewModel.currentFrameIndex}'),
                          fit: BoxFit.contain,
                          cacheWidth: null,
                          cacheHeight: null,
                          gaplessPlayback: false,
                        ),
                      ),
              ),
            ),
            if (viewModel.currentFrame != null)
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black45,
                  child: FutureBuilder<ui.Image>(
                    future: viewModel.currentFrame!.readAsBytes().then((bytes) => decodeImageFromList(bytes)),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final image = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              viewModel.currentFrame!.uri.pathSegments.last,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '图片: ${viewModel.currentFrameIndex + 1}  •  尺寸: ${image.width} × ${image.height}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
} 