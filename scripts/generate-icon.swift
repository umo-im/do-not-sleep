import AppKit
import Foundation

struct IconSpec {
    let filename: String
    let size: Int
}

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconsetURL = rootURL.appendingPathComponent("Support/AppIcon.iconset", isDirectory: true)
let icnsURL = rootURL.appendingPathComponent("Support/AppIcon.icns")

let specs = [
    IconSpec(filename: "icon_16x16.png", size: 16),
    IconSpec(filename: "icon_16x16@2x.png", size: 32),
    IconSpec(filename: "icon_32x32.png", size: 32),
    IconSpec(filename: "icon_32x32@2x.png", size: 64),
    IconSpec(filename: "icon_128x128.png", size: 128),
    IconSpec(filename: "icon_128x128@2x.png", size: 256),
    IconSpec(filename: "icon_256x256.png", size: 256),
    IconSpec(filename: "icon_256x256@2x.png", size: 512),
    IconSpec(filename: "icon_512x512.png", size: 512),
    IconSpec(filename: "icon_512x512@2x.png", size: 1024),
]

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for spec in specs {
    let image = makeIcon(size: CGFloat(spec.size))
    let destinationURL = iconsetURL.appendingPathComponent(spec.filename)
    try writePNG(image: image, to: destinationURL)
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", "-o", icnsURL.path, iconsetURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    throw NSError(domain: "GenerateIcon", code: Int(iconutil.terminationStatus))
}

func makeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("Unable to create graphics context")
    }

    NSGraphicsContext.current?.imageInterpolation = .high
    context.setShouldAntialias(true)

    let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    let insetRect = rect.insetBy(dx: size * 0.06, dy: size * 0.06)
    let radius = size * 0.23

    let backgroundPath = NSBezierPath(roundedRect: insetRect, xRadius: radius, yRadius: radius)
    context.saveGState()
    backgroundPath.addClip()

    let backgroundGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.03, green: 0.13, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.33, blue: 0.43, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.53, blue: 0.56, alpha: 1),
    ])!
    backgroundGradient.draw(in: backgroundPath, angle: -40)

    let glowCenter = CGPoint(x: size * 0.56, y: size * 0.56)
    let glowRadius = size * 0.43
    let glowColors = [
        NSColor(calibratedRed: 0.61, green: 0.95, blue: 0.64, alpha: 0.36).cgColor,
        NSColor(calibratedRed: 0.61, green: 0.95, blue: 0.64, alpha: 0.0).cgColor,
    ] as CFArray
    let glowLocations: [CGFloat] = [0, 1]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let radialGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: glowLocations)!
    context.drawRadialGradient(
        radialGradient,
        startCenter: glowCenter,
        startRadius: 0,
        endCenter: glowCenter,
        endRadius: glowRadius,
        options: []
    )

    let highlightRect = CGRect(x: insetRect.minX, y: insetRect.midY, width: insetRect.width, height: insetRect.height * 0.55)
    let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: radius, yRadius: radius)
    let highlightGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0.22),
        NSColor(calibratedWhite: 1, alpha: 0),
    ])!
    highlightGradient.draw(in: highlightPath, angle: 90)

    context.restoreGState()

    backgroundPath.lineWidth = size * 0.012
    NSColor(calibratedWhite: 1, alpha: 0.1).setStroke()
    backgroundPath.stroke()

    drawMoon(in: context, size: size)
    drawBolt(in: context, size: size)
    drawStars(size: size)

    image.unlockFocus()
    return image
}

func drawMoon(in context: CGContext, size: CGFloat) {
    let moonRect = CGRect(x: size * 0.22, y: size * 0.21, width: size * 0.48, height: size * 0.48)
    let cutoutRect = moonRect.offsetBy(dx: size * 0.13, dy: size * 0.02)

    let moonPath = NSBezierPath()
    moonPath.appendOval(in: moonRect)
    moonPath.appendOval(in: cutoutRect)
    moonPath.windingRule = .evenOdd

    context.saveGState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = size * 0.03
    shadow.shadowOffset = CGSize(width: 0, height: -size * 0.008)
    shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.18)
    shadow.set()

    let moonGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.98, green: 0.99, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.83, green: 0.90, blue: 0.86, alpha: 1),
    ])!
    moonGradient.draw(in: moonPath, angle: 90)
    context.restoreGState()
}

func drawBolt(in context: CGContext, size: CGFloat) {
    let boltPath = NSBezierPath()
    boltPath.move(to: CGPoint(x: size * 0.57, y: size * 0.83))
    boltPath.line(to: CGPoint(x: size * 0.43, y: size * 0.53))
    boltPath.line(to: CGPoint(x: size * 0.55, y: size * 0.53))
    boltPath.line(to: CGPoint(x: size * 0.45, y: size * 0.22))
    boltPath.line(to: CGPoint(x: size * 0.71, y: size * 0.54))
    boltPath.line(to: CGPoint(x: size * 0.57, y: size * 0.54))
    boltPath.close()

    context.saveGState()
    let glow = NSShadow()
    glow.shadowBlurRadius = size * 0.05
    glow.shadowOffset = .zero
    glow.shadowColor = NSColor(calibratedRed: 0.92, green: 1.0, blue: 0.4, alpha: 0.38)
    glow.set()

    let boltGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.36, alpha: 1),
        NSColor(calibratedRed: 0.63, green: 0.98, blue: 0.28, alpha: 1),
    ])!
    boltGradient.draw(in: boltPath, angle: 90)
    context.restoreGState()

    boltPath.lineWidth = size * 0.01
    NSColor(calibratedWhite: 1, alpha: 0.12).setStroke()
    boltPath.stroke()
}

func drawStars(size: CGFloat) {
    let starColor = NSColor(calibratedRed: 0.95, green: 0.99, blue: 0.87, alpha: 0.95)
    let stars: [(CGPoint, CGFloat)] = [
        (CGPoint(x: size * 0.28, y: size * 0.78), size * 0.032),
        (CGPoint(x: size * 0.73, y: size * 0.72), size * 0.024),
        (CGPoint(x: size * 0.26, y: size * 0.63), size * 0.018),
    ]

    for (center, radius) in stars {
        let path = NSBezierPath(ovalIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        starColor.setFill()
        path.fill()
    }
}

func writePNG(image: NSImage, to url: URL) throws {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw CocoaError(.fileWriteUnknown)
    }

    try pngData.write(to: url, options: .atomic)
}
