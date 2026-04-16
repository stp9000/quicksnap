import SwiftUI

struct AnnotationCanvas: View {
    @ObservedObject var document: AnnotationDocument

    @State private var activeStroke: [CGPoint] = []
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var textPlacementPoint: CGPoint?
    @State private var textDraft = ""
    @State private var draggingTextID: UUID?
    @State private var draggingTextOffset: CGSize = .zero
    @State private var editingTextID: UUID?
    @State private var textPressCandidateID: UUID?
    @State private var textPressStartTime: Date?
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                let canvasRect = CGRect(origin: .zero, size: size)

                if let image = document.backgroundImage {
                    context.draw(Image(nsImage: image), in: canvasRect)
                    if document.showsSelectionBorder {
                        context.stroke(
                            Path(canvasRect.insetBy(dx: 1.5, dy: 1.5)),
                            with: .color(Color(nsColor: .separatorColor)),
                            lineWidth: 3
                        )
                    }
                } else {
                    context.fill(Path(canvasRect), with: .color(.white))
                }

                for stroke in document.strokes {
                    draw(stroke: stroke, in: &context)
                }

                if activeStroke.count > 1 {
                    var path = Path()
                    path.move(to: activeStroke[0])
                    for point in activeStroke.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(path, with: .color(Color(nsColor: document.color)), style: StrokeStyle(lineWidth: document.lineWidth, lineCap: .round, lineJoin: .round))
                }

                for shape in document.shapes {
                    draw(shape: shape, in: &context)
                }

                for text in document.textAnnotations {
                    draw(text: text, in: &context)
                }

                if let start = dragStart, let end = dragCurrent,
                   document.selectedTool == .rectangle || document.selectedTool == .arrow {
                    let preview = ShapeAnnotation(
                        kind: document.selectedTool == .rectangle ? .rectangle : .arrow,
                        start: start,
                        end: end,
                        color: document.color,
                        lineWidth: document.lineWidth
                    )
                    draw(shape: preview, in: &context, forceHighlight: false)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                SpatialTapGesture().onEnded { value in
                    if commitTextPlacementIfNeeded() {
                        return
                    }
                    if document.selectedTool == .text {
                        if let text = document.textAnnotations.last(where: { documentTextContains(point: value.location, text: $0) }) {
                            document.selectedAnnotation = .text(text.id)
                            beginEditingText(text)
                        } else {
                            beginTextPlacement(at: value.location)
                        }
                    } else {
                        cancelTextPlacement()
                        document.selectAnnotation(at: value.location)
                    }
                }
            )
            .gesture(drawingGesture)

