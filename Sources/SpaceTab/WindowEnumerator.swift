import AppKit

struct SpaceApp {
    let pid: pid_t
    let name: String
    let icon: NSImage?
    let topWindowID: CGWindowID
}

enum WindowEnumerator {
    /// Apps owning at least one ordinary window on the Space that is currently
    /// displayed. `.optionOnScreenOnly` is the whole trick: the window server
    /// only reports windows on the active Space, so no Space APIs are needed.
    /// Returned in front-to-back z-order.
    static func appsOnCurrentSpace(excluding excludedPID: pid_t) -> [SpaceApp] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let entries = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var seen = Set<pid_t>()
        var result: [SpaceApp] = []

        for entry in entries {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != excludedPID,
                  let windowID = entry[kCGWindowNumber as String] as? CGWindowID,
                  !seen.contains(pid)
            else { continue }

            if let alpha = entry[kCGWindowAlpha as String] as? Double, alpha < 0.05 { continue }

            if let bounds = entry[kCGWindowBounds as String] as? [String: Any],
               let width = bounds["Width"] as? Double,
               let height = bounds["Height"] as? Double,
               width < 48 || height < 48 {
                continue
            }

            guard let running = NSRunningApplication(processIdentifier: pid),
                  running.activationPolicy == .regular
            else { continue }

            seen.insert(pid)
            result.append(SpaceApp(
                pid: pid,
                name: running.localizedName ?? (entry[kCGWindowOwnerName as String] as? String ?? "Unknown"),
                icon: running.icon,
                topWindowID: windowID
            ))
        }

        return result
    }
}
