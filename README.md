# IdleSentry for macOS

A native menu-bar utility that hides or quits the applications you choose when your Mac is idle. Monitoring and preferences stay on your Mac; no account or activity upload is involved.

## Everyday use

1. Open **IdleSentry → Add Apps** (⌘N), search for applications, and select the ones to monitor. Running apps appear first. **Browse…** lets you select apps elsewhere on your Mac.
2. Choose a default timeout and **Hide**, **Standard Quit**, or **Force Quit** in **Inactivity Rules**. Use the action menu on each **Monitored Apps** row to override the default.
3. Leave monitoring enabled on the **Dashboard**. Keyboard or mouse activity resets the timer.

The Dashboard summarizes monitored apps, running apps, timeout, and idle action. A neutral countdown card in the sidebar shows the next app to hide or quit, with a muted amber clock icon. Long names truncate to one line with a hover label; “+N more” summarizes additional apps. Click the card to inspect the full scrollable activity queue, ordered by next deadline. The list remains available when input resets the countdown. The small red badge counts running monitored apps and disappears at zero.

The sidebar’s Quick setup card first checks Accessibility. Its review button opens System & Startup, scrolls to the Accessibility card and highlights it twice (a steady highlight with Reduce Motion). Granting permission advances automatically to the settings-review tip. Dismiss skips the current tip; dismissing the final review stays dismissed after relaunch. The native macOS permission pane remains under the user’s control.

Closing the window leaves IdleSentry running in the menu bar. Choose **Quit IdleSentry** to exit. **System & Startup** includes launch-at-login, optional silent close notifications, and Accessibility settings. The window is resizable and remembers its size. Login-item launches stay in the menu bar, using the macOS launch event rather than a system-uptime guess. Opening the app manually still opens the window; `--background` also supports a quiet non-preview launch.

### What “idle” means

The timeout uses system-wide keyboard and mouse inactivity, after a brief 1.25-second grace period. All running monitored apps are eligible, including the frontmost app. It does not measure how long an individual app has been in the background. Saved per-app timeout overrides are preserved.

### Actions after inactivity

- **Hide** removes the app’s windows while keeping its process, Dock icon, and unsaved work open. Click the Dock icon to return. Hiding does not save documents or release the app’s memory. Hidden apps leave the Hide countdown; apps configured to quit remain eligible even when hidden.
- **Standard Quit** requests a normal application quit. An app can show a save prompt or refuse to close; saving and exit are not guaranteed.
- **Force Quit** requests immediate termination. Unsaved changes can be lost.
- **Close remaining background processes** optionally force-terminates captured background instances with the same bundle identifier after the main app has exited. It never runs for Hide or while the main app is waiting for a save decision, and does not target another regular app instance. Helpers with different identifiers are not covered.

**Send notifications after closing apps** is off by default, including upgrades. Enabling it requests alert permission from macOS. Notifications are silent, combine exits observed together, and report confirmed termination only. Hidden apps and declined quit requests do not notify.

### When an app reports unsaved work

The separate card below the universal rules is enabled only when the default action is Standard Quit; Hide and Force Quit gray it out and bypass the fallback, including for per-app overrides. It applies after Standard Quit: **Leave open** (default), **Hide**, or **Force Quit**. Force Quit explicitly discards unsaved changes. The fallback requires Accessibility permission and either an edited-document report plus a recognized Save / Don’t Save / Cancel dialog, or an AppKit keep/discard save panel with its dedicated discard control. Title-based recognition is English-only; native AppKit save panels use stable button identifiers (including TextEdit’s Delete action for unnamed drafts); unsupported apps/localizations and missing permission leave the app open. A slow or refused quit alone is never evidence. Input or pausing cancels pending fallback handling. Global/per-app Hide and Force Quit do not wait for this fallback.

Notification banners use the system-managed source-app icon. The bundle supplies the adaptive catalog and a readable ICNS fallback. Notifications have no right-side artwork attachment.

