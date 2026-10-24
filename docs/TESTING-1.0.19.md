# IdleSentry 1.0.19 — launcher/keyboard-remapper regression

Status: release publication authorized by the user on October 24, 2026. Historical local checks below retain their original scope.

## Reproduction and behavior

A Karabiner Elements key launches Brave without resetting the system input-idle counter. Previously a newly discovered Brave process inherited all of the time from before its launch, so the first timer tick could immediately close it. Relaunching produced the same cycle.

Launch and foreground-activation workspace notifications now record a per-process monotonic timestamp. The process uses the smaller of system-input inactivity and time since that interaction, followed by the existing 1.25-second grace period. A newly launched/reactivated app receives its configured global or custom timeout, then becomes eligible normally if no further input occurs. Other apps retain their deadlines. Startup-in-progress apps are not acted on. A quit request can itself activate a save dialog; interaction events for a process with a pending quit are deliberately ignored so they cannot re-arm it or bypass its fallback. Termination removes the interaction record and normal updates prune exited PIDs.

## Validation

Automated checks cover an hour-old input counter, full timeout after launch, subsequent countdown/closing, reactivation, unrelated-process independence, normal input taking precedence, stale PID cleanup, and preserving an already pending quit. A disposable native helper configured before launch exercises the actual workspace launch notification with a controlled monotonic clock. Existing save-warning, quit/Hide, notification and settings checks remain in the suite.

Manual acceptance requires the user's actual Karabiner mapping: leave the Mac idle beyond Brave's configured timeout, open Brave with the mapped key without moving the mouse, and confirm it remains open for a fresh timeout. Continued absence of input should eventually close/hide it according to the configured rule. Repeat after reopening. Verify ordinary keyboard/mouse activity resets timing, another already-idle monitored app keeps its original deadline, and Standard Quit save prompts retain their selected policy.

## Local result

All 113 checks passed. Universal 1.0.19 (internal build 202610240008) was packaged, its DMG and SHA-256 checksums verified, and the installed app signature verified. The local app in /Applications was updated. The actual Karabiner key still needs user acceptance; no 1.0.19 GitHub release has been published.

## Fullscreen playback protection

A default-on persisted setting `protectFullscreenPlayback` lives under Inactivity Rules → Playback protection. Missing settings on upgrade default to true; explicit false remains false. `PlaybackProtection.swift` combines visible layer-zero screen-covering window bounds with active `PreventUserIdleDisplaySleep` assertions. Assertion owners may be the window owner or a descendant process (bounded parent traversal supports Chromium helpers). Unrelated system-wide assertions do not exempt an app. The detector uses Core Graphics, IOKit and process information without screen capture or Accessibility inspection.

Protected processes are excluded from all idle actions and the pending/closing queue, while staying in running counts. Rows show Playback protected. A fresh monotonic activity floor is recorded while protected, so losing protection starts a full timeout. A detected protected target has pending fallback/cleanup tracking cancelled before unsaved-work handling. It cannot undo a quit request already delivered before playback evidence appears.

Automated coverage includes fullscreen geometry on external/negative-coordinate displays, maximizing versus fullscreen, display versus system/audio sleep assertions, assertion level, same-process and child-helper ownership, unrelated assertions, cycle bounds, all three primary actions, queue exclusion, protection ending, persisted opt-out and pending destructive fallback cancellation. A real short-lived display assertion validates the IOKit dictionary/owning-PID bridge; it is released immediately. Lifecycle checks use disposable native apps and injected playback evidence rather than claiming actual browser playback was tested.

Manual acceptance: use a short timeout and a disposable YouTube session in Brave fullscreen, then a disposable local VLC video fullscreen. Leave input idle past the timeout and verify the app stays open and its row reports Playback protected. Exit fullscreen or stop playback, verify normal eligibility returns after a fresh interval. Check each primary action using disposable content, explicit toggle-off, restart persistence, a second monitor, and an unrelated fullscreen app while another process holds a display-awake request. Pausing may retain protection when the player retains its assertion. Apps that do not publish supported evidence, XPC helpers without an observable descendant relationship, windowed/Picture in Picture playback and audio-only activity are outside this detector's coverage. No claim of universal player support is made.

## Playback build result

All 139 checks passed after playback integration, including the real IOKit assertion ownership check. Universal 1.0.19 internal build 202610240009 replaced the earlier local launcher-only build; its DMG, installed signature and SHA-256 package checks passed. The real installed Inactivity Rules page was inspected and Protect fullscreen playback was on. Actual fullscreen YouTube/VLC playback remains a manual acceptance item. Source and standalone Windows handoff copies were updated together. No 1.0.19 GitHub release was published.

## Idle-card animation acceptance

The idle footer card reveals upward with a fade inside its own clipped region, above the pinned status card. A 0.48-second soft spring smooths the reveal and dismissal, scoped to isSystemIdle changes. Reduce Motion disables the animation. Check idle onset, real input, pausing/resuming, repeated transitions and minimum window size; no drawing over status text or changes to the monitoring deadline should occur. This cosmetic change is verified by compiling the universal app; no implementation-mirroring animation unit tests were added.

The animation build is universal 1.0.19 internal build 202610240010. Packaging, DMG verification, installed app signature and checksums passed. The installed app reopened normally. No monitored app was running during the final UI check, so the live idle transition remains a user visual acceptance check.

## Release preparation — October 24, 2026

The user authorized publication of the combined 1.0.19 update. Assets are the final universal build 202610240010 with the launcher fix, playback protection and animation, plus a newly generated signed appcast for the exact ZIP. The 139-check run covered runtime behavior before the final presentation-only animation; the final universal package compiled that animation and passed DMG, installed signature and checksum verification. Actual Karabiner key behavior, real YouTube/VLC fullscreen playback and the live animation remain manual acceptance items, not claims established by the automated suite.
