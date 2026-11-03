import Observation
import OSLog
import ServiceManagement

private let log = Logger(subsystem: "live.okirodev.headroom", category: "login-item")

/// Open at Login, through the app's own SMAppService entry. The state lives in System
/// Settings › General › Login Items, where it can change, so it is re-read whenever
/// the popover or menu opens. Reading it is an XPC round trip of ~10 ms, too slow to
/// repeat on every SwiftUI render, so views read the cached value.
@MainActor
@Observable
final class LoginItem {
    static let shared = LoginItem()

    private(set) var isEnabled = false

    private init() {}

    /// Re-reads the state off the main thread.
    func refresh() {
        Task {
            isEnabled = await Task.detached { SMAppService.mainApp.status == .enabled }.value
        }
    }

    /// Re-reads the state on the spot, for the right-click menu, which is built synchronously.
    func readNow() -> Bool {
        isEnabled = SMAppService.mainApp.status == .enabled
        return isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Open at Login: \(error.localizedDescription, privacy: .public)")
        }
        _ = readNow()
    }
}
