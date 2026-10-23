# IdleSentry: macOS changes and Windows parity handoff

Prepared October 24, 2026. Product version: 1.0.18.

## Purpose and repository boundaries

The user asked to push the finished macOS source and leave a complete handoff for an agent in the Windows VM to implement equivalent Windows behavior, including sidebar logo removal, a dedicated unsaved-work policy card, and the tips. This file describes the final behavior, not abandoned experiments.

- macOS reference: https://github.com/synthwave541/IdleSentry, branch main. The commit titled `Bring macOS 1.0.18 behavior and layout into parity` contains this handoff and the implementation.
- Windows target: https://github.com/synthwave541/IdleSentryForWindows.
- Shared macOS checkout: `Zennoris/Published Software/IdleSentry/IdleSentry`.
- Windows checkout: its parent, `Zennoris/Published Software/IdleSentry`.
- A standalone copy of this handoff is at `Zennoris/IdleSentry-Windows-Parity-Handoff-2026-10-24.md` in the VM shared folder.

Inspect the current Windows diff and repository instructions before editing. The Windows working tree already contains substantial uncommitted Store, tray, updater, distribution, packaging and test work. Preserve it. Do not reset, overwrite, or blindly copy Swift files into it. Some parity items may already exist: audit each item and implement the missing behavior using Windows APIs and the existing UI. No Windows source was changed by the macOS agent for this handoff. A source push is separate from publishing signed installers, a Store submission, or changing an update feed.

## 1. Sidebar header and responsive layout

Remove only the decorative app logo from the sidebar header. Keep the app name and version as a left-aligned text header. Keep the app's actual application icon, tray icon, notification identity, About artwork, branding assets and credits. Open source status does not require deleting branding across the product.

Keep the established native window, toolbar and navigation layout. The accepted fix reserves room for the status footer rather than replacing the whole window host. The problematic macOS state was a running monitored app while the user was active: the Watching for inactivity card slipped below the bottom edge at small sizes.

Final macOS layout reference (`ContentView.swift`):

- Header and navigation above Quick setup tips.
- Tips occupy the flexible, scrollable middle region.
- Status footer stays visible at the bottom, with higher layout priority.
- Reserve explicit status height: 88 points for ready/waiting/paused/empty, 110 for countdown. These are macOS measurements; use suitable WPF sizing rather than literal pixel parity.
- The System is idle card appears above status only while monitoring is enabled, monitored apps are configured, and system inactivity exceeds the 1.25-second grace period. It disappears when activity resumes or monitoring pauses. Preserve its clock/pause vector artwork if already present on Windows.
- Main page content is in a bounded centered column on large/fullscreen windows. macOS uses maximum inner width 1040 points, 24-point page padding, and vertical scrolling. Text and card contents remain left aligned inside that centered column.
- Minimum macOS content size is 800 by 560. Keep Windows' native sizing constraints appropriate to its layout. Prevent header/toolbar overlap and clipped footers at the supported minimum and at display scaling factors.
- Keep the existing responsive summary-card layout, long-name truncation, hover help, additional-app count, and bounded scrollable activity queue. Do not replace the UI with the failed experimental preview layout.

## 2. Separate primary action from unsaved-work policy

The primary action selector is Hide / Standard Quit / Force Quit. The dedicated card below it is titled **When an app reports unsaved work**, with an independent **Leave open / Hide / Force Quit** selector. The user called these dedicated toggles; macOS implements a mutually exclusive segmented picker, not three independent switches.

Primary action semantics:

- Hide keeps the app process and unsaved work alive. Restoration must return the user's existing windows/documents. macOS uses native application hide/unhide; Windows needs its own reliable hide/restore behavior. Do not implement Hide by terminating the app or pretending it saved documents.
- Standard Quit requests a normal close. Save prompts and refused quits must be respected. Never force a still-running main app simply because a normal-close timeout elapsed.
- Force Quit explicitly permits losing unsaved changes and requests immediate termination.
- Support a per-app action override with a Default/inherit option, independent of the per-app timeout. Show the effective action in rows and countdown labels (Next to hide / Next to close; Hiding… / Closing…).
- Hidden apps with effective Hide leave the pending countdown/queue, but still count as running. Apps configured to quit can remain eligible when hidden.
- At most one action attempt per process per uninterrupted idle episode. New user input resets eligibility. Do not repeatedly trigger hide/quit/save prompts every timer tick.

