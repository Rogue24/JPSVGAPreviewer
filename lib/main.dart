import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';
import 'single_instance.dart';
import 'package:flutter/services.dart';
import 'view_models/svga_view_model.dart';  // 添加这行导入
import 'widgets/frames_list.dart';
import 'widgets/svga_preview.dart';
import 'widgets/frame_preview.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 检查是否已有实例运行
  bool canRun = await SingleInstance.check();
  if (!canRun) {
    exit(0);
  }

  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  // 设置窗口属性
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'SVGA预览器',
  );

  // 配置窗口
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 创建视图模型
  final viewModel = SVGAViewModel();

  // 设置方法通道处理文件打开
  const channel = MethodChannel('svga_viewer');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'openFile') {
      final String filePath = call.arguments as String;
      if (filePath.toLowerCase().endsWith('.svga')) {
        await viewModel.processSVGAFile(filePath);
      }
    }
  });

  // 如果有命令行参数（双击文件打开），处理第一个文件
  if (args.isNotEmpty && args.first.toLowerCase().endsWith('.svga')) {
    await viewModel.processSVGAFile(args.first);
  }

  // 设置窗口事件处理
  await windowManager.setPreventClose(false);

  runApp(
    ChangeNotifierProvider(
      create: (context) => viewModel,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVGA预览器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark, // 使用深色主题
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DropTarget(
        onDragDone: (details) async {
          final file = details.files.first;
          if (path.extension(file.path).toLowerCase() == '.svga') {
            // 先清空当前数据
            await Provider.of<SVGAViewModel>(context, listen: false).clearState();
            
            // 处理新文件
            await Provider.of<SVGAViewModel>(context, listen: false)
                .processSVGAFile(file.path);
          }
        },
        onDragEntered: (details) {
          Provider.of<SVGAViewModel>(context, listen: false).setDragging(true);
        },
        onDragExited: (details) {
          Provider.of<SVGAViewModel>(context, listen: false).setDragging(false);
        },
        child: Stack(
          children: [
            Row(
              children: [
                // 左侧帧列表
                Container(
                  width: 200,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Colors.grey.shade800,
                        width: 1,
                      ),
                    ),
                  ),
                  child: const FramesList(),
                ),
                // 右侧预览区域
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: Column(
                      children: [
                        // 文件信息栏
                        Consumer<SVGAViewModel>(
                          builder: (context, viewModel, child) {
                            if (viewModel.currentFileName == null) return const SizedBox();
                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade800,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.movie_outlined),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          viewModel.currentFileName!,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '帧率: ${viewModel.fps.toStringAsFixed(1)} FPS  •  时长: ${viewModel.duration.toStringAsFixed(2)}秒  •  内存: ${viewModel.memoryUsage.toStringAsFixed(1)}MB',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '总帧数: ${viewModel.frames.length}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        // 上半部分：SVGA动画预览
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade800,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Consumer<SVGAViewModel>(
                              builder: (context, viewModel, child) {
                                return Center(
                                  child: viewModel.svgaFile == null
                                      ? const Text('无预览内容')
                                      : SVGAPreview(file: viewModel.svgaFile!),
                                );
                              },
                            ),
                          ),
                        ),
                        // 下半部分：当前帧预览
                        const Expanded(
                          child: FramePreview(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 拖拽提示遮罩
            Consumer<SVGAViewModel>(
              builder: (context, viewModel, child) {
                if (!viewModel.isDragging) return const SizedBox();
                return Container(
                  color: Colors.black.withOpacity(0.7),
                  child: const Center(
                    child: Text(
                      '释放以打开 SVGA 文件',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['svga'],
          );
          if (result != null) {
            // 先清空当前数据
            await Provider.of<SVGAViewModel>(context, listen: false).clearState();
            
            // 处理新文件
            await Provider.of<SVGAViewModel>(context, listen: false)
                .processSVGAFile(result.files.single.path!);
          }
        },
        tooltip: '打开SVGA文件',
        child: const Icon(Icons.folder_open),
      ),
    );
  }
}
