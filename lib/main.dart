import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:svga_previewer/widgets/home_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'single_instance.dart';
import 'package:flutter/services.dart';
import 'view_models/svga_view_model.dart';
import 'package:svga_previewer/widgets/url_download_dialog.dart';

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
    size: Size(760, 600),
    minimumSize: Size(380, 300),
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

  // 从缓存加载用户偏好设置（包括排版模式、边框显示、背景颜色）
  await viewModel.loadUserPreferences();

  // 设置方法通道处理文件打开
  const channel = MethodChannel('svga_viewer');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'openFile') {
      final String filePath = call.arguments as String;
      final ext = filePath.toLowerCase();
      if (ext.endsWith('.svga') || ext.endsWith('.json') || ext.endsWith('.lottie') || ext.endsWith('.json.gz') || ext.endsWith('.zip')) {
        await viewModel.processAnimationFile(filePath);
      }
    }
  });

  // 如果有命令行参数（双击文件打开），处理第一个文件
  if (args.isNotEmpty) {
    final ext = args.first.toLowerCase();
    if (ext.endsWith('.svga') || ext.endsWith('.json') || ext.endsWith('.lottie') || ext.endsWith('.json.gz') || ext.endsWith('.zip')) {
      await viewModel.processAnimationFile(args.first);
    }
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
      debugShowCheckedModeBanner: false, // 是否显示右上角的debug图标
      title: 'SVGA预览器',
      theme: ThemeData(
        primarySwatch: Colors.purple,
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
          final ext = path.extension(file.path).toLowerCase();
          if (ext == '.svga' || ext == '.json' || ext == '.lottie' || ext == '.zip' || file.path.toLowerCase().endsWith('.json.gz')) {
            // 先清空当前数据
            await Provider.of<SVGAViewModel>(context, listen: false).clearState();
            
            // 处理新文件
            await Provider.of<SVGAViewModel>(context, listen: false)
                .processAnimationFile(file.path);
          }
        },
        onDragEntered: (details) {
          Provider.of<SVGAViewModel>(context, listen: false).setDragging(true);
        },
        onDragExited: (details) {
          Provider.of<SVGAViewModel>(context, listen: false).setDragging(false);
        },
        child: const HomeScreen(),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // URL 下载按钮
          FloatingActionButton(
            heroTag: 'url_download',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => UrlDownloadDialog(
                  viewModel: Provider.of<SVGAViewModel>(context, listen: false),
                ),
              );
            },
            tooltip: '从 URL 下载',
            child: const Icon(Icons.download),
          ),
          const SizedBox(height: 16),
          // 文件选择按钮
          FloatingActionButton(
            heroTag: 'file_picker',
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['svga', 'json', 'lottie', 'zip'],
              );
              if (result != null) {
                // 先清空当前数据
                await Provider.of<SVGAViewModel>(context, listen: false).clearState();
                
                // 处理新文件
                await Provider.of<SVGAViewModel>(context, listen: false)
                    .processAnimationFile(result.files.single.path!);
              }
            },
            tooltip: '打开动画文件',
            child: const Icon(Icons.folder_open),
          ),
        ],
      ),
    );
  }
}