Save your work before testing automatic closing. Pause monitoring whenever you want your selected apps to remain open.

## Requirements and installation

Requires **macOS 13 Ventura or later**. The build script supports host-native, Apple Silicon, Intel, and universal builds.

Download a DMG from [Releases](https://github.com/synthwave541/IdleSentry/releases), then drag IdleSentry.app to Applications. Current public builds use an ad-hoc signature rather than Developer ID notarization, so macOS may require an explicit first-open approval.

Preferences use `~/Library/Preferences/com.zennoris.IdleSentry.plist`. The UI update retains the existing preference keys and monitored-app format.

## Build from source

Use Xcode 26 or later with the macOS SDK (adaptive icon compilation requires the full Xcode toolchain), then run from this directory:

```sh
bash build.sh universal
```

The application is created at `build/IdleSentry.app` and ad-hoc signed. The minimum deployment target remains macOS 13. The tracked `VERSION` file supplies the product version (1.0.18). Optional local `version.info` supplies build metadata; otherwise the build is labeled custom. No Xcode project is required. The build downloads a pinned Sparkle 2.10.0 framework and verifies its checksum.

To create a universal DMG, app ZIP, and SHA-256 checksums, run `bash package.sh`. Both packages include `FIX LAUNCH ERROR.txt`, with the targeted quarantine command first and an explanation of signing and first-launch approval. Packaging uses command-line tools without Finder automation and is separate from publishing a GitHub release.

### Isolated UI preview

Launch the built executable with `--ui-preview` to use sample applications:

```sh
build/IdleSentry.app/Contents/MacOS/IdleSentry --ui-preview
```

This mode does not load or save your preferences, monitor or terminate apps, request permissions, or register login items. It provides isolated fixtures for regression checks. The temporary interactive Preview menu and test-notification button have been removed.

### Checks

```sh
bash tests/run-checks.sh
```

Checks cover presentation priority, timer formatting, isolated preview mutations, stored-settings compatibility, and installed-app discovery. They launch disposable native helper apps to verify Hide/restore with edited documents, declined quits, standard/force quit, and silent notification payloads. They never target user apps or change system permissions. Banner presentation under macOS notification policy should also be checked manually.

## Windows

The native Windows port is available separately for **x64 and ARM64**: [IdleSentry for Windows](https://github.com/synthwave541/IdleSentryForWindows). The two apps use their own native UI and build tools.

## Credits and license

Created by **Anush Vishwakarma / [Zennoris](https://zennoris.com)**. Distributed under the **Apache License 2.0**; see [LICENSE](LICENSE).

The IdleSentry name and shield/clock branding are trademarks. Forks may use the code under its license; permission is required to distribute them using the official name or branding.

## Updates (1.0.15+)

Use **Check for Updates…** from the menu bar or **About → Software updates**. Automatic checks run daily and can be disabled in About. Downloads and installation require approval; Sparkle shows progress and restarts IdleSentry after installing. Monitoring and preferences stay local; only release metadata and packages are requested from GitHub. System profiling and unattended installs are disabled.

Update archives and the feed use Ed25519 signatures. This is separate from Apple Developer ID signing and does not remove first-install Gatekeeper warnings. The signing key is stored in the release Mac’s login Keychain, account `com.zennoris.IdleSentry`; only its public key is committed. Preserve/back up this key securely using Sparkle’s `generate_keys` tool before replacing the release Mac. Never commit the private key.

To publish future updates, bump `VERSION`, run `bash package.sh`, then `bash scripts/make-appcast.sh` on the release Mac. Upload the DMG, macOS ZIP, `SHA256SUMS.txt` and **appcast.xml** to the matching stable GitHub release in this repository. The appcast download prefix uses the exact version tag (without `v`). Publish all assets together, then make that release the latest release. Do not edit a signed appcast after generating it. CI builds packages but cannot sign the feed without the release key.

Existing 1.0.14 users install 1.0.15 manually once; their preferences are retained. Local checks: `bash tests/run-checks.sh`.