Dedicated unsaved-work card behavior:

1. Default policy is Leave open. Persist it independently of the primary action.
2. Enable the whole card only when the global/default primary action is Standard Quit. For global Hide or Force Quit, gray it out and disable all its controls, retaining the saved fallback selection. Returning to Standard Quit restores that choice. macOS uses opacity 0.45 while disabled.
3. The runtime must enforce this too: global Hide/Force Quit bypass fallback handling even if an individual app overrides its primary action to Standard Quit. Conversely, a per-app Hide/Force Quit never waits for an unsaved-work fallback.
4. After a Standard Quit request, only positively recognized save-decision evidence can invoke the chosen fallback. A slow, busy, hung or refusing process alone is not evidence of unsaved work.
5. Leave open preserves the app and save prompt. Hide preserves both and provides normal restoration. Explicit fallback Force Quit discards unsaved changes; show that consequence beside the control.
6. Missing inspection access, unsupported apps, ambiguous dialogs and unsupported localizations fail open: leave the app alone. Never click Save, Don't Save, Delete or Cancel automatically.
7. User input or pausing monitoring cancels pending fallback processing. Do not later force-quit a process based on a prompt from an abandoned idle episode.
8. macOS checks evidence between one and thirty seconds after the close request and applies the fallback once. It then abandons an unanswered request. Windows may adapt scheduling while preserving bounded inspection and cancellation.

Evidence model (`UnsavedWork.swift`): edited-document evidence plus an actual save-decision dialog with Save, Don't Save and Cancel controls. Native AppKit keep/discard panels can instead use their stable save-panel/button identifiers, because autosaving may clear the edited flag while a discard decision is still required. This fixed TextEdit's Delete button on unnamed drafts. Windows should use appropriate UI Automation and native control evidence, bound to the specific target process, with bounded traversal/timeouts. Do not port AppKit identifiers or macOS Accessibility permission UI literally. Ordinary file-save pickers are not sufficient evidence. English title recognition is limited; stable native identifiers may support additional cases. Be explicit about supported apps and languages.

## 3. Background cleanup and process tracking

The optional Close remaining background processes setting is separate from the unsaved-work card. Disable it for global Hide. It never runs as part of a Hide action.

On macOS, capture only matching background instances when requesting quit, exclude the main process and other regular app instances, and clean up those captured helpers only after the main app's termination is confirmed. Do not target newly relaunched instances or terminate the main app/save warning as cleanup. Adapt process identity and lifetime checks to Windows; beware PID reuse and broad name matching. Preserve the existing Windows tray/distribution logic.

## 4. Quick setup tips — explicitly requested for Windows parity

Place a compact **Quick setup** card immediately below navigation, separate from the pinned bottom status. Allow the tips region to scroll/yield space as the window shrinks. Dismiss is centered with no separating rule.

Final sequence on macOS:

1. If inspection permission is missing, show **Enable Accessibility**, a short explanation that it supports unsaved-work warning recognition, and **Review Accessibility**.
2. Review navigates to System & Startup, scrolls to the Accessibility card and highlights it twice. If Reduce Motion is enabled, use one steady highlight rather than pulses. Navigation itself does not grant OS permissions. The permission card provides explicit request/open-settings controls.
3. Refresh permission state while tips are visible (macOS polls every two seconds), so granting access advances automatically to the next tip.
4. The next tip is **Review your settings**, explaining defaults may not suit the user, with links to Inactivity Rules and System & Startup.
5. Dismiss skips only the current tip. Dismissing the final settings-review tip stays dismissed after restarting. Persist the accessibility-tip dismissal separately.
6. A returning macOS installation whose Accessibility access is missing gets **Recheck Accessibility access** even if initial tips were dismissed. Only when the system switch is already on but access still fails, offer removing and re-adding the installed app in the OS permission list. This recovery dismissal is scoped to a build identity, and a granted state clears recovery dismissal.

