import AppKit
import Foundation

let fileManager = FileManager.default
let iconsetPath = URL(fileURLWithPath: "Resources/AppIcon.iconset")
let brandDir = URL(fileURLWithPath: "Resources/Brand")
let svgMarkPath = brandDir.appendingPathComponent("QuickSnapMark.svg")
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

func drawIcon(size: CGFloat) throws -> NSImage {
    let source = NSImage(contentsOf: svgMarkPath)
    guard let baseImage = source else {
        throw NSError(domain: "icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load QuickSnapMark.svg"])
    }

    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    baseImage.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .sourceOver, fraction: 1.0)
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
    let image = try drawIcon(size: size)
    try writePNG(image, to: iconsetPath.appendingPathComponent(name))
}

print("Wrote iconset at \(iconsetPath.path)")
