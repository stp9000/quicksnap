import AppKit
import Foundation

let fileManager = FileManager.default
let iconsetPath = URL(fileURLWithPath: "Resources/AppIcon.iconset")
let brandDir = URL(fileURLWithPath: "Resources/Brand")
let mark1024Path = brandDir.appendingPathComponent("QuickSnapMark_1024.png")
try? fileManager.removeItem(at: iconsetPath)
try fileManager.createDirectory(at: iconsetPath, withIntermediateDirectories: true)
try? fileManager.createDirectory(at: brandDir, withIntermediateDirectories: true)

let variants: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.saveGState()
    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    let inset = size * 0.06
    let bgRect = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = size * 0.24

    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
    bgPath.addClip()

    let startColor = NSColor(calibratedRed: 0.36, green: 0.19, blue: 0.98, alpha: 1) // #5C31FA
    let endColor = NSColor(calibratedRed: 0.00, green: 0.83, blue: 1.00, alpha: 1)   // #00D4FF
    let gradient = NSGradient(colors: [startColor, endColor])!
    gradient.draw(from: CGPoint(x: bgRect.minX, y: bgRect.maxY),
                  to: CGPoint(x: bgRect.maxX, y: bgRect.minY),
                  options: [])

    ctx.restoreGState()

    let glyphColor = NSColor(white: 1.0, alpha: 0.96)

    let cameraBodyRect = NSRect(
        x: size * 0.19,
        y: size * 0.30,
        width: size * 0.62,
        height: size * 0.40
    )
    let bodyRadius = size * 0.10

    let cameraTopRect = NSRect(
        x: cameraBodyRect.minX + size * 0.07,
        y: cameraBodyRect.maxY - size * 0.02,
        width: size * 0.22,
        height: size * 0.11
    )

    let lensRect = NSRect(
        x: size * 0.36,
        y: size * 0.37,
        width: size * 0.28,
        height: size * 0.28
    )

    let glyphPath = NSBezierPath()
    glyphPath.windingRule = .evenOdd
    glyphPath.append(NSBezierPath(roundedRect: cameraBodyRect, xRadius: bodyRadius, yRadius: bodyRadius))
    glyphPath.append(NSBezierPath(roundedRect: cameraTopRect, xRadius: size * 0.06, yRadius: size * 0.06))
    glyphPath.append(NSBezierPath(ovalIn: lensRect))

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0.0, alpha: 0.22)
    shadow.shadowBlurRadius = size * 0.05
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.01)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    glyphColor.setFill()
    glyphPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Lens rings for extra definition at small sizes.
    let ringOuter = NSBezierPath(ovalIn: lensRect.insetBy(dx: size * 0.012, dy: size * 0.012))
    ringOuter.lineWidth = max(1.5, size * 0.018)
    NSColor(white: 1.0, alpha: 0.85).setStroke()
    ringOuter.stroke()

    let ringInner = NSBezierPath(ovalIn: lensRect.insetBy(dx: size * 0.062, dy: size * 0.062))
    ringInner.lineWidth = max(1.0, size * 0.012)
    NSColor(calibratedRed: 0.78, green: 0.97, blue: 1.00, alpha: 0.70).setStroke()
    ringInner.stroke()

    // Spark "snap" indicator.
    let sparkCenter = CGPoint(x: size * 0.73, y: size * 0.74)
    let sparkRadius = size * 0.055
    let spark = NSBezierPath()
    spark.lineWidth = max(1.5, size * 0.018)
    spark.lineCapStyle = .round
    spark.move(to: CGPoint(x: sparkCenter.x - sparkRadius, y: sparkCenter.y))
    spark.line(to: CGPoint(x: sparkCenter.x + sparkRadius, y: sparkCenter.y))
    spark.move(to: CGPoint(x: sparkCenter.x, y: sparkCenter.y - sparkRadius))
    spark.line(to: CGPoint(x: sparkCenter.x, y: sparkCenter.y + sparkRadius))
    spark.move(to: CGPoint(x: sparkCenter.x - sparkRadius * 0.72, y: sparkCenter.y - sparkRadius * 0.72))
    spark.line(to: CGPoint(x: sparkCenter.x + sparkRadius * 0.72, y: sparkCenter.y + sparkRadius * 0.72))
    spark.move(to: CGPoint(x: sparkCenter.x - sparkRadius * 0.72, y: sparkCenter.y + sparkRadius * 0.72))
    spark.line(to: CGPoint(x: sparkCenter.x + sparkRadius * 0.72, y: sparkCenter.y - sparkRadius * 0.72))
    NSColor(white: 1.0, alpha: 0.92).setStroke()
    spark.stroke()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1)
    }
    try png.write(to: url)
}

for (name, size) in variants {
    let image = drawIcon(size: size)
    try writePNG(image, to: iconsetPath.appendingPathComponent(name))
}

try writePNG(drawIcon(size: 1024), to: mark1024Path)

print("Wrote iconset at \(iconsetPath.path)")
print("Wrote brand mark at \(mark1024Path.path)")
