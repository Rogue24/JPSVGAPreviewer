import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:svga_previewer/models/animation_metadata.dart';
import 'package:svga_previewer/models/animation_type.dart';
import 'package:svga_previewer/models/frame_info.dart';
import 'package:svga_previewer/services/parsers/animation_parser.dart';
import 'package:svga_previewer/services/parsers/animation_parse_result.dart';
import 'package:svga_previewer/services/temp_file_manager.dart';
import 'package:svga_previewer/utils/archive_extractor.dart';
import 'package:svga_previewer/utils/file_type_detector.dart';
import 'package:flutter/material.dart';

/// Lottie 动画解析器
/// 负责解析 Lottie 格式的动画文件，支持 .json, .lottie, .zip, .json.gz 格式
class LottieParser implements AnimationParser {
  @override
  bool canParse(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.json' ||
        ext == '.lottie' ||
        filePath.toLowerCase().endsWith('.json.gz') ||
        ext == '.zip';
  }

  @override
  Future<AnimationParseResult> parse(String filePath) async {
    print('开始处理新的Lottie文件: ${path.basename(filePath)}');

    try {
      // 清空图片缓存
      imageCache.clear();
      imageCache.clearLiveImages();
      print('图片缓存已清空');

      // 获取原始文件大小
      final originalFile = File(filePath);
      int fileSizeBytes = 0;
      if (await originalFile.exists()) {
        fileSizeBytes = await originalFile.length();
        print('Lottie文件大小: $fileSizeBytes bytes');
      }

      // 读取 Lottie JSON 内容（同时提取图片资源）
      print('开始读取 Lottie 文件内容...');
      final readResult = await _readLottieContent(filePath, extractImages: true);
      final jsonString = readResult.jsonContent;
      final lottieImagesDir = readResult.imagesDir;
      print('JSON 内容长度: ${jsonString.length} 字符');

      // 如果是 ZIP 格式（.lottie 或 .zip），需要将 JSON 保存到临时文件
      final ext = path.extension(filePath).toLowerCase();
      String? targetImagesDirPath; // 保存目标图片目录路径，供后续使用
      File? lottieJsonFile;

      if (ext == '.lottie' || ext == '.zip') {
        // 解析 JSON 以检查和修复图片路径
        Map<String, dynamic> jsonData = json.decode(jsonString);

        // 检查并修复 assets 中的图片路径
        // 只有在确实提取到了 images 文件夹时才修复路径
        String processedJsonString = jsonString;
        if (jsonData.containsKey('assets') && lottieImagesDir != null) {
          final assets = jsonData['assets'] as List<dynamic>?;
          if (assets != null) {
            print('检查 assets 中的图片路径，共 ${assets.length} 个资源...');
            bool hasImages = false;
            for (var asset in assets) {
              if (asset is Map<String, dynamic>) {
                final p = asset['p'] as String?; // 图片文件名
                final u = asset['u'] as String?; // 图片路径（目录）

                // 检查是否是图片资源（有 p 字段且是图片格式）
                if (p != null &&
                    (p.toLowerCase().endsWith('.png') ||
                        p.toLowerCase().endsWith('.jpg') ||
                        p.toLowerCase().endsWith('.jpeg'))) {
                  hasImages = true;
                  // 确保路径是 images/（相对于 JSON 文件）
                  String newPath = 'images/';

                  // 如果原路径不是 images/，更新它
                  if (u != newPath) {
                    asset['u'] = newPath;
                    print('更新图片路径: ${u ?? "(空)"} -> $newPath (文件: $p)');
                  } else {
                    print('图片路径已正确: $newPath$p');
                  }
                }
              }
            }
            if (hasImages) {
              // 重新编码 JSON
              processedJsonString = json.encode(jsonData);
              print('已修复 JSON 中的图片路径');
            } else {
              print('未找到图片资源引用');
            }
          }
        } else if (jsonData.containsKey('assets')) {
          print('JSON 包含 assets，但未提取到 images 文件夹，保持原始路径');
        }

        // 创建临时 JSON 文件
        lottieJsonFile = await TempFileManager.createTempJsonFile(processedJsonString);
        print('已将 Lottie JSON 保存到临时文件: ${lottieJsonFile.path}');

        // 如果提取了图片资源，需要先复制图片，然后再设置 lottieFile
        if (lottieImagesDir != null) {
          // 注意：Lottie 库会自动在 JSON 文件所在目录查找 images/ 文件夹
          // 所以我们需要将 images 文件夹复制到 JSON 文件所在目录
          final jsonDir = lottieJsonFile.parent;
          final targetImagesDir = Directory('${jsonDir.path}/images');
          targetImagesDirPath = targetImagesDir.path; // 保存路径供后续使用

          if (await Directory(lottieImagesDir).exists()) {
            // 如果目标目录已存在，先删除
            if (await targetImagesDir.exists()) {
              await targetImagesDir.delete(recursive: true);
            }

            // 复制图片目录（必须在设置 lottieFile 之前完成）
            print('开始复制图片资源...');
            print('源目录: $lottieImagesDir');
            print('目标目录: ${targetImagesDir.path}');
            await ArchiveExtractor.copyDirectory(
                Directory(lottieImagesDir), targetImagesDir);
            print('已将图片资源复制到: ${targetImagesDir.path}');

            // 验证图片是否复制成功
            if (await targetImagesDir.exists()) {
              final imageFiles = await targetImagesDir.list().toList();
              print('图片目录包含 ${imageFiles.length} 个文件/目录');
              for (final file in imageFiles.take(5)) {
                if (file is File) {
                  print('  - ${file.path} (${await file.length()} bytes)');
                }
              }
            } else {
              print('警告: 目标图片目录不存在: ${targetImagesDir.path}');
            }
          } else {
            print('警告: 源图片目录不存在: $lottieImagesDir');
          }
        } else {
          print('未提取到图片资源，跳过图片复制');
        }
      } else {
        // 直接使用原始文件
        lottieJsonFile = originalFile;
        print('使用原始 JSON 文件: ${originalFile.path}');
      }

      // 解析 JSON
      print('开始解析 JSON 数据...');
      Map<String, dynamic> lottieData;
      try {
        lottieData = json.decode(jsonString) as Map<String, dynamic>;
        print('JSON 解析成功，包含 ${lottieData.length} 个键');
      } catch (e) {
        print('JSON 解析失败: $e');
        print(
            'JSON 内容前 500 字符: ${jsonString.substring(0, jsonString.length > 500 ? 500 : jsonString.length)}');
        rethrow;
      }

      // 解析 Lottie 信息
      print('开始解析 Lottie 动画信息...');
      print('JSON 键列表: ${lottieData.keys.toList()}');

      final width = (lottieData['w'] as num?)?.toDouble() ?? 0.0;
      final height = (lottieData['h'] as num?)?.toDouble() ?? 0.0;
      final frameRate = (lottieData['fr'] as num?)?.toDouble() ?? 60.0;
      final inPoint = (lottieData['ip'] as num?)?.toInt() ?? 0;
      final outPoint = (lottieData['op'] as num?)?.toInt() ?? 0;

      print(
          '原始值 - w: $width, h: $height, fr: $frameRate, ip: $inPoint, op: $outPoint');

      final frameWidth = width.toInt();
      final frameHeight = height.toInt();
      final fps = frameRate > 0 ? frameRate : 60.0; // 确保 FPS 不为 0
      final totalFrames = outPoint > inPoint ? (outPoint - inPoint) : 0;
      // 计算时长，避免除以 0
      final duration = totalFrames > 0 && fps > 0 ? totalFrames / fps : 0.0;

      print(
          'Lottie信息: ${frameWidth}x${frameHeight}, FPS: $fps, 总帧数: $totalFrames, 时长: ${duration}秒');

      // 验证关键信息
      if (frameWidth == 0 || frameHeight == 0) {
        print('警告: 宽度或高度为 0，可能是 JSON 格式问题');
      }
      if (totalFrames == 0) {
        print('警告: 总帧数为 0，可能是 JSON 格式问题');
      }

      // 创建临时目录
      final framesDir = await TempFileManager.getLottieFramesDirectory();
      print('创建新的临时目录: ${framesDir.path}');

      // 提取帧和图片资源
      final List<File> tempFrames = [];
      final List<FrameInfo> tempFrameInfos = [];
      double totalFileSizeBytes = 0;
      double memoryUsageMB = 0.0;

      print('开始处理 Lottie 图片资源...');

      // 如果提取了图片资源，将这些图片添加到帧列表中
      // 优先使用复制后的目标目录，如果没有则使用原始提取目录
      String? imagesDirToUse = targetImagesDirPath ?? lottieImagesDir;

      if (imagesDirToUse != null && await Directory(imagesDirToUse).exists()) {
        print('开始加载 images 文件夹中的图片...');
        print('使用图片目录: $imagesDirToUse');
        final imageFiles = await Directory(imagesDirToUse).list().toList();

        // 过滤出图片文件并按文件名排序
        final imageFileList = imageFiles
            .whereType<File>()
            .where((file) {
              final ext = path.extension(file.path).toLowerCase();
              return ext == '.png' ||
                  ext == '.jpg' ||
                  ext == '.jpeg' ||
                  ext == '.webp';
            })
            .toList();

        // 按文件名排序
        imageFileList
            .sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));

        print('找到 ${imageFileList.length} 个图片文件');

        for (var imageFile in imageFileList) {
          try {
            // 读取图片信息
            final bytes = await imageFile.readAsBytes();
            final codec = await instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();

            // 计算内存占用
            final frameMemoryMB =
                (frame.image.width * frame.image.height * 4) / (1024 * 1024);
            memoryUsageMB += frameMemoryMB;

            // 获取文件大小
            final fileSizeBytes = await imageFile.length();
            totalFileSizeBytes += fileSizeBytes;

            // 添加到帧列表
            tempFrames.add(imageFile);

            // 创建帧信息
            final frameInfo = FrameInfo(
              file: imageFile,
              fileSizeBytes: fileSizeBytes,
              memoryUsageMB: frameMemoryMB,
              width: frame.image.width,
              height: frame.image.height,
            );
            tempFrameInfos.add(frameInfo);

            print(
                '添加图片: ${path.basename(imageFile.path)} (${frame.image.width}x${frame.image.height}, ${frameInfo.fileSizeText})');
          } catch (e) {
            print('处理图片 ${imageFile.path} 时出错: $e');
          }
        }
      }

