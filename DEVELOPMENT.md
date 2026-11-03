# Developing Headroom

Notes for building, releasing and understanding the app. Looking for the app? See the [README](README.md).

## Repository Layout

```text
.
├── README.md
├── CLAUDE.md
├── .github/workflows/
│   └── release.yml          # Publishes a release on every push to main
└── macos-app/
    ├── project.yml          # XcodeGen project definition
    ├── Info.plist           # Sparkle feed URL and public key (merged into the generated plist)
    ├── build.sh             # Signed release build
    ├── release.sh           # Notarized DMG + Sparkle appcast, optionally published
    └── Headroom/            # Swift sources and asset catalog
```

## Requirements

- macOS 14+
- Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Claude Code installed and logged in (credentials must exist in the macOS keychain)

## Run

```bash
cd macos-app
xcodegen generate       # creates Headroom.xcodeproj
open Headroom.xcodeproj # run from Xcode
```

## Build

```bash
cd macos-app
./build.sh
```

Produces a Developer ID-signed universal app in `macos-app/dist/` (git-ignored).

## Releases & Auto-Update

Every push to `main` that changes `macos-app/` ships a new version: [the Release workflow](.github/workflows/release.yml) builds the app, notarizes `Headroom-<version>.dmg`, and publishes it as GitHub release `v<version>` with a [Sparkle](https://sparkle-project.org) `appcast.xml` and a copy named `Headroom.dmg` (the README's download link).

The version comes from the commit messages since the last `v*` tag ([Conventional Commits](https://www.conventionalcommits.org)):

| Commit | Bump | Example |
|---|---|---|
| `feat!: …`, or a `BREAKING CHANGE:` line in the body | major | 2.4.2 → 3.0.0 |
| `feat: …` / `feat(scope): …` | minor | 2.4.2 → 2.5.0 |
| anything else (`fix: …`, `chore: …`, no prefix) | patch | 2.4.2 → 2.4.3 |

Installed copies check the latest release's appcast once a day (`SUFeedURL` in `macos-app/Info.plist`; the repo must stay public), download updates in the background, and install them right away — or when the popover closes, if it is open. Debug builds from Xcode only check when you choose **Check for Updates…**.

### One-time CI setup

The workflow needs five repository secrets (`gh secret set NAME` prompts for the value, keeping it out of shell history):

```bash
# Sparkle key (the one in the login keychain): export, upload, delete the file
macos-app/build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle-private-key
gh secret set SPARKLE_PRIVATE_KEY < sparkle-private-key && rm sparkle-private-key

# Developer ID: Keychain Access → My Certificates → "Developer ID Application: …" → Export… as developer-id.p12
base64 -i developer-id.p12 | gh secret set DEVELOPER_ID_P12 && rm developer-id.p12
gh secret set DEVELOPER_ID_P12_PASSWORD    # the password you chose when exporting

# Notarization: an app-specific password from appleid.apple.com
gh secret set APPLE_ID
gh secret set APPLE_APP_PASSWORD
```

Installed copies only accept updates signed with that Sparkle key (public half: `SUPublicEDKey` in `macos-app/Info.plist`). Lose it and everyone has to reinstall by hand.

### Releasing from this Mac

`macos-app/release.sh` builds the next version's notarized DMG and appcast locally; `--publish` also creates the GitHub release (CI normally does this). It uses the keychain: the Sparkle key, the Developer ID, and a notarization profile stored once with:

```bash
xcrun notarytool store-credentials claude-tray-notary --apple-id <your Apple ID> --team-id W898QUYB63
```

## How It Works

1. **Usage data** is parsed from `~/.claude/projects/` JSONL files and merged with a persistent history file, so usage survives session deletions.
2. **Rate limits** are fetched by making a minimal API request to Anthropic and reading the response headers.
3. **Authentication** is imported from Claude Code's macOS keychain entry and kept in memory only.
4. **Errors** from the API or auth surface in a collapsible issue list above the footer.

## Security

- No API keys or credentials are stored in the repository
- Credentials are imported from the macOS keychain at runtime and never written to disk
- The release build is signed with hardened runtime
