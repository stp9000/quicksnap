import SwiftUI

struct AnnotationCanvas: View {
    @ObservedObject var document: AnnotationDocument

    @State private var activeStroke: [CGPoint] = []
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    var body: some View {
        Canvas { context, size in
            let canvasRect = CGRect(origin: .zero, size: size)

            if let image = document.backgroundImage {
                context.draw(Image(nsImage: image), in: canvasRect)
                if document.showsSelectionBorder {
                    context.stroke(
                        Path(canvasRect.insetBy(dx: 1.5, dy: 1.5)),
                        with: .color(.yellow),
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
                document.selectAnnotation(at: value.location)
            }
        )
        .gesture(drawingGesture)
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
                }
            }
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
}