      if (tempFrames.isEmpty) {
        print('未能从Lottie文件中提取到任何图片');
      } else {
        print('成功加载了 ${tempFrames.length} 个图片文件');
        final totalFileSizeMB = totalFileSizeBytes / (1024 * 1024);
        print('临时文件总大小: ${totalFileSizeMB.toStringAsFixed(1)} MB');
      }

      imageCache.clear();
      imageCache.clearLiveImages();
      print('再次清空图片缓存');

      // 创建元数据
      final metadata = AnimationMetadata(
        width: frameWidth,
        height: frameHeight,
        fps: fps,
        totalFrames: totalFrames,
        duration: duration,
        fileSizeBytes: fileSizeBytes,
        memoryUsageMB: memoryUsageMB,
        totalFileSizeMB: totalFileSizeBytes / (1024 * 1024),
      );

      return AnimationParseResult(
        animationType: AnimationType.lottie,
        metadata: metadata,
        animationFile: lottieJsonFile,
        frames: tempFrames,
        frameInfos: tempFrameInfos,
        lottieImagesDir: targetImagesDirPath ?? lottieImagesDir,
      );
    } catch (e) {
      print('处理Lottie文件时出错: $e');
      print(e.toString());
      rethrow;
    }
  }

  /// 读取 Lottie 文件内容
  /// 
  /// [filePath] 文件路径
  /// [extractImages] 是否提取图片资源
  /// 返回读取结果，包含 JSON 内容和图片目录路径
  Future<_LottieReadResult> _readLottieContent(String filePath,
      {bool extractImages = true}) async {
    final ext = path.extension(filePath).toLowerCase();
    final file = File(filePath);

    if (ext == '.gz' || filePath.toLowerCase().endsWith('.json.gz')) {
      // 处理 .json.gz 文件
      final bytes = await file.readAsBytes();
      final gzipDecoder = GZipDecoder();
      final decompressed = gzipDecoder.decodeBytes(bytes);
      return _LottieReadResult(
        jsonContent: utf8.decode(decompressed),
        imagesDir: null,
      );
    } else if (ext == '.lottie' || ext == '.zip') {
      // 处理 .lottie 或 .zip 文件（ZIP 格式）
      print('开始处理 ZIP 格式文件: $filePath');
      final bytes = await file.readAsBytes();
      print('ZIP 文件大小: ${bytes.length} bytes');

      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
        print('ZIP 文件解压成功，包含 ${archive.length} 个文件');
      } catch (e) {
        print('ZIP 文件解压失败: $e');
        throw Exception('无法解压 ZIP 文件: $e');
      }

      // 列出所有文件
      print('ZIP 文件内容:');
      for (final file in archive) {
        print('  - ${file.name} (${file.isFile ? "文件" : "目录"})');
      }

      // 检测是否为 Lottie 格式
      if (ext == '.zip' && !FileTypeDetector.isLottieZip(archive)) {
        throw Exception('ZIP 文件不是有效的 Lottie 格式（未找到 data.json）');
      }

      // 提取图片资源（如果存在）
      String? lottieImagesDir;
      if (extractImages) {
        final lottieTempDir = await TempFileManager.getLottieExtractedDirectory();
        lottieImagesDir =
            await ArchiveExtractor.extractLottieImages(archive, lottieTempDir.path);
        if (lottieImagesDir != null) {
          print('已提取图片资源到: $lottieImagesDir');
        } else {
          print('ZIP 文件中没有图片资源');
        }
      }

      // 优先查找 data.json 文件（标准 Lottie ZIP 格式，支持嵌套目录）
      String? jsonContent;
      for (final file in archive) {
        final fileName = file.name;
        final fileNameLower = fileName.toLowerCase();
        // 跳过 macOS 系统文件
        if (fileNameLower.contains('__macosx') ||
            fileNameLower.contains('/._')) {
          continue;
        }
        // 支持根目录和嵌套目录中的 data.json
        if (fileName == 'data.json' || fileNameLower.endsWith('/data.json')) {
          jsonContent = utf8.decode(file.content as List<int>);
          print('找到 data.json 文件: ${file.name}，大小: ${jsonContent.length} 字符');
          break;
        }
      }

      // 如果找不到 data.json，查找 animations/animation.json（.lottie 新格式，支持嵌套目录）
      if (jsonContent == null) {
        print('未找到 data.json，查找 animations/animation.json...');
        for (final file in archive) {
          final fileName = file.name;
          final fileNameLower = fileName.toLowerCase();
          if (fileNameLower.contains('__macosx') ||
              fileNameLower.contains('/._')) {
            continue;
          }
          // 支持嵌套目录，如 "folder/animations/animation.json"
          if (fileNameLower.endsWith('/animations/animation.json') ||
              (fileNameLower.contains('/animations/') &&
                  fileNameLower.endsWith('.json'))) {
            jsonContent = utf8.decode(file.content as List<int>);
            print(
                '找到动画 JSON 文件: ${file.name}，大小: ${jsonContent.length} 字符');
            break;
          }
        }
      }

      // 如果还是找不到，查找其他 JSON 文件（向后兼容，但排除 manifest.json 和 macOS 系统文件）
      if (jsonContent == null) {
        print('未找到标准动画文件，查找其他 JSON 文件（排除 manifest.json）...');
        for (final file in archive) {
          final fileName = file.name;
          final fileNameLower = fileName.toLowerCase();
          // 跳过 macOS 系统文件和 manifest.json
          if (fileNameLower.contains('__macosx') ||
              fileNameLower.contains('/._') ||
              fileNameLower.contains('manifest')) {
            continue;
          }
          if (fileNameLower.endsWith('.json') && file.isFile) {
            jsonContent = utf8.decode(file.content as List<int>);
            print('找到 JSON 文件: ${file.name}，大小: ${jsonContent.length} 字符');
            break;
          }
        }
      }

      if (jsonContent == null) {
        throw Exception('在 ZIP 文件中未找到 JSON 文件');
      }

      return _LottieReadResult(
        jsonContent: jsonContent,
        imagesDir: lottieImagesDir,
      );
    } else {
      // 直接读取 .json 文件
      return _LottieReadResult(
        jsonContent: await file.readAsString(),
        imagesDir: null,
      );
    }
  }
}

/// Lottie 读取结果
class _LottieReadResult {
  final String jsonContent;
  final String? imagesDir;

  _LottieReadResult({
    required this.jsonContent,
    this.imagesDir,
  });
}

