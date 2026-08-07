import AppKit

/// A menu row with a native NSSwitch, in the style of Tailscale's menu bar item.
/// NSMenuItem renders any view you hand it; the switch is stock AppKit, so it
/// picks up the system accent colour, light/dark appearance and accessibility
/// behaviour for free.
final class ToggleMenuItemView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let toggle = NSSwitch()

    var onToggle: ((Bool) -> Void)?

    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 44))

        titleLabel.stringValue = title
        titleLabel.font = NSFont.menuFont(ofSize: 0)
        titleLabel.textColor = .labelColor

        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor

        toggle.target = self
        toggle.action = #selector(switchChanged)

        let text = NSStackView(views: [titleLabel, subtitleLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1

        let row = NSStackView(views: [text, NSView(), toggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        // 14pt leading inset lines the title up with standard menu item titles.
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
            heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    func update(isOn: Bool, subtitle: String) {
        toggle.state = isOn ? .on : .off
        subtitleLabel.stringValue = subtitle
    }

    @objc private func switchChanged() {
        onToggle?(toggle.state == .on)
    }
}
