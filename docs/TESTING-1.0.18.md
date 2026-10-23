# IdleSentry 1.0.18 — validation and release notes

Use `IdleSentry-1.0.18.dmg` or `build/IdleSentry.app`. This is the real universal app, not the isolated sample-data preview. Quit any running IdleSentry Preview before opening it. Existing preferences and monitored apps are retained; check the list and selected action before leaving the Mac idle.

## Manual acceptance

1. In Inactivity Rules, select Hide and set a short timeout. Add a disposable unsaved TextEdit/Word/Excel document to Monitored Apps. Stop input until the timeout: all app windows should disappear, its Dock icon should stay, and clicking that icon should restore the unchanged document. Do not use valuable unsaved work for acceptance testing.
2. Let it remain hidden for another timeout: there should be no repeated closing actions or close notifications. Resume input and return to the app: a later idle episode can hide it again.
3. Choose a per-app action while leaving the default unchanged. Confirm it persists after quitting/relaunching IdleSentry. Choose Default to inherit the global action again. Existing Standard Quit/Force Quit preferences should stay as selected when upgrading.
4. Watch System is idle appear above the countdown, then move the mouse or press a key: it should disappear. Pausing monitoring also hides it and stops automatic actions.
5. In System & Startup, confirm Send notifications after closing apps starts off. Enable it and allow alerts if macOS asks. Close two disposable saved apps through inactivity: one silent notification should name the apps. A save prompt or Hide should never be reported as a completed close. Turn the toggle off and restart: it should remain off.
6. In Inactivity Rules → When an app reports unsaved work, verify the default is Leave open. Grant Accessibility if you choose to test the fallback. Select Standard Quit plus fallback Hide, and use a disposable edited document with a recognized English save warning. After the warning appears, the app should hide with its document and warning intact; restore it from the Dock. With no Accessibility permission or an unsupported warning, it should remain open. Only test fallback Force Quit on disposable changes; it intentionally discards them. Resume input or pause monitoring while waiting: no fallback should run.
7. Quit and replace the prior test installation with this rebuilt app, then relaunch. Enable close notifications in System & Startup and let a disposable monitored app close through inactivity. Check that the leading sender icon is IdleSentry’s actual logo, with no right-side thumbnail. The notification must remain silent.
8. With the real app window open, check its Dock icon using System Settings → Appearance → Icon & widget style. Verify Default, Dark, Clear, and Tinted. Close and reopen IdleSentry’s window to exercise its menu-bar/Dock transition. Restore your preferred system appearance afterwards.
9. Check About reports 1.0.18. After publication, Check for Updates in 1.0.15 should offer 1.0.18 through the signed feed. Source and local checks do not exercise the complete interactive Sparkle installation flow.

## Automated/local validation

`bash tests/run-checks.sh` covers legacy settings, live presentation, idle reset/pause, edited-document Hide/restore, refused quit protection, confirmed standard/force quit, combined silent notification payloads, opt-out persistence, and discovery. It uses disposable native helpers and an isolated preference suite, and never changes macOS notification permission.

`bash package.sh` creates universal arm64/x86_64 packages, verifies the app signature and DMG, and creates SHA256SUMS.txt. The adaptive icon catalog is compiled with Apple’s asset compiler from the existing artwork. Banner presentation, the actual Dock under the user’s appearance settings, and Office-specific behavior require manual acceptance.

The signed Sparkle feed must be generated for the final package at release time. Source publication is separate from publishing release assets and updating the public feed; neither a source push nor CI artifact upload publishes an installer release.

The fallback lifecycle checks inject save-warning evidence while exercising real disposable apps. Structural checks verify that edited work, a dialog, and all three save-decision controls are required. Live cross-app Accessibility detection and actual notification presentation need the manual acceptance above; the automated test process is not granted Accessibility or notification permission.

## Latest UI/startup acceptance

