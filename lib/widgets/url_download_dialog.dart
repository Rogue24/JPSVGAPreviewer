import 'package:flutter/material.dart';
import 'package:svga_previewer/view_models/svga_view_model.dart';

class UrlDownloadDialog extends StatefulWidget {
  final SVGAViewModel viewModel;

  const UrlDownloadDialog({super.key, required this.viewModel});

  @override
  State<UrlDownloadDialog> createState() => _UrlDownloadDialogState();
}

class _UrlDownloadDialogState extends State<UrlDownloadDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isButtonEnabled = false;
  double _dialogWidth = 600;
  double _dialogHeight = 400;

  @override
  void initState() {
    super.initState();
    // 清理之前的下载状态
    widget.viewModel.clearDownloadState();
    // 清空输入框
    _controller.clear();
    _isButtonEnabled = false;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final newValue = _controller.text.trim().isNotEmpty && !widget.viewModel.isDownloading;
    if (_isButtonEnabled != newValue) {
      setState(() {
        _isButtonEnabled = newValue;
      });
    }
  }

  Future<void> _startDownload() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    
    await widget.viewModel.downloadFromUrl(url);
    
    // 如果下载成功且没有错误，关闭对话框
    if (!widget.viewModel.isDownloading && widget.viewModel.downloadError == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            width: _dialogWidth,
            height: _dialogHeight,
            constraints: const BoxConstraints(
              minWidth: 400,
              minHeight: 300,
              maxWidth: 1000,
              maxHeight: 800,
            ),
            child: Stack(
              children: [
                Column(
                  children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade800, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '从 URL 下载 SVGA 文件',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            // 内容区域
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '输入 SVGA 文件 URL:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'https://example.com/file.svga',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: 3,
                      onSubmitted: (_) => _startDownload(),
                    ),
                    const SizedBox(height: 16),
                    // 进度条
                    AnimatedBuilder(
                      animation: widget.viewModel,
                      builder: (context, child) {
                        return _buildProgress();
                      },
                    ),
                    // 错误信息
                    AnimatedBuilder(
                      animation: widget.viewModel,
                      builder: (context, child) {
                        if (widget.viewModel.downloadError != null) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade700, width: 1),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.viewModel.downloadError!,
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                    const Spacer(),
                    // 按钮区域
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        AnimatedBuilder(
                          animation: widget.viewModel,
                          builder: (context, child) {
                            final isDownloading = widget.viewModel.isDownloading;
                            final canDownload = _isButtonEnabled && !isDownloading;
                            
                            return FilledButton(
                              onPressed: canDownload ? _startDownload : null,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDownloading) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(isDownloading ? '下载中...' : '下载并解析'),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        AnimatedBuilder(
                          animation: widget.viewModel,
                          builder: (context, child) {
                            if (widget.viewModel.isDownloading) {
                              return IconButton(
                                icon: const Icon(Icons.cancel_outlined),
                                onPressed: widget.viewModel.cancelDownload,
                                tooltip: '取消下载',
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
                  ],
                ),
                // 调整大小手柄（右下角）
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setDialogState(() {
                        _dialogWidth = (_dialogWidth + details.delta.dx).clamp(400.0, 1000.0);
                        _dialogHeight = (_dialogHeight + details.delta.dy).clamp(300.0, 800.0);
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Icon(
                          Icons.drag_handle,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgress() {
    final isDownloading = widget.viewModel.isDownloading;
    final progress = widget.viewModel.downloadProgress;
    final showProgress = isDownloading || progress > 0;
    if (!showProgress) return const SizedBox();

    final percentText = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress > 0 ? progress.clamp(0, 1) : null,
          minHeight: 6,
          backgroundColor: Colors.grey.shade900,
          color: Colors.deepPurpleAccent.shade200,
        ),
        const SizedBox(height: 4),
        Text(
          isDownloading ? '下载中... $percentText%' : '下载完成',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

