import AppKit
import SwiftUI

struct DragExportNotch: NSViewRepresentable {
    @ObservedObject var document: AnnotationDocument
    let skin: AppSkin

    func makeNSView(context: Context) -> DragExportNotchView {
        let view = DragExportNotchView()
        view.document = document
        view.skin = skin
        view.toolTip = "Drag to export PNG"
        return view
    }

    func updateNSView(_ nsView: DragExportNotchView, context: Context) {
        nsView.document = document
        nsView.skin = skin
        nsView.needsDisplay = true
    }
}

final class DragExportNotchView: NSView, NSDraggingSource {
    weak var document: AnnotationDocument?
    var skin: AppSkin = .classic

    private var trackingArea: NSTrackingArea?
    private var isHovering = false { didSet { needsDisplay = true } }
    private var isPressed = false { didSet { needsDisplay = true } }
    private var hasStartedDrag = false
    private var preparedDragFileURL: URL?

    override var intrinsicContentSize: NSSize {
        NSSize(width: 88, height: 28)
    }

    private var isEnabled: Bool {
        document?.backgroundImage != nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        isHovering = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        isPressed = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        guard !hasStartedDrag else { return }
        hasStartedDrag = false
        isPressed = true
        preparedDragFileURL = document?.writeExportPNGToTemporaryFile()
        hasStartedDrag = true
        let started = beginFileDrag(with: event)
        if !started {
            hasStartedDrag = false
            isPressed = false
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
    }

    override func mouseUp(with event: NSEvent) {
        hasStartedDrag = false
        isPressed = false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let notchRect = bounds.insetBy(dx: 1, dy: 1)
        let radius: CGFloat = 3
        let notchPath = NSBezierPath(roundedRect: notchRect, xRadius: radius, yRadius: radius)

        // Panel fill from skin
        let fillColor: NSColor
        if isPressed {
            fillColor = skin.notchPressed
        } else if isHovering {
            fillColor = skin.notchHover
        } else {
            fillColor = skin.notchResting
        }
        fillColor.setFill()
        notchPath.fill()

        // Outer border — near-black
        NSColor(white: 0.06, alpha: 1.0).setStroke()
        notchPath.lineWidth = 1
        notchPath.stroke()

        // Two-tone bevel from skin (inverted when pressed)
        let bevelHi  = isPressed ? skin.notchBevelShadow : skin.notchBevelHi
        let bevelShd = isPressed ? skin.notchBevelHi : skin.notchBevelShadow

        let topLine = NSBezierPath()
        topLine.move(to: NSPoint(x: notchRect.minX + radius, y: notchRect.maxY - 0.5))
        topLine.line(to: NSPoint(x: notchRect.maxX - radius, y: notchRect.maxY - 0.5))
        bevelHi.setStroke(); topLine.lineWidth = 1; topLine.stroke()

        let leftLine = NSBezierPath()
        leftLine.move(to: NSPoint(x: notchRect.minX + 0.5, y: notchRect.minY + radius))
        leftLine.line(to: NSPoint(x: notchRect.minX + 0.5, y: notchRect.maxY - radius))
        bevelHi.setStroke(); leftLine.lineWidth = 1; leftLine.stroke()

        let bottomLine = NSBezierPath()
        bottomLine.move(to: NSPoint(x: notchRect.minX + radius, y: notchRect.minY + 0.5))
        bottomLine.line(to: NSPoint(x: notchRect.maxX - radius, y: notchRect.minY + 0.5))
        bevelShd.setStroke(); bottomLine.lineWidth = 1; bottomLine.stroke()

        let rightLine = NSBezierPath()
        rightLine.move(to: NSPoint(x: notchRect.maxX - 0.5, y: notchRect.minY + radius))
        rightLine.line(to: NSPoint(x: notchRect.maxX - 0.5, y: notchRect.maxY - radius))
        bevelShd.setStroke(); rightLine.lineWidth = 1; rightLine.stroke()

        // Icon — accent color from skin
        let iconName = "square.and.arrow.up"
        let imageConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        if let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: "Export"),
           let configured = icon.withSymbolConfiguration(imageConfig) {
            let iconRect = NSRect(
                x: bounds.midX - 7,
                y: bounds.midY - 7,
                width: 14,
                height: 14
            )
            let iconColor = isEnabled
                ? skin.notchIcon.withAlphaComponent(isPressed ? 1.0 : 0.88)
                : skin.notchIconDisabled
            let paletteConfig = NSImage.SymbolConfiguration(paletteColors: [iconColor])
            let coloredIcon = configured.withSymbolConfiguration(paletteConfig) ?? configured
            coloredIcon.draw(in: iconRect)
        }
    }

    @discardableResult
    private func beginFileDrag(with event: NSEvent) -> Bool {
        guard let document else { return false }
        let tempURL = preparedDragFileURL ?? document.writeExportPNGToTemporaryFile()
        preparedDragFileURL = nil
        guard let tempURL else {
            NSSound.beep()
            return false
        }

        let item = NSDraggingItem(pasteboardWriter: tempURL as NSURL)
        let cursorPoint = convert(event.locationInWindow, from: nil)
        let dragPreview = dragPreviewImage(for: tempURL)
        let draggingFrame = NSRect(
            x: cursorPoint.x - dragPreview.size.width * 0.5,
            y: cursorPoint.y - dragPreview.size.height * 0.5,
            width: dragPreview.size.width,
            height: dragPreview.size.height
        )
        item.setDraggingFrame(draggingFrame, contents: dragPreview)

        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
        return true
    }

    private func dragPreviewImage(for fileURL: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        icon.size = NSSize(width: 48, height: 48)
        return icon
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        hasStartedDrag = false
        isPressed = false
        preparedDragFileURL = nil
        if !operation.contains(.copy) {
            DispatchQueue.main.async {
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
