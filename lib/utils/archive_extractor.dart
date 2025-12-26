import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

/// 归档文件提取工具
/// 用于从 ZIP 和 GZIP 归档中提取文件，特别是 Lottie 动画的资源文件
class ArchiveExtractor {
  /// 从 ZIP 归档中提取 Lottie 图片资源
  /// 
  /// 支持嵌套目录结构（如 "folder/images/file.png"）
  /// 会将所有图片统一提取到目标目录的 images/ 文件夹中
  /// 
  /// [archive] ZIP 归档对象
  /// [tempDirPath] 临时目录路径
  /// 返回提取的图片目录路径，如果没有图片则返回 null
  static Future<String?> extractLottieImages(
      Archive archive, String tempDirPath) async {
    final imagesDir = Directory('$tempDirPath/images');
    bool hasImages = false;

    // 查找所有包含 images/ 的路径（支持嵌套目录）
    String? imagesBasePath; // 存储找到的 images 文件夹的基础路径

    for (final file in archive) {
      final fileName = file.name;
      final fileNameLower = fileName.toLowerCase();

      // 跳过目录条目和 macOS 系统文件
      if (!file.isFile ||
          fileNameLower.contains('__macosx') ||
          fileNameLower.contains('/._')) {
        continue;
      }

      // 检查是否是 images/ 文件夹中的文件（支持嵌套目录，如 "folder/images/file.png"）
      if (fileNameLower.contains('/images/')) {
        // 提取 images/ 之后的部分作为相对路径
        final imagesIndex = fileNameLower.indexOf('/images/');
        final relativePath = fileName.substring(imagesIndex + 8); // +8 是 "/images/" 的长度

        // 如果这是第一个找到的图片，记录基础路径
        if (!hasImages) {
          imagesBasePath = fileName.substring(0, imagesIndex + 8); // 包含 "/images/"
          print('找到 images 文件夹路径: $imagesBasePath');
        }

        hasImages = true;
        // 创建统一的 images/ 目录结构（去掉嵌套的父目录）
        final targetPath = path.join(tempDirPath, 'images', relativePath);
        final targetFile = File(targetPath);
        final targetDir = targetFile.parent;

        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        // 写入文件
        if (file.content is List<int>) {
          await targetFile.writeAsBytes(file.content as List<int>);
          print('提取图片资源: $fileName -> $targetPath');
        }
      } else if (fileNameLower.startsWith('images/')) {
        // 处理根目录下的 images/ 文件夹
        hasImages = true;
        final relativePath = fileName.substring(7); // 去掉 "images/" 前缀
        final targetPath = path.join(tempDirPath, 'images', relativePath);
        final targetFile = File(targetPath);
        final targetDir = targetFile.parent;

        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        if (file.content is List<int>) {
          await targetFile.writeAsBytes(file.content as List<int>);
          print('提取图片资源: $fileName -> $targetPath');
        }
      }
    }

    if (hasImages) {
      return imagesDir.path;
    }
    return null;
  }

  /// 递归复制目录
  /// 
  /// [source] 源目录
  /// [target] 目标目录
  static Future<void> copyDirectory(
      Directory source, Directory target) async {
    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final targetPath = path.join(target.path, path.basename(entity.path));
      if (entity is Directory) {
        await copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }
}

