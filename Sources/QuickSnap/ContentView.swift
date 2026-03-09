import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var document: AnnotationDocument
    @EnvironmentObject var skinManager: SkinManager
    @StateObject private var colorPanel = ColorPanelCoordinator()

    private var skin: AppSkin { skinManager.current }

    var body: some View {
        VStack(spacing: 0) {
            toolBar

            Rectangle()
                .fill(skin.isModern ? skin.border : skin.separator)
                .frame(height: 1)

            ScrollView([.horizontal, .vertical]) {
                if skin.isModern {
                    modernCanvas
                } else {
                    winAmpCanvas
                }
            }
            .background(canvasBackground)

            Rectangle()
                .fill(skin.isModern ? skin.border : skin.separator)
                .frame(height: 1)

            exportFooter
        }
        .background(windowBackground)
        .background(WindowTransparencyHelper(isGlass: skin.isGlass))
        .onDeleteCommand {
            document.deleteSelectedAnnotation()
        }
    }

    @ViewBuilder
    private var windowBackground: some View {
        if skin.isGlass {
            Rectangle().fill(.ultraThinMaterial)
        } else {
            skin.panelBg
        }
    }

    @ViewBuilder
    private var canvasBackground: some View {
        if skin.isGlass {
            Color.clear
        } else {
            skin.panelBg
        }
    }

    // MARK: - Canvas Variants

    private var modernCanvas: some View {
        AnnotationCanvas(document: document)
            .frame(width: document.canvasSize.width, height: document.canvasSize.height)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(skin.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 4)
            .padding(24)
    }

    private var winAmpCanvas: some View {
        AnnotationCanvas(document: document)
            .frame(width: document.canvasSize.width, height: document.canvasSize.height)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [skin.canvasFrameStart, skin.canvasFrameEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: Color.black.opacity(0.7), radius: 8, x: 0, y: 2)
            .padding(20)
    }

    // MARK: - Toolbar

    private var toolBar: some View {
        HStack(spacing: skin.isModern ? 10 : 8) {
            Spacer(minLength: 0)

            iconButton(symbol: "folder", helpText: "Open Image") {
                document.openImageFromDisk()
            }

            iconButton(symbol: "camera", helpText: "Capture Full Screen") {
                document.captureMainDisplay()
            }

            iconButton(symbol: "selection.pin.in.out", helpText: "Capture Selection") {
                document.captureSelectionFromScreen()
            }

            iconButton(symbol: "square.and.arrow.down", helpText: "Export PNG") {
                document.saveAnnotatedImage()
            }

            themeDivider()

            ForEach(AnnotationTool.allCases) { tool in
                Button {
                    document.selectedTool = tool
                } label: {
                    Image(systemName: tool.symbolName)
                        .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
                }
                .buttonStyle(currentButtonStyle(isActive: document.selectedTool == tool))
                .help(tool.rawValue)
            }

            colorPickerButton

            if skin.isModern {
                ModernSlider(skin: skin, value: $document.lineWidth, range: 1.0...20.0)
                    .frame(width: 110)
                    .help("Line Width")
            } else {
                WinAmpSlider(skin: skin, value: $document.lineWidth, range: 1.0...20.0)
                    .frame(width: 110)
                    .help("Line Width")
            }

            themeDivider()

            iconButton(symbol: "arrow.uturn.backward", helpText: "Undo Last Annotation") {
                document.undoLastAnnotation()
            }
            .disabled(document.strokes.isEmpty && document.shapes.isEmpty)

            iconButton(symbol: "trash", helpText: "Delete Selected Annotation") {
                document.deleteSelectedAnnotation()
            }
            .disabled(document.selectedAnnotation == nil)

            iconButton(symbol: "trash.slash", helpText: "Clear All Annotations") {
                document.clearAnnotations()
            }

            themeDivider()

            skinPicker

            Spacer(minLength: 0)
        }
        .padding(.horizontal, skin.isModern ? 16 : 10)
        .padding(.vertical, skin.isModern ? 12 : 8)
        .background(toolbarBackground)
    }

    // MARK: - Toolbar Background

    @ViewBuilder
    private var toolbarBackground: some View {
        if skin.isGlass {
            Rectangle().fill(.ultraThinMaterial)
        } else if skin.isModern {
            skin.surface
        } else {
            LinearGradient(
                colors: [skin.toolbarGradientTop, skin.panelBg],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var footerBackground: some View {
        if skin.isGlass {
            Rectangle().fill(.ultraThinMaterial)
        } else if skin.isModern {
            skin.surface
        } else {
            skin.panelBg
        }
    }

    // MARK: - Skin Picker

    private var skinPicker: some View {
        Menu {
            Section("Modern") {
                ForEach(SkinManager.all.filter { $0.isModern }) { s in
                    Button {
                        skinManager.select(s)
                    } label: {
                        if skin.id == s.id {
                            Label(s.name, systemImage: "checkmark")
                        } else {
                            Text(s.name)
                        }
                    }
                }
            }
            Section("Classic") {
                ForEach(SkinManager.all.filter { !$0.isModern }) { s in
                    Button {
                        skinManager.select(s)
                    } label: {
                        if skin.id == s.id {
                            Label(s.name, systemImage: "checkmark")
                        } else {
                            Text(s.name)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "paintpalette")
                .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
                .foregroundColor(skin.iconIdle)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
        .background(skinPickerBackground)
        .overlay(skinPickerOverlay)
        .help("Change Theme")
    }

    @ViewBuilder
    private var skinPickerBackground: some View {
        if skin.isModern {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(skin.buttonFace)
                .allowsHitTesting(false)
        } else {
            LinearGradient(
                colors: [skin.buttonGradTop, skin.buttonGradBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var skinPickerOverlay: some View {
        if !skin.isModern {
            BevelBorder(hi: skin.bevelHi, shadow: skin.bevelShadow, cornerRadius: 3, pressed: false)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Dividers

    private func themeDivider() -> some View {
        Group {
            if skin.isModern {
                modernDivider()
            } else {
                winAmpDivider()
            }
        }
    }

    private func modernDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 3)
    }

    private func winAmpDivider() -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(skin.separator)
                .frame(width: 1, height: 22)
            Rectangle()
                .fill(skin.bevelHi.opacity(0.3))
                .frame(width: 1, height: 22)
                .offset(x: 1)
        }
    }

    // MARK: - Helpers

    private func currentButtonStyle(isActive: Bool = false) -> AnyButtonStyle {
        if skin.isModern {
            return AnyButtonStyle(ModernButtonStyle(skin: skin, isActive: isActive))
        } else {
            return AnyButtonStyle(WinAmpButtonStyle(skin: skin, isActive: isActive))
        }
    }

    private func iconButton(symbol: String, helpText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
        }
        .buttonStyle(currentButtonStyle())
        .help(helpText)
    }

    // MARK: - Color Picker

    private var colorPickerButton: some View {
        Button {
            colorPanel.onColorChange = { newColor in
                document.color = newColor
            }
            colorPanel.present(initial: document.color)
        } label: {
            RoundedRectangle(cornerRadius: skin.isModern ? 4 : 2, style: .continuous)
                .fill(Color(nsColor: document.color))
                .overlay(
                    RoundedRectangle(cornerRadius: skin.isModern ? 4 : 2, style: .continuous)
                        .strokeBorder(
                            skin.isModern ? skin.border : skin.bevelShadow.opacity(0.8),
                            lineWidth: 1
                        )
                )
                .frame(width: skin.isModern ? 18 : 16, height: skin.isModern ? 18 : 16)
                .frame(width: skin.isModern ? 32 : 28, height: skin.isModern ? 32 : 28)
        }
        .buttonStyle(currentButtonStyle())
        .help("Annotation Color")
    }

    // MARK: - Footer

    private var exportFooter: some View {
        HStack(spacing: 12) {
            Text(document.defaultExportFilename)
                .font(skin.isModern ? skin.primaryFont(size: 11) : skin.lcdFont(size: 10))
                .foregroundColor(skin.accentDim)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            DragExportNotch(document: document, skin: skin)
                .frame(width: 88, height: 28)
                .disabled(document.backgroundImage == nil)
                .opacity(document.backgroundImage == nil ? 0.55 : 1)

            Text(document.currentResolutionText)
                .font(skin.isModern ? skin.monoFont(size: 11) : skin.lcdFont(size: 10))
                .foregroundColor(skin.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, skin.isModern ? 16 : 12)
        .frame(height: skin.isModern ? 36 : 34)
        .background(footerBackground)
        .overlay(
            Rectangle()
                .fill(skin.isModern ? skin.border : skin.separator)
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - AnyButtonStyle (type-erased wrapper)

struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - ColorPanelCoordinator

final class ColorPanelCoordinator: NSObject, ObservableObject {
    var onColorChange: ((NSColor) -> Void)?

    func present(initial: NSColor) {
        let panel = NSColorPanel.shared
        panel.color = initial
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        onColorChange?(sender.color)
    }
}

// MARK: - WindowTransparencyHelper

struct WindowTransparencyHelper: NSViewRepresentable {
    let isGlass: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.alphaValue = 0
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if isGlass {
                window.isOpaque = false
                window.backgroundColor = .clear
            } else {
                window.isOpaque = true
                window.backgroundColor = .windowBackgroundColor
            }
        }
    }
}
