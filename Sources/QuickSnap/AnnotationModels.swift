import AppKit
import Foundation
import SwiftUI

enum AnnotationTool: String, CaseIterable, Identifiable {
    case pen = "Pen"
    case rectangle = "Rectangle"
    case arrow = "Arrow"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .pen:
            return "pencil.tip"
        case .rectangle:
            return "rectangle"
        case .arrow:
            return "arrow.up.right"
        }
    }
}

struct Stroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: NSColor
    var lineWidth: CGFloat
}

enum ShapeKind {
    case rectangle
    case arrow
}

struct ShapeAnnotation: Identifiable {
    let id = UUID()
    var kind: ShapeKind
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
}

enum SelectedAnnotation: Equatable {
    case stroke(UUID)
    case shape(UUID)
}

@MainActor
final class AnnotationDocument: ObservableObject {
    @Published var backgroundImage: NSImage?
    @Published var showsSelectionBorder = false
    @Published var canvasSize = CGSize(width: 1280, height: 800)
    @Published var selectedTool: AnnotationTool = .pen
    @Published var selectedAnnotation: SelectedAnnotation?
    @Published var color: NSColor = .systemRed
    @Published var lineWidth: CGFloat = 4
    @Published var strokes: [Stroke] = []
    @Published var shapes: [ShapeAnnotation] = []
    private var annotationHistory: [SelectedAnnotation] = []
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    private let defaultExportDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures", isDirectory: true)
        .appendingPathComponent("QuickSnap", isDirectory: true)

    var defaultExportFilename: String {
        "\(makeTimestampedBaseName()).png"
    }

    var currentResolutionText: String {
        "\(Int(canvasSize.width)) x \(Int(canvasSize.height))"
    }

    func clearAnnotations() {
        strokes.removeAll()
        shapes.removeAll()
        selectedAnnotation = nil
        annotationHistory.removeAll()
    }

    func loadImage(_ image: NSImage, showsSelectionBorder: Bool = false) {
        backgroundImage = image
        self.showsSelectionBorder = showsSelectionBorder
        let size = image.size
        if size.width > 0, size.height > 0 {
            canvasSize = size
        }
        clearAnnotations()
    }

    func captureMainDisplay() {
        captureWhileAppHidden(showsSelectionBorder: false) {
            guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else { return nil }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }

    func captureSelectionFromScreen() {
        captureWhileAppHidden(showsSelectionBorder: true) {
            let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("quicksnap-selection-\(UUID().uuidString).png")

            defer { try? FileManager.default.removeItem(at: outputURL) }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-x", outputURL.path]

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }

            guard process.terminationStatus == 0 else { return nil }
            return NSImage(contentsOf: outputURL)
        }
    }

