import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var document: AnnotationDocument
    @Binding var isDarkMode: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolBar
            Divider()

            ScrollView([.horizontal, .vertical]) {
                AnnotationCanvas(document: document)
                    .frame(width: document.canvasSize.width, height: document.canvasSize.height)
                    .background(Color.white)
                    .padding(20)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onDeleteCommand {
            document.deleteSelectedAnnotation()
        }
    }

    private var toolBar: some View {
        HStack(spacing: 10) {
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

            Divider()
                .frame(height: 20)

            ForEach(AnnotationTool.allCases) { tool in
                Button {
                    document.selectedTool = tool
                } label: {
                    Image(systemName: tool.symbolName)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .tint(document.selectedTool == tool ? .accentColor : nil)
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
            .frame(width: 30)
            .help("Annotation Color")

            Slider(value: $document.lineWidth, in: 1 ... 20)
                .frame(width: 110)
                .help("Line Width")

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

            iconButton(symbol: isDarkMode ? "sun.max" : "moon", helpText: "Toggle Dark Mode") {
                isDarkMode.toggle()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func iconButton(symbol: String, helpText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
        .help(helpText)
    }
}
