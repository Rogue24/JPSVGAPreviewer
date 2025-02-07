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
            Center(
              child: viewModel.currentFrame == null
                  ? const Text('无预览内容')
                  : Image.file(
                      viewModel.currentFrame!,
                      key: ValueKey('preview_${viewModel.currentFileName}_${viewModel.currentFrameIndex}'),
                      fit: BoxFit.contain,
                      cacheWidth: null,
                      cacheHeight: null,
                      gaplessPlayback: false,
                    ),
            ),
            if (viewModel.currentFrame != null)
              Positioned(
                left: 8,
                top: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<ui.Image>(
                            future: decodeImageFromList(viewModel.currentFrame!.readAsBytesSync()).then((value) => value),
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
                                      '当前帧: ${viewModel.currentFrameIndex + 1}  •  尺寸: ${image.width} × ${image.height}',
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
} 