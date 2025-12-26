import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path/path.dart' as path;
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart' as svga;
import 'package:svga_previewer/models/animation_metadata.dart';
import 'package:svga_previewer/models/animation_type.dart';
import 'package:svga_previewer/models/frame_info.dart';
import 'package:svga_previewer/services/parsers/animation_parser.dart';
import 'package:svga_previewer/services/parsers/animation_parse_result.dart';
import 'package:svga_previewer/services/temp_file_manager.dart';
import 'package:flutter/material.dart';

/// SVGA 动画解析器
/// 负责解析 SVGA 格式的动画文件，提取帧图片和元数据
class SVGAParser implements AnimationParser {
  @override
  bool canParse(String filePath) {
    return path.extension(filePath).toLowerCase() == '.svga';
  }

  @override
  Future<AnimationParseResult> parse(String filePath) async {
    print('开始处理新的SVGA文件: ${path.basename(filePath)}');

    try {
      // 清空图片缓存
      imageCache.clear();
      imageCache.clearLiveImages();
      print('图片缓存已清空');

      // 获取文件大小
      final svgaFile = File(filePath);
      int fileSizeBytes = 0;
      if (await svgaFile.exists()) {
        fileSizeBytes = await svgaFile.length();
        print('SVGA文件大小: $fileSizeBytes bytes');
      }

      // 创建临时目录
      final framesDir = await TempFileManager.getSVGAFramesDirectory();
      print('创建新的临时目录: ${framesDir.path}');

      // 解析 SVGA 文件
      final svgaParser = const svga.SVGAParser();
      final videoItem = await svgaParser.decodeFromBuffer(
        await File(filePath).readAsBytes(),
      );
      print('SVGA文件解析完成');

      final images = videoItem.images;

      // 提取元数据
      final totalFrames = videoItem.params.frames;
      final fps = videoItem.params.fps.toDouble();
      final duration = totalFrames / fps;
      final frameWidth = videoItem.params.viewBoxWidth.toInt();
      final frameHeight = videoItem.params.viewBoxHeight.toInt();

      print('FPS: $fps, 持续时间: $duration秒');

      // 提取帧图片
      final List<File> tempFrames = [];
      final List<FrameInfo> tempFrameInfos = [];
      double totalFileSizeBytes = 0;
      double memoryUsageMB = 0.0;

      print('开始提取帧图片，总数：${images.length}');
      var index = 0;
      for (var entry in images.entries) {
        if (entry.value.isNotEmpty) {
          try {
            final codec =
                await instantiateImageCodec(Uint8List.fromList(entry.value));
            final frame = await codec.getNextFrame();
            final byteData =
                await frame.image.toByteData(format: ImageByteFormat.png);

            if (byteData != null) {
              final frameFile = File('${framesDir.path}/${entry.key}');
              await frameFile.writeAsBytes(byteData.buffer.asUint8List());
              print('成功写入帧 $index 到文件: ${frameFile.path}');

              // 计算内存占用
              final frameMemoryMB =
                  (frame.image.width * frame.image.height * 4) / (1024 * 1024);
              memoryUsageMB += frameMemoryMB;

              // 获取文件大小
              final fileSizeBytes = await frameFile.length();
              totalFileSizeBytes += fileSizeBytes;

              print(
                  '当前帧内存占用: ${frameMemoryMB.toStringAsFixed(2)} MB，文件大小: $fileSizeBytes bytes');

              if (await frameFile.exists()) {
                tempFrames.add(frameFile);

                // 创建帧信息
                final frameInfo = FrameInfo(
                  file: frameFile,
                  fileSizeBytes: fileSizeBytes,
                  memoryUsageMB: frameMemoryMB,
                  width: frame.image.width,
                  height: frame.image.height,
                );
                tempFrameInfos.add(frameInfo);

                print(
                    '添加第 ${index + 1} 帧到临时数组，文件大小: ${frameInfo.fileSizeText}');
              } else {
                print('警告：帧文件未成功创建: ${frameFile.path}');
              }
              index++;
            }
          } catch (e) {
            print('处理帧 $index 时出错: $e');
          }
        }
      }

      if (tempFrames.isEmpty) {
        print('未能从SVGA文件中提取到任何图片');
      } else {
        print('成功提取了 ${tempFrames.length} 帧图片');
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
        animationType: AnimationType.svga,
        metadata: metadata,
        animationFile: svgaFile,
        frames: tempFrames,
        frameInfos: tempFrameInfos,
      );
    } catch (e) {
      print('处理SVGA文件时出错: $e');
      print(e.toString());
      rethrow;
    }
  }
}

