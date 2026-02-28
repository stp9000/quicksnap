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
                .fill(skin.separator)
                .frame(height: 1)

            ScrollView([.horizontal, .vertical]) {
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
            .background(skin.panelBg)

            Rectangle()
                .fill(skin.separator)
                .frame(height: 1)

            exportFooter
        }
        .background(skin.panelBg)
        .onDeleteCommand {
            document.deleteSelectedAnnotation()
        }
    }

    private var toolBar: some View {
        HStack(spacing: 8) {
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

            winAmpDivider()

            ForEach(AnnotationTool.allCases) { tool in
                Button {
                    document.selectedTool = tool
                } label: {
                    Image(systemName: tool.symbolName)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(WinAmpButtonStyle(skin: skin, isActive: document.selectedTool == tool))
                .help(tool.rawValue)
            }

            Button {
                colorPanel.onColorChange = { newColor in
                    document.color = newColor
                }
                colorPanel.present(initial: document.color)
            } label: {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(nsColor: document.color))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(skin.bevelShadow.opacity(0.8), lineWidth: 1)
                    )
                    .frame(width: 16, height: 16)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(WinAmpButtonStyle(skin: skin))
            .help("Annotation Color")

            WinAmpSlider(skin: skin, value: $document.lineWidth, range: 1.0...20.0)
                .frame(width: 110)
                .help("Line Width")

            winAmpDivider()

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

            winAmpDivider()

            skinPicker

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [skin.toolbarGradientTop, skin.panelBg],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var skinPicker: some View {
        Menu {
            ForEach(SkinManager.all) { s in
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
        } label: {
            Image(systemName: "arrow.right")
                .frame(width: 28, height: 28)
                .foregroundColor(skin.iconIdle)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .background(
            LinearGradient(
                colors: [skin.buttonGradTop, skin.buttonGradBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .allowsHitTesting(false)
        )
        .overlay(
            BevelBorder(hi: skin.bevelHi, shadow: skin.bevelShadow, cornerRadius: 3, pressed: false)
                .allowsHitTesting(false)
        )
        .help("Change Skin")
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

    private func iconButton(symbol: String, helpText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(WinAmpButtonStyle(skin: skin))
        .help(helpText)
    }

    private var exportFooter: some View {
        HStack(spacing: 12) {
            Text(document.defaultExportFilename)
                .font(skin.lcdFont(size: 10))
                .foregroundColor(skin.accentDim)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            DragExportNotch(document: document, skin: skin)
                .frame(width: 88, height: 28)
                .disabled(document.backgroundImage == nil)
                .opacity(document.backgroundImage == nil ? 0.55 : 1)

            Text(document.currentResolutionText)
                .font(skin.lcdFont(size: 10))
                .foregroundColor(skin.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(skin.panelBg)
        .overlay(
            Rectangle()
                .fill(skin.separator)
                .frame(height: 1),
            alignment: .top
        )
    }
}

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
