import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/models/animation_type.dart';
import 'package:svga_previewer/view_models/animation_view_model.dart';

class SVGAInfoBar extends StatelessWidget {
  const SVGAInfoBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black45,
      child: Consumer<AnimationViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.currentFileName == null) return const Row();
          return Row(
            children: [
              Icon(viewModel.animationType == AnimationType.lottie ? Icons.animation : Icons.movie_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          viewModel.currentFileName!,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: viewModel.animationType == AnimationType.lottie 
                                ? Colors.blue.shade900 
                                : Colors.purple.shade900,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            viewModel.animationType == AnimationType.lottie ? 'Lottie' : 'SVGA',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _infoText(viewModel),
                      style: const TextStyle(color: Colors.grey, fontSize: 12,),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fileSizeText(viewModel),
                      style: const TextStyle(color: Colors.orange, fontSize: 11,),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _totalFramesText(viewModel),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          );
        },
      ),
    );
  }

  String _infoText(AnimationViewModel viewModel) {
    return '帧率: ${viewModel.fps.toStringAsFixed(1)} FPS  •  时长: ${viewModel.duration.toStringAsFixed(2)}秒  •  分辨率: ${viewModel.frameWidth}x${viewModel.frameHeight}';
  }

  String _fileSizeText(AnimationViewModel viewModel) {
    final fileType = viewModel.animationType == AnimationType.lottie ? 'Lottie文件' : 'SVGA文件';
    return '$fileType: ${viewModel.svgaFileSizeText}  •  临时文件: ${viewModel.totalFileSizeMB.toStringAsFixed(1)}MB  •  内存: ${viewModel.memoryUsage.toStringAsFixed(1)}MB';
  }

  String _totalFramesText(AnimationViewModel viewModel) {
    return '总帧数: ${viewModel.totalFrames}';
  }
}