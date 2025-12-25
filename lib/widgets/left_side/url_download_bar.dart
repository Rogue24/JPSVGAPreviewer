import 'package:flutter/material.dart';
import 'package:svga_previewer/view_models/svga_view_model.dart';

class UrlDownloadBar extends StatefulWidget {
  final SVGAViewModel viewModel;

  const UrlDownloadBar({super.key, required this.viewModel});

  @override
  State<UrlDownloadBar> createState() => _UrlDownloadBarState();
}

class _UrlDownloadBarState extends State<UrlDownloadBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade800,
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '输入 SVGA 文件 URL (http/https)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onSubmitted: (_) => _startDownload(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: widget.viewModel.isDownloading || _controller.text.trim().isEmpty
                        ? null
                        : _startDownload,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: Text(widget.viewModel.isDownloading ? '下载中...' : '下载并解析'),
                  ),
                  const SizedBox(width: 6),
                  if (widget.viewModel.isDownloading)
                    IconButton(
                      tooltip: '取消下载',
                      icon: const Icon(Icons.cancel_outlined),
                      onPressed: widget.viewModel.cancelDownload,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildProgress(),
              if (widget.viewModel.downloadError != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.viewModel.downloadError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
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
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _startDownload() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    await widget.viewModel.downloadFromUrl(url);
  }
}

