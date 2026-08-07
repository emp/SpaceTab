import AppKit

/// Flat, opaque panel on purpose: no blur, no window thumbnails. Over screen
/// sharing this encodes as a handful of solid blocks instead of a full-frame
/// translucent recomposite.
///
/// Coordinates are the default bottom-left origin. A flipped view would be
/// tidier for laying out a row with a label under it, but `NSImage.draw(in:)`
/// does not compensate for flipping and renders icons upside down.
final class SwitcherView: NSView {
    var apps: [SpaceApp] = []
    var selection = 0
    private(set) var iconSize: CGFloat = SwitcherView.maxIconSize

    /// Measured against the native switcher: its tiles sit almost edge to edge,
    /// and the selection highlight is one icon canvas wide. The visual breathing
    /// room between icons comes from the transparent margin baked into every
    /// macOS app icon (art fills ~80% of its canvas), not from layout padding —
    /// so `cellPadding` stays near zero or the gap reads twice as wide as it
    /// should.
    private static let maxIconSize: CGFloat = 128
    private static let minIconSize: CGFloat = 32
    private static let cellPadding: CGFloat = 4
    private static let edgePadding: CGFloat = 14
    private static let labelHeight: CGFloat = 26
    static let cornerRadius: CGFloat = 18

    /// Off when an NSVisualEffectView behind us supplies the background.
    var drawsBackground = true

    private var cellSize: CGFloat { iconSize + Self.cellPadding * 2 }

    /// Matches the native switcher: full-size icons until the row would overflow
    /// the screen, then shrink to fit rather than wrap or scroll.
    func layoutSize(maxWidth: CGFloat) -> NSSize {
        let count = CGFloat(max(apps.count, 1))
        iconSize = Self.maxIconSize

        let available = maxWidth - Self.edgePadding * 2
        if cellSize * count > available {
            let fitted = (available / count) - Self.cellPadding * 2
            iconSize = max(Self.minIconSize, floor(fitted))
        }

        return NSSize(
            width: min(maxWidth, cellSize * count + Self.edgePadding * 2),
            height: cellSize + Self.labelHeight + Self.edgePadding * 2
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

        let background = isDark
            ? NSColor(calibratedWhite: 0.14, alpha: 0.96)
            : NSColor(calibratedWhite: 0.95, alpha: 0.96)
        // Native darkens the selected tile in both appearances rather than
        // lightening it in dark mode.
        let highlight = isDark
            ? NSColor(calibratedWhite: 0.0, alpha: 0.28)
            : NSColor(calibratedWhite: 0.0, alpha: 0.14)
        let labelColor = isDark
            ? NSColor(calibratedWhite: 0.88, alpha: 1.0)
            : NSColor(calibratedWhite: 0.24, alpha: 1.0)

        if drawsBackground {
            background.setFill()
            NSBezierPath(roundedRect: bounds,
                         xRadius: Self.cornerRadius,
                         yRadius: Self.cornerRadius).fill()
        }

        guard !apps.isEmpty else { return }

        NSGraphicsContext.current?.imageInterpolation = .high
        let rowBottom = Self.edgePadding + Self.labelHeight

        for (index, app) in apps.enumerated() {
            let cell = NSRect(
                x: Self.edgePadding + CGFloat(index) * cellSize,
                y: rowBottom,
                width: cellSize,
                height: cellSize
            )

            if index == selection {
                highlight.setFill()
                NSBezierPath(roundedRect: cell, xRadius: 12, yRadius: 12).fill()
            }

            let iconRect = cell.insetBy(dx: Self.cellPadding, dy: Self.cellPadding)
            app.icon?.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        let index = min(selection, apps.count - 1)
        let title = apps[index].name as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: labelColor
        ]
        let textSize = title.size(withAttributes: attributes)

        // Native anchors the label under the selected icon, not the panel,
        // clamped so long names stay inside the panel.
        let selectedCentre = Self.edgePadding + (CGFloat(index) + 0.5) * cellSize
        let maxX = bounds.width - Self.edgePadding - textSize.width
        let x = min(max(Self.edgePadding, selectedCentre - textSize.width / 2), max(Self.edgePadding, maxX))

        let titleRect = NSRect(
            x: x,
            y: Self.edgePadding + (Self.labelHeight - textSize.height) / 2,
            width: min(textSize.width, bounds.width - Self.edgePadding * 2),
            height: textSize.height
        )
        title.draw(in: titleRect, withAttributes: attributes)
    }
}
