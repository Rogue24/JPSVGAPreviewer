import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/models/animation_type.dart';
import 'package:svga_previewer/view_models/animation_view_model.dart';
import 'package:svga_previewer/widgets/right_side/svga_preview.dart';
import 'package:svga_previewer/widgets/right_side/lottie_preview.dart';
import 'package:svgaplayer_flutter/player.dart';

class AnimationPreview extends StatelessWidget {
  final SVGAAnimationController controller;
  
  const AnimationPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Consumer<AnimationViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.animationType == null) {
          return _buildPlaceholder(viewModel);
        }
          return LayoutBuilder(
            builder: (context, constraints) {
              double width = constraints.maxWidth;
              double height = constraints.maxHeight;
              Size preferredSize;
              
              // 如果宽度或高度为 0，使用默认尺寸
              if (viewModel.frameWidth <= 0 || viewModel.frameHeight <= 0) {
                preferredSize = Size(width - 2, height - 2);
                print('使用默认尺寸: $preferredSize (因为 frameWidth=${viewModel.frameWidth}, frameHeight=${viewModel.frameHeight})');
              } else if (viewModel.frameWidth > viewModel.frameHeight) {
                double ratio = viewModel.frameHeight / viewModel.frameWidth;
                height = width * ratio;
                preferredSize = Size((width - 2), (width - 2) * ratio); // Border宽度是属于内边距，所以减2
              } else {
                double ratio = viewModel.frameWidth / viewModel.frameHeight;
                width = height * ratio;
                preferredSize = Size((height - 2) * ratio, (height - 2)); // Border宽度是属于内边距，所以减2
              }
              return SizedBox(
                width: width,
                height: height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildAnimationPreview(viewModel, preferredSize),
                    _buildBorder(viewModel),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildPlaceholder(AnimationViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        color: viewModel.previewBackgroundColor,
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('无预览'),
      ),
    );
  }

  Widget _buildAnimationPreview(AnimationViewModel viewModel, Size preferredSize) {
    if (viewModel.animationType == AnimationType.svga && viewModel.svgaFile != null) {
      return SVGAPreview(
        controller: controller,
        file: viewModel.svgaFile!,
        preferredSize: preferredSize,
      );
    } else if (viewModel.animationType == AnimationType.lottie && viewModel.lottieFile != null) {
      return LottiePreview(
        file: viewModel.lottieFile!,
        preferredSize: preferredSize,
      );
    } else {
      return const SizedBox();
    }
  }

  Widget _buildBorder(AnimationViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        border: viewModel.showBorder ? Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ) : null,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
} 