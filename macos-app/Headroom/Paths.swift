import Foundation

enum Paths {
    static let claudeProjects = URL.homeDirectory.appending(path: ".claude/projects", directoryHint: .isDirectory)

    static let appSupport = URL.applicationSupportDirectory.appending(path: "Headroom", directoryHint: .isDirectory)
    static let history = appSupport.appending(path: "usage-history.json")
    static let dashboardCache = appSupport.appending(path: "dashboard-cache.json")

    /// Data directory from before the rename to Headroom.
    static let previousAppSupport = URL.applicationSupportDirectory.appending(path: "Claude Usage Tray", directoryHint: .isDirectory)

    /// Data directory of the Electron build this app replaces.
    static let legacyAppSupport = URL.applicationSupportDirectory.appending(path: "claude-usage-tray", directoryHint: .isDirectory)
    static let legacyAuthFile = legacyAppSupport.appending(path: "auth.enc")

    /// Creates the data directory. On first launch it is copied from the pre-rename
    /// directory, or else seeded with the Electron build's usage history, so totals
    /// from deleted sessions carry over. Copied, not moved: the old directory stays
    /// as a backup of the only record of that usage.
    static func prepare() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: appSupport.path(percentEncoded: false)),
           fm.fileExists(atPath: previousAppSupport.path(percentEncoded: false)) {
            try? fm.copyItem(at: previousAppSupport, to: appSupport)
        }
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let legacyHistory = legacyAppSupport.appending(path: "usage-history.json")
        if !fm.fileExists(atPath: history.path(percentEncoded: false)),
           fm.fileExists(atPath: legacyHistory.path(percentEncoded: false)) {
            try? fm.copyItem(at: legacyHistory, to: history)
        }
    }
}
