import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/view_models/svga_view_model.dart';

class SVGAInfoBar extends StatelessWidget {
  const SVGAInfoBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black45,
      child: Consumer<SVGAViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.currentFileName == null) return const Row();
          return Row(
            children: [
              const Icon(Icons.movie_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.currentFileName!,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _infoText(viewModel),
                      style: const TextStyle(color: Colors.grey, fontSize: 12,),
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

  String _infoText(SVGAViewModel viewModel) {
    return '帧率: ${viewModel.fps.toStringAsFixed(1)} FPS  •  时长: ${viewModel.duration.toStringAsFixed(2)}秒  •  内存: ${viewModel.memoryUsage.toStringAsFixed(1)}MB •  分辨率: ${viewModel.frameWidth}x${viewModel.frameHeight}';
  }

  String _totalFramesText(SVGAViewModel viewModel) {
    return '总帧数: ${viewModel.totalFrames}';
  }
}