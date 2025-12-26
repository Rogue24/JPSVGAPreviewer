import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:svga_previewer/models/animation_type.dart';
import 'package:svga_previewer/view_models/animation_view_model.dart';
import 'package:lottie/lottie.dart';
import 'dart:io';

class LottiePreview extends StatefulWidget {
  final File file;
  final Size preferredSize;
  
  const LottiePreview({super.key, required this.file, required this.preferredSize});
  
  @override
  State<LottiePreview> createState() => _LottiePreviewState();
}

class _LottiePreviewState extends State<LottiePreview> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Duration? _originalDuration;
  double _currentAppliedSpeed = 1.0;
  bool _listenerAdded = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _loadLottie();
  }

  /// 更新播放状态到 ViewModel
  void _updatePlayState() {
    if (!mounted) return;
    final viewModel = Provider.of<AnimationViewModel>(context, listen: false);
    final totalFrames = viewModel.totalFrames;
    viewModel.updateLottiePlayState(
      _controller.isAnimating,
      _controller.value,
      totalFrames > 0 ? totalFrames : 1,
    );
  }

  @override
  void didUpdateWidget(LottiePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      print("LottiePreview didUpdateWidget: Lottie文件【已】变化");
      _loadLottie();
    } else {
      print("LottiePreview didUpdateWidget: Lottie文件【未】变化");
    }
  }
  
  Future<void> _loadLottie() async {
    try {
      _controller.reset();
      // Lottie widget 会自动加载文件，我们只需要设置 controller
      // 通过 onLoaded 回调获取 composition 信息
      print("LottiePreview 开始加载文件: ${widget.file.path}");
    } catch (e) {
      print('LottiePreview 加载Lottie文件失败: $e');
    }
  }

  /// 应用播放速度到controller
  void _applyPlaybackSpeed(double speed, {Duration? compositionDuration}) {
    final duration = compositionDuration ?? _originalDuration;
    if (duration == null) {
      print("原始duration未保存，跳过速度应用");
      return;
    }
    
    if (_currentAppliedSpeed == speed && _originalDuration != null) {
      return; // 已经应用了相同的速度，跳过
    }
    
    try {
      // 基于原始duration计算新duration
      final newDuration = Duration(
        milliseconds: (duration.inMilliseconds / speed).round(),
      );
      
      // 保存当前播放状态
      final wasAnimating = _controller.isAnimating;
      final currentValue = _controller.value;
      
      // 停止当前动画
      if (wasAnimating) {
        _controller.stop();
      }
      
      // 设置新的duration
      _controller.duration = newDuration;
      
      // 恢复播放位置
      _controller.value = currentValue;
      
      // 如果之前在播放，继续播放
      if (wasAnimating) {
        _controller.repeat();
      }
      
      _currentAppliedSpeed = speed;
      if (_originalDuration == null) {
        _originalDuration = duration;
      }
      print("LottiePreview 成功应用播放速度: ${speed}x, 新duration: ${newDuration.inMilliseconds}ms");
    } catch (e) {
      print("LottiePreview 应用播放速度失败: $e");
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // 添加监听器来更新播放状态（只添加一次）
    if (!_listenerAdded) {
      _controller.addListener(_updatePlayState);
      _listenerAdded = true;
    }
    
    return Consumer<AnimationViewModel>(
      builder: (context, viewModel, child) {
        // 注册控制回调（只在首次构建时注册）
        if (viewModel.animationType == AnimationType.lottie) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            viewModel.registerLottieCallbacks(
              onPlay: () {
                if (_controller.isCompleted) {
                  _controller.reset();
                }
                _controller.repeat();
              },
              onPause: () {
                _controller.stop();
              },
              onSeek: (value) {
                _controller.stop();
                _controller.value = value.clamp(0.0, 1.0);
              },
            );
          });
        }

        // 监听播放速度变化并自动应用
        if (_originalDuration != null && viewModel.playbackSpeed != _currentAppliedSpeed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyPlaybackSpeed(viewModel.playbackSpeed);
          });
        } else if (_originalDuration == null && _controller.duration != null) {
          // 如果 duration 已设置但 _originalDuration 未设置，更新它
          _originalDuration = _controller.duration;
        }
        
        print('LottiePreview build: file=${widget.file.path}, size=${widget.preferredSize}');
        
        return Container(
          width: widget.preferredSize.width,
          height: widget.preferredSize.height,
          decoration: BoxDecoration(
            color: viewModel.previewBackgroundColor,
            borderRadius: viewModel.showBorder ? BorderRadius.circular(6) : null,
          ),
          clipBehavior: viewModel.allowDrawingOverflow ? Clip.none : Clip.hardEdge,
          child: widget.file.existsSync()
              ? Lottie.file(
                  widget.file,
                  controller: _controller,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  onLoaded: (composition) {
                    // 当动画加载完成时，设置 duration 并应用播放速度
                    try {
                      final duration = composition.duration;
                      print('Lottie 动画加载成功: duration=$duration, size=${widget.preferredSize}');
                      
                      // 验证 duration 是否有效
                      if (duration.inMilliseconds > 0 && duration.inMilliseconds.isFinite) {
                        if (_originalDuration == null) {
                          _originalDuration = duration;
                          _controller.duration = duration;
                          _applyPlaybackSpeed(viewModel.playbackSpeed, compositionDuration: duration);
                          _controller.repeat();
                          print('Lottie 动画开始播放');
                        }
                      } else {
                        print('警告: Lottie duration 无效: $duration');
                      }
                    } catch (e) {
                      print('Lottie onLoaded 回调出错: $e');
                    }
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('Lottie 加载错误: $error');
                    print('文件路径: ${widget.file.path}');
                    print('文件存在: ${widget.file.existsSync()}');
                    print('堆栈跟踪: $stackTrace');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            '加载失败: $error',
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        '文件不存在: ${widget.file.path}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
        );
      }
    );
  }
}

