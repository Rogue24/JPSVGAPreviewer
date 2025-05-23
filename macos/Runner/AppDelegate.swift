import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ aNotification: Notification) {
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
  
  // 处理文件打开
  override func application(_ sender: NSApplication, open urls: [URL]) {
    guard let url = urls.first else { return }
      
    // 获取Flutter引擎
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else { return }
    
    // 发送文件路径到Dart端
    let channel = FlutterMethodChannel(name: "svga_viewer", binaryMessenger: controller.engine.binaryMessenger)
    channel.invokeMethod("openFile", arguments: url.path)
  }
}
