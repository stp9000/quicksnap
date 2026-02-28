import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var document: AnnotationDocument

    var body: some View {
        VStack(spacing: 0) {
            toolBar

            Rectangle()
                .fill(WinAmp.separator)
                .frame(height: 1)

            ScrollView([.horizontal, .vertical]) {
                AnnotationCanvas(document: document)
                    .frame(width: document.canvasSize.width, height: document.canvasSize.height)
                    .background(Color.white)
                    .overlay(
                        Rectangle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [WinAmp.bevelDark, Color(hex: "#333333")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.7), radius: 8, x: 0, y: 2)
                    .padding(20)
            }
            .background(WinAmp.panelBackground)

            Rectangle()
                .fill(WinAmp.separator)
                .frame(height: 1)

            exportFooter
        }
        .background(WinAmp.panelBackground)
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
                .buttonStyle(WinAmpButtonStyle(isActive: document.selectedTool == tool))
                .help(tool.rawValue)
            }

            ColorPicker(
                "",
                selection: Binding(
                    get: { Color(nsColor: document.color) },
                    set: { document.color = NSColor($0) }
                )
            )
            .labelsHidden()
            .frame(width: 30, height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(WinAmp.accentGreen.opacity(0.6), lineWidth: 1)
            )
            .help("Annotation Color")

            WinAmpSlider(value: $document.lineWidth, range: 1.0...20.0)
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color(hex: "#282828"), WinAmp.panelBackground],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func winAmpDivider() -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(WinAmp.separator)
                .frame(width: 1, height: 22)
            Rectangle()
                .fill(WinAmp.bevelLight.opacity(0.3))
                .frame(width: 1, height: 22)
                .offset(x: 1)
        }
    }

    private func iconButton(symbol: String, helpText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(WinAmpButtonStyle())
        .help(helpText)
    }

    private var exportFooter: some View {
        HStack(spacing: 12) {
            Text(document.defaultExportFilename)
                .font(WinAmp.lcdFont(size: 10))
                .foregroundColor(WinAmp.dimGreen)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            DragExportNotch(document: document)
                .frame(width: 88, height: 28)
                .disabled(document.backgroundImage == nil)
                .opacity(document.backgroundImage == nil ? 0.55 : 1)

            Text(document.currentResolutionText)
                .font(WinAmp.lcdFont(size: 10))
                .foregroundColor(WinAmp.accentGreen)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(WinAmp.panelBackground)
        .overlay(
            Rectangle()
                .fill(WinAmp.separator)
                .frame(height: 1),
            alignment: .top
        )
    }
}