Windows adaptation: retain the sequence, navigation/highlight, live capability refresh, persistence and compact placement. Replace macOS-specific Accessibility/Settings instructions with accurate Windows capability guidance only if needed. Do not invent a macOS-style permission gate on Windows or ask for administrator privileges without a real platform need. If no inspection setup is required, start with Review your settings. Respect Windows reduced-animation/accessibility settings. Do not let a dismissed onboarding tip suppress genuinely relevant recovery guidance.

## 5. Optional close notifications

Provide **Send notifications after closing apps** in System & Startup, off by default including upgrades. Persist opt-out. Request platform notification authorization only as appropriate when enabled; handle blocked notifications through accurate system-settings guidance.

Notify only after confirming actual process termination. A successful close API call is not proof of exit. Combine exits observed together, show app names, keep notifications silent, and never report Hide/refused quits as closed. Names are sorted, control characters sanitized, each limited to 60 Unicode scalars, first three shown plus an additional count. Turning notifications off suppresses delivery, including pending closes.

Use the normal leading sender-app icon. There must be no decorative right-side logo/checkmark attachment. No Send Test Notification control or temporary diagnostic menu/app should ship. Keep useful isolated regression tests.

### macOS icon diagnosis and fix (platform-specific context)

The actual app repeatedly showed a generic leading notification icon, while identical minimal sender code and artwork under a fresh diagnostic bundle identity worked. Reinstalls, signing/registration changes and notification-service restarts did not fix the original identity. Rebuilding the per-user IconServices `store.index` finally restored the proper leading icon; the user explicitly confirmed it. This was a verified local stale-cache problem, not proof of a subscription requirement or an application notification-payload conflict. Do not add automatic cache deletion to either product.

macOS packaging also now compiles `AppIcon.icon` into the adaptive Assets.car and matching ICNS, merges asset-compiler metadata, declares the explicit ICNS filename, normalizes bundle permissions and leaves Dock appearance selection to the system. It no longer overwrites the compiled fallback with the older source ICNS. Windows should keep valid Windows application/notification registration and its existing icon assets; do not copy IconServices recovery or Apple signing assumptions.

## 6. Startup and persisted settings

macOS now detects the actual login-item launch event instead of guessing from uptime. Login starts in the menu bar; manual opening shows the window; explicit --background remains supported. Windows should use its real startup context and tray conventions, preserving startup/distribution work already present.

macOS retained legacy `quitMethod` values: Standard Quit=0, Force Quit=1; Hide=2. `MonitoredApp.customAction` is optional so old saved app lists decode. Fallback has its own values: Leave open=0, Hide=1, Force Quit=2. These are different enums; do not confuse the integer mappings. Respect Windows' existing persisted format and migrate safely. Other settings include `sendCloseNotifications`, `unsavedWorkAction`, `fullyCloseApps`, `setupTipsDismissed`, and `accessibilityTipDismissed`; recovery/build-trust keys are macOS-specific. Preferences and monitored apps must survive upgrades.

## 7. Cleanup and what was deliberately retained

Removed: temporary test-notification button/method, developer Preview menu, diagnostic/preview app bundles, temporary senders/icon probes/backups and obsolete macOS DMGs/ZIPs. About artwork and installed app/tray/notification icons remain. The current 1.0.18 DMG/ZIP/checksums remain. About 320 MB of stale local artifacts were removed before the final sidebar-logo update. Isolated test fixtures and the --ui-preview fixture mode remain for regression work; no second preview app should run alongside the real app during user acceptance.

Do the equivalent Windows cleanup only for identified disposable artifacts. Preserve source, tests, user settings, active releases, signing materials and the uncommitted Store work. Do not indiscriminately delete the VM shared folder.

## 8. macOS implementation map

