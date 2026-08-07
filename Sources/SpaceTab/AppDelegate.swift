import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = SwitcherPanel()
    private let view = SwitcherView()
    private let hotkey = HotKeyTap()

    private var apps: [SpaceApp] = []
    private var selection = 0
    private var mru: [pid_t] = []
    private var statusItem: NSStatusItem?
    private var toggleView: ToggleMenuItemView?
    private var blurToggleView: ToggleMenuItemView?
    private var permissionTimer: Timer?
    private var announcedPermissionNeed = false

    private static let modeKey = "hotKeyMode"
    private static let blurKey = "useBlurBackground"

    /// The real system material, same as the native switcher. Off by default:
    /// a blurred backdrop is a different image every time it appears and
    /// recomposites whatever is behind it, which is exactly what a screen
    /// sharing encoder handles worst. A flat panel is a few solid blocks.
    private var usesBlur: Bool {
        get { UserDefaults.standard.bool(forKey: Self.blurKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.blurKey)
            dismiss()
            applyBackground()
            refreshMenu()
        }
    }

    /// A rounded rect stretched from its centre, so one small image masks any
    /// panel width.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private func applyBackground() {
        view.drawsBackground = !usesBlur

        guard usesBlur else {
            panel.contentView = view
            return
        }

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        // layer.cornerRadius does not clip a visual effect view: the window
        // server composites the material behind the layer, so the square bounds
        // show through. maskImage is the supported way to round it.
        effect.maskImage = Self.roundedMask(radius: SwitcherView.cornerRadius)

        view.frame = effect.bounds
        view.autoresizingMask = [.width, .height]
        effect.addSubview(view)
        panel.contentView = effect
    }

    private var mode: HotKeyMode {
        get {
            HotKeyMode(rawValue: UserDefaults.standard.string(forKey: Self.modeKey) ?? "") ?? .option
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.modeKey)
            hotkey.mode = newValue
            dismiss()
            refreshMenu()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Registered rather than hardcoded, so a value the user has explicitly
        // toggled still wins; these apply only when nothing is stored yet.
        UserDefaults.standard.register(defaults: [
            Self.modeKey: HotKeyMode.command.rawValue,
            Self.blurKey: true
        ])

        applyBackground()
        installStatusItem()
        hotkey.mode = mode

        if let front = NSWorkspace.shared.frontmostApplication {
            mru = [front.processIdentifier]
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        hotkey.onCycle = { [weak self] forward in self?.cycle(forward: forward) }
        hotkey.onCommit = { [weak self] in self?.commit() }
        hotkey.onCancel = { [weak self] in self?.dismiss() }

        startHotkey()
    }

    // MARK: - Accessibility permission

    private func startHotkey() {
        if hotkey.start() {
            permissionTimer?.invalidate()
            permissionTimer = nil
            updateStatusTitle(enabled: true)
            return
        }

        updateStatusTitle(enabled: false)

        // Prompt exactly once. The prompting variant of the trust check spawns a
        // fresh dialog on every call, so it must never live inside the poll loop.
        //
        // macOS suppresses this dialog after repeated tccutil resets, which is
        // easy to hit while iterating, so it is a hint rather than the mechanism:
        // System Settings is opened directly and the menu bar icon switches to a
        // warning, so the app is never silently inert.
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(prompt)

        if !announcedPermissionNeed {
            announcedPermissionNeed = true
            openAccessibilitySettings()
        }

        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard AXIsProcessTrusted() else { return }

            if self.hotkey.start() {
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
                self.updateStatusTitle(enabled: true)
            } else {
                // Trusted, but the tap still won't attach: this process started
                // before the grant landed. A fresh process picks it up.
                self.relaunch()
            }
        }
    }

    private func relaunch() {
        let defaults = UserDefaults.standard
        let key = "lastRelaunch"
        let last = defaults.object(forKey: key) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 30 else { return }
        defaults.set(Date(), forKey: key)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: - MRU

    @objc private func applicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        mru.removeAll { $0 == pid }
        mru.insert(pid, at: 0)
    }

    private func ordered(_ candidates: [SpaceApp]) -> [SpaceApp] {
        var remaining = candidates
        var result: [SpaceApp] = []

        for pid in mru {
            if let index = remaining.firstIndex(where: { $0.pid == pid }) {
                result.append(remaining.remove(at: index))
            }
        }
        result.append(contentsOf: remaining)
        return result
    }

    // MARK: - Switching

    private func cycle(forward: Bool) {
        if panel.isVisible {
            guard !apps.isEmpty else { return }
            selection = (selection + (forward ? 1 : -1) + apps.count) % apps.count
            view.selection = selection
            view.needsDisplay = true
            return
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        apps = ordered(WindowEnumerator.appsOnCurrentSpace(excluding: ownPID))
        guard !apps.isEmpty else { return }

        selection = apps.count > 1 ? (forward ? 1 : apps.count - 1) : 0
        present()
    }

    private func present() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }

        view.apps = apps
        view.selection = selection

        let size = view.layoutSize(maxWidth: frame.width - 80)
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        view.needsDisplay = true
        panel.orderFrontRegardless()
        // The shadow is cached against the previous shape; without this it keeps
        // the old panel's rectangle outline.
        panel.invalidateShadow()
    }

    private func commit() {
        guard panel.isVisible else { return }
        let target = apps.indices.contains(selection) ? apps[selection] : nil
        dismiss()
        if let target { WindowRaiser.activate(target) }
    }

    private func dismiss() {
        panel.orderOut(nil)
    }

    // MARK: - Menu bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "square.on.square",
            accessibilityDescription: "SpaceTab"
        )

        let menu = NSMenu()
        let heading = NSMenuItem(title: "SpaceTab", action: nil, keyEquivalent: "")
        heading.tag = 2
        menu.addItem(heading)
        menu.addItem(.separator())

        let status = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
        status.tag = 1
        menu.addItem(status)
        menu.addItem(.separator())

        let toggle = ToggleMenuItemView(title: "Replace Cmd+Tab")
        toggle.onToggle = { [weak self] isOn in
            self?.mode = isOn ? .command : .option
        }
        let replace = NSMenuItem()
        replace.view = toggle
        menu.addItem(replace)
        toggleView = toggle

        let blur = ToggleMenuItemView(title: "Blur background")
        blur.onToggle = { [weak self] isOn in self?.usesBlur = isOn }
        let blurItem = NSMenuItem()
        blurItem.view = blur
        menu.addItem(blurItem)
        blurToggleView = blur

        menu.addItem(withTitle: "Open Accessibility Settings…",
                     action: #selector(openAccessibilitySettings),
                     keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
        refreshMenu()
    }

    private func refreshMenu() {
        statusItem?.menu?.item(withTag: 2)?.title = "SpaceTab"
        toggleView?.update(isOn: mode == .command, subtitle: "Trigger: \(mode.title)")
        blurToggleView?.update(isOn: usesBlur,
                               subtitle: usesBlur ? "Native look" : "Flat — faster remote")
    }

    private func updateStatusTitle(enabled: Bool) {
        statusItem?.button?.image = NSImage(
            systemSymbolName: enabled ? "square.on.square" : "exclamationmark.triangle.fill",
            accessibilityDescription: "SpaceTab"
        )
        guard let entry = statusItem?.menu?.item(withTag: 1) else { return }
        entry.title = enabled ? "Active" : "Needs Accessibility permission"
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
