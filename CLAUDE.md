# CLAUDE.md

## Commands

cd macos-app
xcodegen generate  # regenerate the Xcode project (after adding/removing files or editing project.yml)
open Headroom.xcodeproj
./build.sh         # Developer ID-signed universal release in macos-app/dist/
./release.sh       # notarized DMG + Sparkle appcast in dist/; --publish creates the GitHub release (CI does this on every push to main)

## Architecture

Native menu bar app (no Dock icon, no main window): AppKit `NSStatusItem` + `NSPopover` hosting SwiftUI. Swift 6 language mode, macOS 14+. One dependency: Sparkle (SwiftPM, for auto-update).

- `AppDelegate.swift` — entry point; creates the model and the status item
- `AppModel.swift` — `@Observable` state, refresh timers (60s usage, 15m rate limits), coalesced fetches, disk cache
- `UsageStore.swift` — actor; parses `~/.claude/projects/**/*.jsonl` (entries cached per file by mtime+size) and merges with the persisted history
- `Pricing.swift` — per-model prices
- `CredentialStore.swift` — keychain import; `RateLimitClient.swift` — rate-limit header probe
- `StatusItemController.swift` — menu bar item, popover show/dismiss, right-click menu
- `Updater.swift` — Sparkle; installs downloaded updates immediately, or when the popover closes
- `PopoverView.swift` — the popover UI

## Data Flow

1. `UsageStore.load` scans the JSONL transcripts, merges with `usage-history.json` and saves it
2. `AppModel` combines that with the rate limits read from a one-token API request's `anthropic-ratelimit-unified-*` headers
3. `PopoverView` and `StatusItemController` observe `AppModel` directly

## Gotchas

- `Headroom.xcodeproj` is generated and git-ignored — edit `project.yml`, not the project
- `Pricing.swift` must be updated manually when new Claude models launch. A model missing from it is billed at the fallback rate, and history keeps the inflated value (it only goes up) unless a history-version migration re-prices it
- History uses high-water-mark merging — values only go up, never down. Bump `historyVersion` only with a migration: transcripts get deleted, so the history is the only record of older usage
- Data lives in `~/Library/Application Support/Headroom/`; on first launch it is copied from the pre-rename `Claude Usage Tray/` directory, or else seeded from the former Electron app's `claude-usage-tray/` directory
- The OAuth token is never written to disk; only a `connected` flag in UserDefaults persists
- Read Claude Code's keychain item through `/usr/bin/security`, not `SecItem` — the item trusts that tool, so there is no access prompt
- The popover uses `.applicationDefined` behavior with its own dismissal, and opens with `activate(ignoringOtherApps:)` — the cooperative `activate()` leaves the app inactive after a menu bar click
- Releases are versioned from commit messages since the last `v*` tag (`feat:` → minor, `feat!:` → major, anything else → patch); every push to main touching `macos-app/` publishes one
- Sparkle compares `CFBundleVersion`, so `build.sh` sets both it and `MARKETING_VERSION` to the release version; the values in `project.yml` are only development defaults
- `macos-app/Info.plist` holds only Sparkle keys and is merged into the generated plist; it shares Vigil's Sparkle EdDSA key (the login keychain's default `generate_keys` item)
- The bundle ID is `live.okirodev.headroom`. Before the rename it was `com.claude.usage-tray` (shared with the former Electron app); `CredentialStore` reads that defaults domain once to carry over the `connected` flag. Sparkle refuses updates whose bundle ID differs from the installed app's, so never change it again once a release has shipped

## Code Style

- Plain Swift and SwiftUI; no third-party packages beyond Sparkle
- Strict concurrency: UI types are `@MainActor`, file and network work runs in actors or off the main thread