| File | Final responsibility |
| --- | --- |
| `ContentView.swift` | Text-only sidebar header, tips, reserved footer, idle artwork, action-aware rows/queue, centered bounded content |
| `SettingsViews.swift` | Primary action, separate gated unsaved-work card, close notifications, Accessibility scroll/highlight |
| `AppState.swift` | Settings compatibility, action overrides, one-attempt tracking, pending quit/fallback lifecycle, confirmed notifications, tips and recovery |
| `IdleAction.swift` | Primary-action enum and sanitized combined notification text |
| `UnsavedWork.swift` | Fallback enum and conservative supported save-warning evidence |
| `AccessRecovery.swift` | Executable/build identity and permission recovery tip predicate |
| `LaunchContext.swift` | Login event and foreground/background launch decisions |
| `AppDelegate.swift` | Login launch integration, foreground silent banner presentation, native window/menu behavior, bundle registration |
| `AppIcon.icon/`, `build.sh` | Adaptive icon source, universal build, plist/icon metadata, permissions/signing |
| `tests/PresentationChecks.swift`, `tests/LifecycleHelper.swift`, `tests/run-checks.sh` | Isolated fixtures, disposable native app lifecycle checks and settings/presentation coverage |
| `README.md`, `CHANGELOG.md`, `docs/TESTING-1.0.18.md` | Usage, final change log, validation and icon-recovery evidence |

Likely Windows starting points: `IdleSentry for Windows/MainWindow.xaml`, `MainWindow.xaml.cs`, `AppState.cs`, existing `CloseNotification.cs`, and `IdleSentry.ChooserTests/`. Verify current architecture first; names are guidance, not a mandate to bypass existing abstractions.

## 9. Acceptance checklist for the Windows agent

- Upgrade existing preferences: default action/timeouts/app list unchanged, absent fallback defaults to Leave open, absent notification option defaults off.
- Each primary action and per-app override persists and is reflected in countdown/row labels.
- Disposable unsaved document: Hide preserves process, document and restoration; no repeated actions or false close notifications.
- Standard Quit with save refusal remains open; cleanup must not force it closed. Slow quit with no evidence stays open.
- Recognized save warning: fallback Leave open preserves it; Hide preserves/restores it; explicit Force Quit terminates only the disposable target. Test missing/ambiguous evidence and unsupported apps too.
- Global Hide/Force Quit disables the whole fallback card and runtime policy, retaining the chosen fallback. Returning to Standard Quit restores it. Verify per-app edge cases.
- Activity and Pause cancel pending fallback; one attempt per process per idle episode; relaunch does not inherit an old process action.
- Confirmed exits notify once, silently and in a batch; disabled notifications, Hide, declined quits and failed terminations do not notify. Correct leading icon, no right-side decoration/test button.
- Tips appear in sequence, navigate/scroll/highlight accurately, respect reduced animation, advance when capability is available and persist per-tip/final dismissals.
- Compact, normal and maximized/fullscreen sizes at supported DPI scales: no header overlap, clipped card or footer; tips scroll; wide content centered. Check ready, waiting, empty, paused, countdown, and idle-plus-countdown states, including a running app while actively moving the mouse.
- Only the real app is installed/running after acceptance. Startup launches stay quiet in tray; manual launch opens normally.
- Run existing Windows test suites and add meaningful lifecycle/settings checks for new behavior, using disposable helper apps and isolated settings. Do not use the user's real documents for destructive tests.

macOS verification already completed: 101 checks passed in prior local runs; universal arm64/x86_64 packaging, strict app signature verification, DMG verification and SHA-256 checks passed for final local build 202610240007. The user confirmed the corrected leading notification icon and compact active-input footer. Wide layout and text-only sidebar were visually verified. Real TextEdit native save-warning Hide/Force Quit was tested with disposable content; Office-specific support and real login after sign-in remain manual acceptance items. The final pre-push rerun passed all 101 checks after isolating synthetic idle episodes from the live production timer in the test harness; production behavior was unchanged. Details are in `docs/TESTING-1.0.18.md`.