    func openImageFromDisk() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .bmp, .heic, .webP]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        loadImage(image, showsSelectionBorder: false)
    }

    func saveAnnotatedImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = defaultExportFilename

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let pngData = renderPNGDataForExport() else { return }

        do {
            try pngData.write(to: url)
        } catch {
            NSSound.beep()
        }
    }

    func renderPNGDataForExport() -> Data? {
        renderPNGData()
    }

    func writeExportPNGToTemporaryFile() -> URL? {
        guard let pngData = renderPNGDataForExport() else { return nil }
        let fileName = defaultExportFilename
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempURL = tempDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")

        do {
            try pngData.write(to: tempURL, options: .atomic)
            archiveExportPNGInBackground(pngData: pngData, fileName: fileName)
            return tempURL
        } catch {
            NSSound.beep()
            return nil
        }
    }

    func undoLastAnnotation() {
        guard let last = annotationHistory.popLast() else { return }
        switch last {
        case .stroke(let id):
            strokes.removeAll { $0.id == id }
        case .shape(let id):
            shapes.removeAll { $0.id == id }
        }
        selectedAnnotation = nil
    }

    func deleteSelectedAnnotation() {
        guard let selected = selectedAnnotation else { return }

        switch selected {
        case .stroke(let id):
            strokes.removeAll { $0.id == id }
            annotationHistory.removeAll { $0 == .stroke(id) }
        case .shape(let id):
            shapes.removeAll { $0.id == id }
            annotationHistory.removeAll { $0 == .shape(id) }
        }

        selectedAnnotation = nil
    }

    func selectAnnotation(at point: CGPoint) {
        if let stroke = strokes.last(where: { pointHitsStroke(point, stroke: $0) }) {
            selectedAnnotation = .stroke(stroke.id)
            return
        }

        if let shape = shapes.last(where: { pointHitsShape(point, shape: $0) }) {
            selectedAnnotation = .shape(shape.id)
            return
        }

        selectedAnnotation = nil
    }

    private func captureWhileAppHidden(showsSelectionBorder: Bool, _ work: @escaping () -> NSImage?) {
        let app = NSApplication.shared
        let wasActive = app.isActive
        app.hide(nil)

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.25) {
            let capturedImage = work()
            DispatchQueue.main.async {
                if let capturedImage {
                    self.loadImage(capturedImage, showsSelectionBorder: showsSelectionBorder)
                }
                app.unhide(nil)
                if wasActive {
                    app.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    private func renderPNGData() -> Data? {
        let outputImage = renderAnnotatedImage()
        guard let tiffData = outputImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        return pngData
    }

    private func renderAnnotatedImage() -> NSImage {
        let output = NSImage(size: canvasSize)
        output.lockFocus()

        NSColor.white.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()

        backgroundImage?.draw(in: NSRect(origin: .zero, size: canvasSize), from: .zero, operation: .sourceOver, fraction: 1)
        if showsSelectionBorder {
            drawSelectionBorder(in: NSRect(origin: .zero, size: canvasSize))
        }

        for stroke in strokes {
            drawStroke(stroke, highlighted: false)
        }

        for shape in shapes {
            drawShape(shape, highlighted: false)
        }

        output.unlockFocus()
        return output
    }

    private func drawStroke(_ stroke: Stroke, highlighted: Bool) {
        guard let first = stroke.points.first else { return }
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = stroke.lineWidth + (highlighted ? 2 : 0)
        path.move(to: renderPoint(first))
        for point in stroke.points.dropFirst() {
            path.line(to: renderPoint(point))
        }
        (highlighted ? NSColor.systemBlue : stroke.color).setStroke()
        path.stroke()
    }

    private func drawShape(_ shape: ShapeAnnotation, highlighted: Bool) {
        (highlighted ? NSColor.systemBlue : shape.color).setStroke()

        switch shape.kind {
        case .rectangle:
            let convertedStart = renderPoint(shape.start)
            let convertedEnd = renderPoint(shape.end)
            let rect = CGRect(
                x: min(convertedStart.x, convertedEnd.x),
                y: min(convertedStart.y, convertedEnd.y),
                width: abs(convertedEnd.x - convertedStart.x),
                height: abs(convertedEnd.y - convertedStart.y)
            )
            let path = NSBezierPath(rect: rect)
            path.lineWidth = shape.lineWidth + (highlighted ? 2 : 0)
            path.stroke()
        case .arrow:
            let start = renderPoint(shape.start)
            let end = renderPoint(shape.end)
            let path = NSBezierPath()
            path.lineWidth = shape.lineWidth + (highlighted ? 2 : 0)
            path.lineCapStyle = .round
            path.move(to: start)
            path.line(to: end)
            path.stroke()

            let angle = atan2(end.y - start.y, end.x - start.x)
            let headLength = max(10, shape.lineWidth * 4)
            let left = CGPoint(
                x: end.x - headLength * cos(angle - .pi / 6),
                y: end.y - headLength * sin(angle - .pi / 6)
            )
            let right = CGPoint(
                x: end.x - headLength * cos(angle + .pi / 6),
                y: end.y - headLength * sin(angle + .pi / 6)
            )
            let head = NSBezierPath()
            head.lineWidth = shape.lineWidth + (highlighted ? 2 : 0)
            head.lineCapStyle = .round
            head.move(to: end)
            head.line(to: left)
            head.move(to: end)
            head.line(to: right)
            head.stroke()
        }
    }

    private func pointHitsStroke(_ point: CGPoint, stroke: Stroke) -> Bool {
        guard stroke.points.count > 1 else { return false }
        let threshold = max(8, stroke.lineWidth + 4)
        for idx in 0..<(stroke.points.count - 1) {
            if distanceFromPoint(point, toSegmentStart: stroke.points[idx], end: stroke.points[idx + 1]) <= threshold {
                return true
            }
        }
        return false
    }

    private func pointHitsShape(_ point: CGPoint, shape: ShapeAnnotation) -> Bool {
        switch shape.kind {
        case .rectangle:
            let rect = CGRect(
                x: min(shape.start.x, shape.end.x),
                y: min(shape.start.y, shape.end.y),
                width: abs(shape.end.x - shape.start.x),
                height: abs(shape.end.y - shape.start.y)
            )
            let inset = max(6, shape.lineWidth + 3)
            let outer = rect.insetBy(dx: -inset, dy: -inset)
            let inner = rect.insetBy(dx: inset, dy: inset)
            return outer.contains(point) && !inner.contains(point)
        case .arrow:
            let shaftDistance = distanceFromPoint(point, toSegmentStart: shape.start, end: shape.end)
            return shaftDistance <= max(10, shape.lineWidth + 4)
        }
    }

    private func distanceFromPoint(_ point: CGPoint, toSegmentStart a: CGPoint, end b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: point.x - a.x, y: point.y - a.y)
        let abLenSquared = ab.x * ab.x + ab.y * ab.y
        if abLenSquared == 0 { return hypot(ap.x, ap.y) }

        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / abLenSquared))
        let projection = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
        return hypot(point.x - projection.x, point.y - projection.y)
    }

    private func renderPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: canvasSize.height - point.y)
    }

    private func drawSelectionBorder(in rect: NSRect) {
        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: 1.5, dy: 1.5))
        border.lineWidth = 3
        border.stroke()
    }

    private func makeTimestampedBaseName(now: Date = Date()) -> String {
        let formatter = Self.timestampFormatter
        formatter.timeZone = .autoupdatingCurrent
        return "QuickSnap-\(formatter.string(from: now))"
    }

    private func writeExportPNGToDefaultFolder(pngData: Data, fileName: String) -> URL? {
        let destinationURL = defaultExportDirectory.appendingPathComponent(fileName)
        do {
            try FileManager.default.createDirectory(at: defaultExportDirectory, withIntermediateDirectories: true)
            try pngData.write(to: destinationURL, options: .atomic)
            return destinationURL
        } catch {
            return nil
        }
    }

    private func archiveExportPNGInBackground(pngData: Data, fileName: String) {
        let destinationDirectory = defaultExportDirectory
        let archiveData = pngData
        DispatchQueue.global(qos: .utility).async {
            let destinationURL = destinationDirectory.appendingPathComponent(fileName)
            do {
                try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
                try archiveData.write(to: destinationURL, options: .atomic)
            } catch {
                return
            }
        }
    }

    func addStroke(points: [CGPoint]) {
        guard points.count > 1 else { return }
        let stroke = Stroke(points: points, color: color, lineWidth: lineWidth)
        strokes.append(stroke)
        annotationHistory.append(.stroke(stroke.id))
        selectedAnnotation = nil
    }

    func addShape(kind: ShapeKind, start: CGPoint, end: CGPoint) {
        let shape = ShapeAnnotation(kind: kind, start: start, end: end, color: color, lineWidth: lineWidth)
        shapes.append(shape)
        annotationHistory.append(.shape(shape.id))
        selectedAnnotation = nil
    }
}
