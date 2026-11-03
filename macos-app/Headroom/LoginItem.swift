import OSLog
import ServiceManagement

private let log = Logger(subsystem: "live.okirodev.headroom", category: "login-item")

/// Open at Login, through the app's own SMAppService entry. The state lives in System
/// Settings › General › Login Items, so it is read fresh rather than cached.
@MainActor
enum LoginItem {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                log.error("Open at Login: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
