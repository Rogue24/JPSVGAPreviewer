import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 临时文件管理器
/// 负责管理应用运行时产生的临时文件，包括帧图片、Lottie 提取文件等
class TempFileManager {
  /// 清理所有临时文件
  /// 
  /// 包括：
  /// - SVGA 帧目录
  /// - Lottie 帧目录
  /// - Lottie 提取目录
  /// - 临时 JSON 文件
  /// - 临时 images 目录
  static Future<void> clearAllTempFiles() async {
    print('开始清理临时文件...');
    
    try {
      final tempDir = await getTemporaryDirectory();
      
      // 清理 SVGA 帧目录
      final framesDir = Directory('${tempDir.path}/svga_frames');
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
        print('SVGA 临时目录已删除');
      }
      
      // 清理 Lottie 帧目录
      final lottieFramesDir = Directory('${tempDir.path}/lottie_frames');
      if (await lottieFramesDir.exists()) {
        await lottieFramesDir.delete(recursive: true);
        print('Lottie 临时目录已删除');
      }
      
      // 清理 Lottie 提取目录
      final lottieExtractedDir = Directory('${tempDir.path}/lottie_extracted');
      if (await lottieExtractedDir.exists()) {
        await lottieExtractedDir.delete(recursive: true);
        print('Lottie 提取目录已删除');
      }
      
      // 清理临时 JSON 文件（lottie_*.json）
      try {
        final tempDirList = await tempDir.list().toList();
        for (final entity in tempDirList) {
          if (entity is File &&
              entity.path.contains('lottie_') &&
              entity.path.endsWith('.json')) {
            await entity.delete();
            print('删除临时 JSON 文件: ${entity.path}');
          }
          // 同时清理可能存在的 images 目录（在 JSON 文件旁边）
          if (entity is Directory &&
              entity.path.contains('lottie_') &&
              path.basename(entity.path) == 'images') {
            await entity.delete(recursive: true);
            print('删除临时 images 目录: ${entity.path}');
          }
        }
      } catch (e) {
        print('清理临时 JSON 文件失败: $e');
      }
    } catch (e) {
      print('清理临时目录失败: $e');
    }
    
    print('临时文件清理完成');
  }

  /// 清理下载文件
  /// 
  /// [filePath] 要删除的下载文件路径
  static Future<void> removeDownloadedFile(String? filePath) async {
    if (filePath == null) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('删除下载文件: $filePath');
      }
    } catch (e) {
      print('删除下载文件失败: $e');
    }
  }

  /// 获取 SVGA 帧目录路径
  /// 
  /// 如果目录不存在则创建
  static Future<Directory> getSVGAFramesDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final framesDir = Directory('${tempDir.path}/svga_frames');
    if (await framesDir.exists()) {
      await framesDir.delete(recursive: true);
    }
    await framesDir.create(recursive: true);
    return framesDir;
  }

  /// 获取 Lottie 帧目录路径
  /// 
  /// 如果目录不存在则创建
  static Future<Directory> getLottieFramesDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final framesDir = Directory('${tempDir.path}/lottie_frames');
    if (await framesDir.exists()) {
      await framesDir.delete(recursive: true);
    }
    await framesDir.create(recursive: true);
    return framesDir;
  }

  /// 获取 Lottie 提取目录路径
  /// 
  /// 如果目录不存在则创建
  static Future<Directory> getLottieExtractedDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final extractedDir = Directory('${tempDir.path}/lottie_extracted');
    if (await extractedDir.exists()) {
      await extractedDir.delete(recursive: true);
    }
    await extractedDir.create(recursive: true);
    return extractedDir;
  }

  /// 获取下载目录路径
  /// 
  /// 如果目录不存在则创建
  static Future<Directory> getDownloadDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final downloadDir = Directory('${tempDir.path}/svga_downloads');
    if (await downloadDir.exists()) {
      await downloadDir.delete(recursive: true);
    }
    await downloadDir.create(recursive: true);
    return downloadDir;
  }

  /// 创建临时 JSON 文件
  /// 
  /// [content] JSON 内容
  /// 返回创建的临时文件
  static Future<File> createTempJsonFile(String content) async {
    final tempDir = await getTemporaryDirectory();
    final jsonFile = File(
        '${tempDir.path}/lottie_${DateTime.now().millisecondsSinceEpoch}.json');
    await jsonFile.writeAsString(content);
    return jsonFile;
  }
}

