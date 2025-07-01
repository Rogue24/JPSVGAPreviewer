import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/view_models/svga_view_model.dart';
import 'package:svga_previewer/widgets/svga_preview.dart';
import 'package:svgaplayer_flutter/player.dart';

class AnimationPreview extends StatelessWidget {
  final SVGAAnimationController controller;
  
  const AnimationPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Consumer<SVGAViewModel>(
        builder: (context, viewModel, child) {
          return Stack(
            alignment: Alignment.center,
            children: _buildWigets(viewModel),
          );
        },
      ),
    );
  }

  List<Widget> _buildWigets(SVGAViewModel viewModel) {
    if (viewModel.svgaFile == null) {
      return [_buildPlaceholder(viewModel)];
    }
    return [
      _buildSVGABackground(viewModel),
      SVGAPreview(controller: controller, file: viewModel.svgaFile!),
    ];
  }

  Widget _buildPlaceholder(SVGAViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        color: viewModel.previewBackgroundColor,
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('无预览'),
      ),
    );
  }

  Widget _buildSVGABackground(SVGAViewModel viewModel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        double height = constraints.maxHeight;
        if (viewModel.frameWidth > viewModel.frameHeight) {
          height = width * (viewModel.frameHeight / viewModel.frameWidth);
        } else {
          width = height * (viewModel.frameWidth / viewModel.frameHeight);
        }
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: viewModel.previewBackgroundColor,
            border: viewModel.showBorder ? Border.all(
              color: Colors.grey.shade800,
              width: 1,
            ) : null,
            borderRadius: viewModel.showBorder ? BorderRadius.circular(4) : null,
          ),
        );
      },
    );
  }
} 