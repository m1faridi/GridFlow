import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Keep one engine alive independently of any window. Dart owns every view.
  private var engine: FlutterEngine?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let engine = FlutterEngine(name: "GridFlow", project: nil)
    self.engine = engine
    engine.run(withEntrypoint: nil)
    RegisterGeneratedPlugins(registry: engine)
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
