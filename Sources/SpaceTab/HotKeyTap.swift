import AppKit
import Carbon.HIToolbox
import CoreGraphics

enum HotKeyMode: String {
    case option
    case command

    /// The modifier that must be held. Releasing it commits the selection.
    var flag: CGEventFlags {
        switch self {
        case .option: return .maskAlternate
        case .command: return .maskCommand
        }
    }

    /// Modifiers that must be absent, so we don't swallow neighbouring
    /// shortcuts like Ctrl+Option+Tab.
    var conflicting: [CGEventFlags] {
        switch self {
        case .option: return [.maskCommand, .maskControl]
        case .command: return [.maskAlternate, .maskControl]
        }
    }

    var title: String {
        switch self {
        case .option: return "Option+Tab"
        case .command: return "Cmd+Tab"
        }
    }
}

/// Intercepts the trigger chord at the session event tap so the keystroke never
/// reaches the focused app — or, in `.command` mode, the WindowServer's built-in
/// app switcher. Session taps run ahead of symbolic hotkeys in the event
/// pipeline, which is what makes replacing Cmd+Tab possible.
///
/// Failure modes are deliberately safe: if the callback stalls, macOS disables
/// the tap and the system switcher comes straight back; if the process dies, the
/// tap dies with it. Quitting SpaceTab always restores stock Cmd+Tab.
final class HotKeyTap {
    var onCycle: ((_ forward: Bool) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    var mode: HotKeyMode = .option {
        didSet { engaged = false }
    }

    private var tap: CFMachPort?
    private var engaged = false

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<HotKeyTap>.fromOpaque(refcon).takeUnretainedValue()
            return owner.handle(type: type, event: event)
        }

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        tap = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passthrough = Unmanaged.passUnretained(event)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return passthrough
        }

        let flags = event.flags

        if type == .flagsChanged {
            if engaged && !flags.contains(mode.flag) {
                engaged = false
                onCommit?()
            }
            return passthrough
        }

        guard type == .keyDown else { return passthrough }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let backward = flags.contains(.maskShift)

        if keyCode == kVK_Tab,
           flags.contains(mode.flag),
           !mode.conflicting.contains(where: { flags.contains($0) }) {
            engaged = true
            onCycle?(!backward)
            return nil
        }

        guard engaged else { return passthrough }

        switch keyCode {
        case kVK_Escape:
            engaged = false
            onCancel?()
            return nil
        case kVK_RightArrow, kVK_DownArrow:
            onCycle?(true)
            return nil
        case kVK_LeftArrow, kVK_UpArrow:
            onCycle?(false)
            return nil
        default:
            return passthrough
        }
    }
}
