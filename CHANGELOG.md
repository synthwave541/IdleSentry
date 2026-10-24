# Release history

## 1.0.19 — 2026-10-24

- Reveal the System is idle card with a clipped upward slide and fade above the pinned sidebar status, using a soft spring and disabling motion for Reduce Motion.
- Add default-on Protect fullscreen playback in Inactivity Rules. Require a visible fullscreen window and a display-awake assertion from that app or a descendant helper; skip Hide, Standard Quit and Force Quit, label protected app rows, and restart the timeout when protection ends.
- Give newly launched or reactivated monitored apps their own fresh inactivity interval, including when keyboard remappers and launchers leave the system input-idle counter unchanged. Other apps keep their existing deadlines.
- Wait for app startup to finish before attempting an idle action. Ignore activation caused by a pending quit/save decision, and clear interaction records when processes exit.

## 1.0.18 — 2026-10-24

- Add Hide alongside Standard Quit and Force Quit, with per-app action overrides and compatible legacy settings. Hidden apps keep their work open and leave the Hide countdown.
- Add a dedicated unsaved-work fallback card: Leave open (default), Hide, or explicit Force Quit. Enable it only for the default Standard Quit action; retain its selection while disabled. Require a recognized save decision rather than a slow or refused quit.
- Recognize native AppKit keep/discard panels, including TextEdit's Delete button for unnamed drafts, and supported English save warnings with edited-document evidence. Missing Accessibility access and unsupported warnings leave work open. Input or pausing cancels fallback handling.
- Attempt each process once per uninterrupted idle episode. Perform optional background cleanup only after the main app exits, excluding other regular app instances and all Hide actions.
- Add optional silent notifications for confirmed app exits, off by default. Combine exits observed together; do not report Hide or declined quits. Use the system-managed leading app icon with no right-side artwork.
- Compile the existing artwork as an adaptive icon catalog, retain its generated ICNS fallback, merge compiler icon metadata, normalize bundle permissions, and remove fixed Dock-image overrides. Document verified local IconServices-cache recovery separately from product code.
- Add a System is idle sidebar card and sequential, dismissible Quick setup tips below navigation. Link to rules and system settings; scroll to and highlight Accessibility twice, with a steady highlight for Reduce Motion. Refresh permission state and show recovery guidance for returning installations.
- Reserve sidebar footer space at compact sizes, center the bounded main content column on wide windows, and simplify the sidebar header to app name and version. Keep the existing native window and toolbar behavior.
- Use the actual login-launch event instead of boot uptime so login launches stay in the menu bar; preserve normal manual opening and explicit background launches.
- Remove temporary test-notification controls, the developer preview menu, and diagnostic apps/artifacts after verification. Retain isolated regression fixtures.
- Expand automated settings, presentation, discovery, launch, save-warning and lifecycle coverage; prepare universal Intel/Apple Silicon packages at 1.0.18. Public release assets and the signed update feed are published separately from source.

## 1.0.14 — 2026-10-21

- Add a native Dashboard, resizable split-view sidebar, system-accent controls and focused settings pages.
- Refresh application rows, app discovery and multi-selection, and About/website links.
- Show one quiet countdown card, with long-name truncation and an additional-app count.
- Open a bounded, scrollable closing queue that stays available when activity resets the timer.
- Add isolated sample-data previews and presentation/settings/discovery checks.
- Preserve existing monitored apps, preferences and native quit strategies.
- Track the product version in VERSION and support reproducible universal builds.

This version aligns with Windows source version 1.0.14. Public download assets are published separately from source pushes.