- Switch default action among Standard Quit, Hide and Force Quit. The entire unsaved-work card must gray out for Hide/Force Quit, then become usable with its previous choice intact when returning to Standard Quit.
- Quick setup first offers Accessibility review if permission is missing. Click Review Accessibility: it opens System & Startup, scrolls to Accessibility and highlights it twice. Use Open System Settings there to reach the OS permission pane. With Reduce Motion enabled, expect one steady highlight instead of pulsing. Permission granted should advance automatically to the settings-review tip within two seconds. Dismiss skips the current tip; dismissing the final tip persists across relaunch.
- At the next real sign-in, verify that Launch at login leaves only the menu-bar item, with no foreground settings window. Opening IdleSentry manually should still show the window. Login-event and explicit-background decisions are covered by automated tests; this session does not log out or reboot the user’s Mac.

## Live TextEdit verification

On October 23, 2026, the installed app recognized TextEdit’s actual native keep/discard panel with Accessibility enabled. With Standard Quit and the Hide fallback, TextEdit remained running and became hidden; restoring it and cancelling the save warning preserved the disposable test sentence intact. With the Force Quit fallback, the same disposable process terminated after the recognized warning. The test app entry was removed afterward and the user’s Leave open fallback restored. This does not establish Office-specific compatibility.

If Accessibility is missing for a returning installation, the sidebar shows a dismissible Recheck Accessibility access tip even after initial setup tips were dismissed. Removal/re-addition instructions apply only if the system switch is already on but the app still reports missing access; a reinstall does not automatically require this repair.

## Notification sender icon verification — October 23, 2026

The user confirmed that the installed full app displays IdleSentry's shield-and-clock icon on the left after rebuilding the per-user IconServices cache index. Notifications contain no right-side artwork attachment.

The isolated comparison used the same minimal sender, icon resources and metadata under two bundle identifiers. The original `com.zennoris.IdleSentry` identity showed the placeholder; the diagnostic identity showed the correct icon. A clean reinstall, development signing, registration refreshes and notification-service restarts had not fixed the original identity. This isolates the observed failure from the app's monitoring and notification-payload code.

Recovery stopped IdleSentry, Notification Center and the current user's iconservicesagent, moved `$(getconf DARWIN_USER_CACHE_DIR)com.apple.iconservices/store.index` to a temporary backup, then reopened the original full app. The user confirmed the next real test banner had the proper left icon. Notification permissions, app settings and the tint-color registry were preserved. The app must not perform this cache reset automatically. This is a verified local recovery, not evidence that every missing icon has the same cause.

## Responsive layout acceptance

At the minimum 800 × 560 content size, open a monitored app and keep input active: the complete Watching for inactivity card must stay inside the sidebar. Check the waiting, paused and countdown states as well. Only the tips area should yield space or scroll. At full-screen width, page content should remain in a centered column no wider than 1040 points. The standard window hosting and toolbar behavior are retained.

Temporary test-notification controls and the developer preview menu were removed after icon verification. Regression fixtures remain isolated in the automated test suite.

## Final local acceptance — October 24, 2026

The user confirmed the active-input Watching for inactivity card stays fully visible at the small window size. The real app was visually checked with a wide window and a centered bounded content column. The sidebar logo was then removed, leaving the name and version; this was visually checked in the installed real app. The final local universal build is internal build 202610240007, product version 1.0.18. Its app signature, DMG and package checksums passed verification. Temporary preview/diagnostic applications and stale installers were removed; the current DMG and ZIP remain. The macOS-specific notification cache recovery above was verified before this final cosmetic change.

## Pre-push validation — October 24, 2026

The final source passed all 101 checks. A first rerun exposed a test timing race: production polling could read live input while the lifecycle fixture waited on synthetic idle values, cancelling a pending fallback. The lifecycle fixture now pumps the run loop in short slices and stops automatic polling, leaving idle advancement to its explicit checks; production behavior is unchanged. The corrected rerun passed. Final installed signature and both package checksums were also reverified. Shell entry-point executable permissions were restored, and documentation was reconciled with the final behavior (no right-side notification artwork or interactive Preview menu).

## Release publication — October 24, 2026

The user authorized publishing the 1.0.18 macOS release. Release assets use the previously verified final local universal package (internal build 202610240007), with a newly generated signed Sparkle appcast for that exact ZIP. The release includes the DMG, ZIP, SHA256SUMS.txt and appcast.xml. A source push alone does not update the website download: its resolver follows the latest published stable GitHub release.
