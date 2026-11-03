import Observation
import Sparkle

/// Sparkle auto-update. The feed (SUFeedURL in Info.plist) is the appcast.xml attached to
/// the latest GitHub release, which CI publishes on every push to main.
/// Sparkle calls the user driver delegate on the main thread without saying so in its
/// headers; @preconcurrency checks that at runtime.
@MainActor
@Observable
final class Updater: NSObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    /// An update found by a background check that Sparkle couldn't install silently and the
    /// user hasn't looked at yet. Shown in the popover instead of a window popping up.
    private(set) var pendingVersion: String?

    /// True while the popover is open: a downloaded update waits rather than relaunching
    /// the app from under the user, and installs once it closes.
    @ObservationIgnored var holdsInstall = false {
        didSet { if !holdsInstall { installDownloadedUpdate() } }
    }

    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    /// Installs a silently downloaded update and relaunches.
    @ObservationIgnored private var installNow: (() -> Void)?
    @ObservationIgnored private var started = false

    override init() {
        super.init()
        // Debug builds from Xcode don't check on their own: they would offer to replace
        // themselves with the latest release. Check for Updates… still starts the updater.
        #if DEBUG
        started = false
        #else
        started = true
        #endif
        controller = SPUStandardUpdaterController(startingUpdater: started, updaterDelegate: self, userDriverDelegate: self)
    }

    /// Backed by Sparkle, so observation is reported by hand: the popover re-renders
    /// only when something it reads changes.
    var updatesAutomatically: Bool {
        get {
            access(keyPath: \.updatesAutomatically)
            return controller.updater.automaticallyChecksForUpdates && controller.updater.automaticallyDownloadsUpdates
        }
        set {
            withMutation(keyPath: \.updatesAutomatically) {
                controller.updater.automaticallyChecksForUpdates = newValue
                controller.updater.automaticallyDownloadsUpdates = newValue
            }
        }
    }

    /// Also brings a pending update's window to the front.
    func checkForUpdates() {
        if !started {
            started = true
            controller.startUpdater()
        }
        controller.checkForUpdates(nil)
    }

    private func installDownloadedUpdate() {
        guard !holdsInstall, let install = installNow else { return }
        installNow = nil
        install()
    }

    // MARK: Silent install

    /// Updates download in the background (SUAutomaticallyUpdate) and would wait for a quit,
    /// which a menu bar app rarely sees. Take them over and install right away, or when the
    /// popover closes.
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        installNow = immediateInstallHandler
        installDownloadedUpdate()
        return true
    }

    // MARK: Gentle reminders (Sparkle warns for background apps without them)

    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Near launch Sparkle shows its window right away; later background finds go to the popover.
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if !handleShowingUpdate { pendingVersion = update.displayVersionString }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        pendingVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        pendingVersion = nil
    }
}
