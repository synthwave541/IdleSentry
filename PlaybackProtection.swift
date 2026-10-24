import AppKit
import IOKit.pwr_mgt
import Darwin

/// A display-awake assertion is a playback hint, not proof of a playing video.
/// Require a visible fullscreen window owned by that process as well. This is
/// intentionally app-agnostic and never reads browser tabs or captures pixels.
struct PlaybackEvidence {
    var fullscreenOwners: Set<pid_t>
    var displayAssertionOwners: Set<pid_t>
    var parents: [pid_t: pid_t] = [:]

    var protectedProcesses: Set<pid_t> {
        var protected = Set<pid_t>()
        for owner in displayAssertionOwners {
            var process = owner
            var visited = Set<pid_t>()
            for _ in 0..<16 {
                guard process > 1, visited.insert(process).inserted else { break }
                if fullscreenOwners.contains(process) { protected.insert(process); break }
                guard let parent = parents[process] else { break }
                process = parent
            }
        }
        return protected
    }

    static func coversDisplay(window: CGRect, display: CGRect) -> Bool {
        guard window.width > 0, window.height > 0, display.width > 0, display.height > 0 else { return false }
        // Allow compositor rounding, not a maximized window's menu/title bars.
        let tolerance: CGFloat = 2
        return abs(window.minX - display.minX) <= tolerance &&
            abs(window.minY - display.minY) <= tolerance &&
            abs(window.maxX - display.maxX) <= tolerance &&
            abs(window.maxY - display.maxY) <= tolerance
    }

    static func isDisplayAssertion(type: String?, level: Int?) -> Bool {
        type == (kIOPMAssertionTypePreventUserIdleDisplaySleep as String) &&
            level == Int(kIOPMAssertionLevelOn)
    }
}

enum PlaybackProtection {
    static func protectedProcesses() -> Set<pid_t> {
        let displays = NSScreen.screens.compactMap { screen -> CGRect? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
        }
        guard !displays.isEmpty,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        var fullscreenOwners = Set<pid_t>()
        for window in windows {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  displays.contains(where: { PlaybackEvidence.coversDisplay(window: rect, display: $0) }) else { continue }
            fullscreenOwners.insert(pid)
        }
        guard !fullscreenOwners.isEmpty else { return [] }
        let owners = displayAssertionOwners()
        var parents: [pid_t: pid_t] = [:]
        for owner in owners {
            var process = owner
            for _ in 0..<16 {
                guard process > 1, !fullscreenOwners.contains(process), parents[process] == nil else { break }
                var info = proc_bsdinfo()
                let size = Int32(MemoryLayout<proc_bsdinfo>.size)
                guard proc_pidinfo(process, PROC_PIDTBSDINFO, 0, &info, size) == size else { break }
                let parent = pid_t(info.pbi_ppid)
                parents[process] = parent
                guard parent != process else { break }
                process = parent
            }
        }
        return PlaybackEvidence(fullscreenOwners: fullscreenOwners, displayAssertionOwners: owners, parents: parents).protectedProcesses
    }

    static func displayAssertionOwners() -> Set<pid_t> {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess,
              let assertions = raw?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return [] }
        return Set(assertions.compactMap { pid, entries in
            entries.contains(where: {
                PlaybackEvidence.isDisplayAssertion(type: $0[kIOPMAssertionTypeKey as String] as? String,
                    level: ($0[kIOPMAssertionLevelKey as String] as? NSNumber)?.intValue)
            }) ? pid.int32Value : nil
        })
    }
}
