import Foundation

public enum ShapeKind: String, Codable {
    case rectangle
    case arrow
}

public struct PersistedCaptureAnnotations: Codable, Hashable {
    public var strokes: [PersistedStroke] = []
    public var shapes: [PersistedShape] = []
    public var texts: [PersistedTextAnnotation] = []

    public init(
        strokes: [PersistedStroke] = [],
        shapes: [PersistedShape] = [],
        texts: [PersistedTextAnnotation] = []
    ) {
        self.strokes = strokes
        self.shapes = shapes
        self.texts = texts
    }

    public var isEmpty: Bool {
        strokes.isEmpty && shapes.isEmpty && texts.isEmpty
    }
}

public struct PersistedPoint: Codable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct PersistedStroke: Codable, Hashable {
    public var id: String
    public var points: [PersistedPoint]
    public var colorHex: String
    public var lineWidth: Double

    public init(id: String, points: [PersistedPoint], colorHex: String, lineWidth: Double) {
        self.id = id
        self.points = points
        self.colorHex = colorHex
        self.lineWidth = lineWidth
    }
}

public struct PersistedShape: Codable, Hashable {
    public var id: String
    public var kind: ShapeKind
    public var start: PersistedPoint
    public var end: PersistedPoint
    public var colorHex: String
    public var lineWidth: Double

    public init(
        id: String,
        kind: ShapeKind,
        start: PersistedPoint,
        end: PersistedPoint,
        colorHex: String,
        lineWidth: Double
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.colorHex = colorHex
        self.lineWidth = lineWidth
    }
}

public struct PersistedTextAnnotation: Codable, Hashable {
    public var id: String
    public var text: String
    public var position: PersistedPoint
    public var colorHex: String
    public var fontSize: Double

    public init(id: String, text: String, position: PersistedPoint, colorHex: String, fontSize: Double) {
        self.id = id
        self.text = text
        self.position = position
        self.colorHex = colorHex
        self.fontSize = fontSize
    }
}
