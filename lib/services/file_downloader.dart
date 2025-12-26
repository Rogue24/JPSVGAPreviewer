import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:svga_previewer/services/temp_file_manager.dart';

/// 文件下载服务
/// 负责从网络下载文件，支持进度跟踪、取消下载和错误处理
class FileDownloader {
  CancelToken? _cancelToken;
  bool _isDownloading = false;

  /// 下载文件
  /// 
  /// 仅支持 .svga、.lottie、.zip 格式
  /// 
  /// [url] 要下载的文件 URL
  /// [onProgress] 下载进度回调，参数为进度值（0.0-1.0）
  /// [onError] 错误回调，参数为错误消息
  /// 
  /// 返回下载的文件路径，如果失败则返回 null
  Future<String?> download(
    String url, {
    void Function(double progress)? onProgress,
    void Function(String error)? onError,
  }) async {
    if (_isDownloading) {
      onError?.call('已有下载任务正在进行');
      return null;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      onError?.call('无效的URL（仅支持 http/https）');
      return null;
    }

    // 检查文件格式是否支持
    final fileExtension = _detectFileExtension(url);
    if (!_isSupportedFormat(fileExtension)) {
      String errorMessage = '仅支持以下格式：\n• .svga\n• .lottie\n• .zip';
      if (fileExtension.isEmpty) {
        errorMessage += '\n无法从 URL 中检测到文件格式，请确保 URL 包含文件扩展名（如 .svga、.lottie 或 .zip）';
      } else {
        errorMessage += '\n不支持检测到的格式: $fileExtension';
      }
      onError?.call(errorMessage);
      return null;
    }

    _isDownloading = true;
    _cancelToken = CancelToken();

    try {
      final host = uri.host;

      // DNS 解析日志
      try {
        print('开始DNS解析: $host');
        final addresses = await InternetAddress.lookup(host);
        print('DNS解析结果: ${addresses.map((a) => a.address).join(", ")}');
      } catch (e) {
        print('DNS解析失败: $e');
        print('提示: 这是系统 DNS 配置问题，请检查：');
        print('  1. 系统设置 → 网络 → 高级 → DNS');
        print('  2. 确保有可用的 DNS 服务器（如 8.8.8.8, 1.1.1.1）');
        print('  3. 刷新 DNS 缓存: sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder');
      }

      final downloadDir = await TempFileManager.getDownloadDirectory();

      final savePath = path.join(
        downloadDir.path,
        'download_${DateTime.now().millisecondsSinceEpoch}$fileExtension',
      );

      print('开始下载: $url');
      print('检测到文件类型: $fileExtension');
      print('保存路径: $savePath');

      final dio = Dio();

      // 使用 Dio 下载
      await dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': uri.origin,
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress?.call(progress);
            if (received % 100000 == 0 || received == total) {
              print(
                  '下载进度: ${(received / 1024).toStringAsFixed(1)} KB / ${(total / 1024).toStringAsFixed(1)} KB (${(progress * 100).toStringAsFixed(1)}%)');
            }
          } else {
            onProgress?.call(0.0);
          }
        },
      );

      print('下载成功');

      // 文件大小日志
      final downloadedFile = File(savePath);
      if (await downloadedFile.exists()) {
        final fileSize = await downloadedFile.length();
        print(
            '下载完成，文件大小: $fileSize bytes (${(fileSize / 1024).toStringAsFixed(1)} KB)');
      } else {
        print('警告: 下载文件不存在: $savePath');
      }

      _isDownloading = false;
      return savePath;
    } on DioException catch (e) {
      print('下载异常 (DioException): ${e.type} - ${e.message}');
      print('响应状态: ${e.response?.statusCode}');
      print('响应数据: ${e.response?.data}');
      
      String errorMessage;
      if (CancelToken.isCancel(e)) {
        print('下载已取消');
        errorMessage = '下载已取消';
      } else {
        print('下载失败详情: ${e.toString()}');
        // 检查是否是 DNS 解析失败
        final errorMsg = e.message ?? e.toString();
        if (errorMsg.contains('Failed host lookup') ||
            errorMsg.contains('nodename nor servname')) {
          errorMessage =
              'DNS 解析失败\n请检查系统 DNS 配置:\n1. 系统设置 → 网络 → 高级 → DNS\n2. 添加 DNS: 8.8.8.8 或 1.1.1.1\n3. 刷新缓存: sudo dscacheutil -flushcache';
        } else {
          errorMessage = '下载失败: $errorMsg';
        }
      }
      
      _isDownloading = false;
      onError?.call(errorMessage);
      
      // 下载失败，删除下载的文件
      final downloadDir = await TempFileManager.getDownloadDirectory();
      final files = await downloadDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.contains('download_')) {
          await TempFileManager.removeDownloadedFile(file.path);
        }
      }
      
      return null;
    } catch (e, stackTrace) {
      print('下载异常 (其他): $e');
      print('堆栈跟踪: $stackTrace');
      
      String errorMessage;
      // 检查是否是 DNS 解析失败
      final errorStr = e.toString();
      if (errorStr.contains('Failed host lookup') ||
          errorStr.contains('nodename nor servname')) {
        errorMessage =
            'DNS 解析失败\n请检查系统 DNS 配置:\n1. 系统设置 → 网络 → 高级 → DNS\n2. 添加 DNS: 8.8.8.8 或 1.1.1.1\n3. 刷新缓存: sudo dscacheutil -flushcache';
      } else {
        errorMessage = '下载失败: $e';
      }
      
      _isDownloading = false;
      onError?.call(errorMessage);
      
      return null;
    } finally {
      _cancelToken = null;
      print('下载流程结束');
    }
  }

  /// 取消下载
  void cancel() {
    if (_isDownloading &&
        _cancelToken != null &&
        !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('用户取消');
      _isDownloading = false;
    }
  }

  /// 是否正在下载
  bool get isDownloading => _isDownloading;

  /// 检测文件扩展名
  /// 
  /// [url] 文件 URL
  /// 返回文件扩展名（包含点号），如果无法检测则返回空字符串
  String _detectFileExtension(String url) {
    final urlLower = url.toLowerCase();
    
    // 常见文件扩展名列表（按优先级排序，支持的格式优先）
    final extensions = [
      '.svga',
      '.lottie',
      '.zip',
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.json',
      '.json.gz',
      '.mp4',
      '.mov',
      '.avi',
      '.pdf',
      '.txt',
    ];
    
    // 优先从 URL 路径中提取扩展名
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last.toLowerCase();
        // 检查最后一个路径段是否以扩展名结尾
        for (final ext in extensions) {
          if (lastSegment.endsWith(ext)) {
            return ext;
          }
        }
        // 如果没有匹配到已知扩展名，尝试提取最后一个点号后的内容
        final lastDotIndex = lastSegment.lastIndexOf('.');
        if (lastDotIndex > 0 && lastDotIndex < lastSegment.length - 1) {
          final potentialExt = '.${lastSegment.substring(lastDotIndex + 1)}';
          // 只返回有效的扩展名（不包含查询参数等）
          if (potentialExt.length <= 10 && !potentialExt.contains('?')) {
            return potentialExt;
          }
        }
      }
    } catch (e) {
      print('解析 URL 路径失败: $e');
    }
    
    // 如果从路径中无法提取，尝试从整个 URL 中查找
    for (final ext in extensions) {
      if (urlLower.contains(ext)) {
        // 确保扩展名是完整的（后面跟着路径分隔符、查询参数或字符串结尾）
        final index = urlLower.indexOf(ext);
        if (index > 0) {
          final charAfter = index + ext.length < urlLower.length 
              ? urlLower[index + ext.length] 
              : '';
          // 检查扩展名后是否是有效的分隔符（路径分隔符、查询参数或字符串结尾）
          if (charAfter == '' || charAfter == '/' || charAfter == '?' || charAfter == '#') {
            return ext;
          }
        }
      }
    }
    
    // 无法检测到格式
    return '';
  }

  /// 检查文件格式是否支持
  /// 
  /// [extension] 文件扩展名（包含点号）
  /// 返回 true 如果支持，否则返回 false
  bool _isSupportedFormat(String extension) {
    return extension == '.svga' || 
           extension == '.lottie' || 
           extension == '.zip';
  }
}

