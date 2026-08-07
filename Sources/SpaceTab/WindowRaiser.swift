import AppKit
import ApplicationServices

/// Private but long-stable: maps an AXUIElement window back to its CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

enum WindowRaiser {
    static func activate(_ target: SpaceApp) {
        guard let running = NSRunningApplication(processIdentifier: target.pid) else { return }

        // Raise the specific window we saw on this Space *before* activating, so
        // macOS doesn't yank us to another Space to show some other window.
        raise(pid: target.pid, windowID: target.topWindowID)

        if #available(macOS 14.0, *) {
            running.activate()
        } else {
            running.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private static func raise(pid: pid_t, windowID: CGWindowID) {
        let axApp = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return }

        for window in windows {
            var id: CGWindowID = 0
            guard _AXUIElementGetWindow(window, &id) == .success, id == windowID else { continue }
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            return
        }
    }
}
