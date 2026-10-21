# IdleSentry for macOS

A native menu-bar utility that quits the applications you choose when your Mac is idle. Monitoring and preferences stay on your Mac; no account or activity upload is involved.

## Everyday use

1. Open **IdleSentry → Add Apps** (⌘N), search for applications, and select the ones to monitor. Running apps appear first. **Browse…** lets you select apps elsewhere on your Mac.
2. Choose a default timeout in **Inactivity Rules**.
3. Leave monitoring enabled on the **Dashboard**. Keyboard or mouse activity resets the timer.

The Dashboard summarizes monitored apps, running apps, timeout, and quit method. A neutral countdown card in the sidebar shows the next app to close, with a muted amber clock icon. Long names truncate to one line with a hover label; “+N more” summarizes additional apps. Click the card to inspect the full scrollable closing queue, ordered by next deadline. The list remains available when input resets the countdown. The small red badge counts running monitored apps and disappears at zero.

Closing the window leaves IdleSentry running in the menu bar. Choose **Quit IdleSentry** to exit. **System & Startup** includes launch-at-login and Accessibility settings. The window is resizable and remembers its size.

### What “idle” means

The timeout uses system-wide keyboard and mouse inactivity, after a brief 1.25-second grace period. All running monitored apps are eligible, including the frontmost app. It does not measure how long an individual app has been in the background. Saved per-app timeout overrides are preserved.

### Quit methods

- **Standard Quit** requests a normal application quit. An app can show a save prompt or refuse to close; saving and exit are not guaranteed.
- **Force Quit** requests immediate termination. Unsaved changes can be lost.
- **Close remaining background processes** optionally force-terminates remaining processes with the same bundle identifier 0.4 seconds after the initial request. This can interrupt saving. Helpers with different identifiers are not covered by that exact match.

Save your work before testing automatic closing. Pause monitoring whenever you want your selected apps to remain open.

## Requirements and installation

Requires **macOS 13 Ventura or later**. The build script supports host-native, Apple Silicon, Intel, and universal builds.

Download a DMG from [Releases](https://github.com/synthwave541/IdleSentry/releases), then drag IdleSentry.app to Applications. Current public builds use an ad-hoc signature rather than Developer ID notarization, so macOS may require an explicit first-open approval.

Preferences use `~/Library/Preferences/com.zennoris.IdleSentry.plist`. The UI update retains the existing preference keys and monitored-app format.

## Build from source

Use Xcode or the Xcode Command Line Tools with the macOS SDK, then run from this directory:

```sh
bash build.sh universal
```

The application is created at `build/IdleSentry.app` and ad-hoc signed. The minimum deployment target remains macOS 13. The tracked `VERSION` file supplies the product version (1.0.15). Optional local `version.info` supplies build metadata; otherwise the build is labeled custom. No Xcode project is required. The build downloads a pinned Sparkle 2.10.0 framework and verifies its checksum.

To create a universal DMG, app ZIP, and SHA-256 checksums, run `bash package.sh`. Both packages include `FIX LAUNCH ERROR.txt`, with the targeted quarantine command first and an explanation of signing and first-launch approval. Packaging uses command-line tools without Finder automation and is separate from publishing a GitHub release.

### Isolated UI preview

Launch the built executable with `--ui-preview` to use sample applications:

```sh
build/IdleSentry.app/Contents/MacOS/IdleSentry --ui-preview
```

This mode does not load or save your preferences, monitor or terminate apps, request permissions, or register login items. The Preview menu offers ready/countdown/many-app/paused/empty/waiting states, app-only light/dark appearance, and window sizes for visual QA. Those controls are absent from normal launches.

### Checks

```sh
bash tests/run-checks.sh
```

Checks cover presentation priority, timer formatting, isolated preview mutations, stored-settings compatibility, and installed-app discovery. They do not close real applications or change system permissions.

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
