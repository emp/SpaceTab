import AppKit

// Renders the same SF Symbol used in the menu bar into a macOS app icon.
// Usage: swift Tools/makeicon.swift <output.iconset>

let outputDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

/// Apple's macOS icon grid: the rounded body fills 824 of a 1024 canvas.
let bodyRatio: CGFloat = 824.0 / 1024.0
let cornerRatio: CGFloat = 0.2237
let glyphRatio: CGFloat = 0.52

func renderIcon(size: CGFloat) -> Data {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let body = NSRect(x: 0, y: 0, width: size, height: size)
            .insetBy(dx: size * (1 - bodyRatio) / 2, dy: size * (1 - bodyRatio) / 2)

        let path = NSBezierPath(roundedRect: body,
                                xRadius: body.width * cornerRatio,
                                yRadius: body.width * cornerRatio)
        path.addClip()

        NSGradient(colors: [
            NSColor(calibratedRed: 0.29, green: 0.30, blue: 0.32, alpha: 1),
            NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        ])?.draw(in: body, angle: -90)

        let glyphPoint = size * glyphRatio
        let config = NSImage.SymbolConfiguration(pointSize: glyphPoint, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))

        if let symbol = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let s = symbol.size
            symbol.draw(at: NSPoint(x: (size - s.width) / 2, y: (size - s.height) / 2),
                        from: .zero, operation: .sourceOver, fraction: 1)
        }
        return true
    }

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { fatalError("render failed at \(size)") }
    return png
}

// name -> pixel dimension
let variants: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

var cache: [CGFloat: Data] = [:]
for (name, size) in variants {
    let png = cache[size] ?? renderIcon(size: size)
    cache[size] = png
    try png.write(to: URL(fileURLWithPath: "\(outputDir)/\(name)"))
}
print("wrote \(variants.count) variants to \(outputDir)")