            if let editorPoint = activeEditorPoint {
                TextField("", text: $textDraft, prompt: Text("Type"))
                    .textFieldStyle(.plain)
                    .font(.system(size: max(14, document.lineWidth * 5), weight: .semibold))
                    .foregroundColor(Color(nsColor: document.color))
                    .focused($isTextEditorFocused)
                    .frame(minWidth: 80, idealWidth: 180, maxWidth: 260, alignment: .leading)
                    .position(x: editorPoint.x + 90, y: editorPoint.y + 12)
                    .onSubmit {
                        commitTextPlacement()
                    }
                    .onExitCommand {
                        commitTextPlacementIfNeeded()
                    }
                    .onChange(of: isTextEditorFocused) { focused in
                        if !focused {
                            commitTextPlacementIfNeeded()
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            isTextEditorFocused = true
                        }
                    }
                    .zIndex(1)
            }
        }
        .onChange(of: document.selectedTool) { tool in
            if tool != .text {
                cancelTextPlacement()
            }
        }
    }

    private var activeEditorPoint: CGPoint? {
        editingTextID != nil ? textPlacementPoint : textPlacementPoint
    }

    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                switch document.selectedTool {
                case .pen:
                    activeStroke.append(value.location)
                case .rectangle, .arrow:
                    if dragStart == nil {
                        dragStart = value.startLocation
                    }
                    dragCurrent = value.location
                case .text:
                    guard editingTextID == nil else { return }
                    if draggingTextID == nil {
                        if textPressCandidateID == nil,
                           let annotation = document.textAnnotations.last(where: { documentTextContains(point: value.startLocation, text: $0) }) {
                            textPressCandidateID = annotation.id
                            textPressStartTime = Date()
                            document.selectedAnnotation = .text(annotation.id)
                            draggingTextOffset = CGSize(
                                width: value.startLocation.x - annotation.position.x,
                                height: value.startLocation.y - annotation.position.y
                            )
                        }
                        if let candidateID = textPressCandidateID,
                           let startTime = textPressStartTime,
                           Date().timeIntervalSince(startTime) >= 0.35 {
                            draggingTextID = candidateID
                            textPressCandidateID = nil
                            textPressStartTime = nil
                        }
                    }
                    if draggingTextID != nil {
                        let newPosition = CGPoint(
                            x: value.location.x - draggingTextOffset.width,
                            y: value.location.y - draggingTextOffset.height
                        )
                        document.moveSelectedTextAnnotation(to: newPosition)
                    }
                }
            }
            .onEnded { value in
                switch document.selectedTool {
                case .pen:
                    document.addStroke(points: activeStroke)
                    activeStroke.removeAll(keepingCapacity: true)
                case .rectangle, .arrow:
                    if let start = dragStart {
                        let kind: ShapeKind = (document.selectedTool == .rectangle) ? .rectangle : .arrow
                        document.addShape(kind: kind, start: start, end: value.location)
                    }
                    dragStart = nil
                    dragCurrent = nil
                case .text:
                    if let _ = draggingTextID {
                        let newPosition = CGPoint(
                            x: value.location.x - draggingTextOffset.width,
                            y: value.location.y - draggingTextOffset.height
                        )
                        document.moveSelectedTextAnnotation(to: newPosition)
                    }
                    draggingTextID = nil
                    draggingTextOffset = .zero
                    textPressCandidateID = nil
                    textPressStartTime = nil
                }
            }
    }

    private var selectedTextID: UUID? {
        if case .text(let id) = document.selectedAnnotation {
            return id
        }
        return nil
    }

    private func draw(stroke: Stroke, in context: inout GraphicsContext) {
        guard let first = stroke.points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in stroke.points.dropFirst() {
            path.addLine(to: point)
        }

        let isHighlighted: Bool
        if case .stroke(let id) = document.selectedAnnotation {
            isHighlighted = id == stroke.id
        } else {
            isHighlighted = false
        }

        context.stroke(
            path,
            with: .color(isHighlighted ? .blue : Color(nsColor: stroke.color)),
            style: StrokeStyle(lineWidth: stroke.lineWidth + (isHighlighted ? 2 : 0), lineCap: .round, lineJoin: .round)
        )
    }

    private func draw(shape: ShapeAnnotation, in context: inout GraphicsContext, forceHighlight: Bool? = nil) {
        let isHighlighted: Bool
        if let forced = forceHighlight {
            isHighlighted = forced
        } else if case .shape(let id) = document.selectedAnnotation {
            isHighlighted = (id == shape.id)
        } else {
            isHighlighted = false
        }

        let strokeColor = isHighlighted ? Color.blue : Color(nsColor: shape.color)
        let strokeWidth = shape.lineWidth + (isHighlighted ? 2 : 0)

        switch shape.kind {
        case .rectangle:
            let rect = CGRect(
                x: min(shape.start.x, shape.end.x),
                y: min(shape.start.y, shape.end.y),
                width: abs(shape.end.x - shape.start.x),
                height: abs(shape.end.y - shape.start.y)
            )
            let path = Path(rect)
            context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: strokeWidth))
        case .arrow:
            var path = Path()
            path.move(to: shape.start)
            path.addLine(to: shape.end)

            let angle = atan2(shape.end.y - shape.start.y, shape.end.x - shape.start.x)
            let headLength = max(10, shape.lineWidth * 4)
            let left = CGPoint(
                x: shape.end.x - headLength * cos(angle - .pi / 6),
                y: shape.end.y - headLength * sin(angle - .pi / 6)
            )
            let right = CGPoint(
                x: shape.end.x - headLength * cos(angle + .pi / 6),
                y: shape.end.y - headLength * sin(angle + .pi / 6)
            )
            path.move(to: shape.end)
            path.addLine(to: left)
            path.move(to: shape.end)
            path.addLine(to: right)

            context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
        }
    }

    private func draw(text: TextAnnotation, in context: inout GraphicsContext) {
        var resolved = context.resolve(
            Text(text.text)
            .font(.system(size: text.fontSize, weight: .semibold))
        )
        resolved.shading = .color(Color(nsColor: text.color))
        context.draw(resolved, at: text.position, anchor: .topLeading)
    }

    private func beginTextPlacement(at point: CGPoint) {
        editingTextID = nil
        textPlacementPoint = point
        textDraft = ""
        isTextEditorFocused = true
        draggingTextID = nil
        textPressCandidateID = nil
        textPressStartTime = nil
    }

    private func commitTextPlacement() {
        guard let textPlacementPoint else { return }
        if editingTextID != nil {
            document.updateSelectedTextAnnotation(textDraft)
        } else {
            document.addTextAnnotation(textDraft, at: textPlacementPoint)
        }
        cancelTextPlacement()
    }

    @discardableResult
    private func commitTextPlacementIfNeeded() -> Bool {
        guard textPlacementPoint != nil else { return false }
        if textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cancelTextPlacement()
        } else {
            commitTextPlacement()
        }
        return true
    }

    private func cancelTextPlacement() {
        textPlacementPoint = nil
        textDraft = ""
        isTextEditorFocused = false
        draggingTextID = nil
        draggingTextOffset = .zero
        editingTextID = nil
        textPressCandidateID = nil
        textPressStartTime = nil
    }

    private func beginEditingText(_ text: TextAnnotation) {
        editingTextID = text.id
        textPlacementPoint = text.position
        textDraft = text.text
        draggingTextID = nil
        draggingTextOffset = .zero
        DispatchQueue.main.async {
            isTextEditorFocused = true
        }
    }

    private func documentTextContains(point: CGPoint, text: TextAnnotation) -> Bool {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: text.fontSize, weight: .semibold)
        ]
        let size = NSString(string: text.text).size(withAttributes: attributes)
        let rect = CGRect(x: text.position.x, y: text.position.y, width: size.width, height: size.height)
            .insetBy(dx: -8, dy: -6)
        return rect.contains(point)
    }
}
