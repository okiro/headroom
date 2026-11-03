import AppKit

/// Menu bar only: `LSUIElement` keeps the app out of the Dock and there is no main window.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusItem: StatusItemController?
    private var updater: Updater?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Paths.prepare()
        let model = AppModel()
        self.model = model
        let updater = Updater()
        self.updater = updater
        statusItem = StatusItemController(model: model, updater: updater)
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.saveCache()
    }
}
