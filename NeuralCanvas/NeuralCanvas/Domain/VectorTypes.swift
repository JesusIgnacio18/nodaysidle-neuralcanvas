import Foundation
import CoreGraphics

// MARK: - Codable Color

/// A color representation that can be serialized to Data
struct CodableColor: Codable, Hashable, Sendable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Creates a CodableColor from a hex string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        if length == 6 {
            self.red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            self.green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            self.blue = CGFloat(rgb & 0x0000FF) / 255.0
            self.alpha = 1.0
        } else if length == 8 {
            self.red = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            self.green = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            self.blue = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            self.alpha = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
    }

    /// Returns the color as a hex string
    var hexString: String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // Common colors
    static let black = CodableColor(red: 0, green: 0, blue: 0)
    static let white = CodableColor(red: 1, green: 1, blue: 1)
    static let clear = CodableColor(red: 0, green: 0, blue: 0, alpha: 0)
    static let gray = CodableColor(red: 0.5, green: 0.5, blue: 0.5)
}

// MARK: - Codable Point

/// A CGPoint wrapper for Codable conformance
struct CodablePoint: Codable, Hashable, Sendable {
    let x: CGFloat
    let y: CGFloat

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Codable Rect

/// A CGRect wrapper for Codable conformance
struct CodableRect: Codable, Hashable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    static let zero = CodableRect(x: 0, y: 0, width: 0, height: 0)
}

// MARK: - Stroke Point

/// A single point in a stroke with optional pressure data
struct StrokePoint: Codable, Hashable, Sendable {
    let location: CodablePoint
    let pressure: CGFloat
    let timestamp: TimeInterval

    init(location: CGPoint, pressure: CGFloat = 1.0, timestamp: TimeInterval = 0) {
        self.location = CodablePoint(location)
        self.pressure = pressure
        self.timestamp = timestamp
    }
}

// MARK: - Vector Stroke

/// A single drawing stroke consisting of multiple points
struct VectorStroke: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let points: [StrokePoint]
    let width: CGFloat
    let color: CodableColor
    let createdAt: Date

    init(
        id: UUID = UUID(),
        points: [StrokePoint],
        width: CGFloat = 2.0,
        color: CodableColor = .black,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.points = points
        self.width = width
        self.color = color
        self.createdAt = createdAt
    }

    /// The bounding rectangle of this stroke
    var bounds: CGRect {
        guard !points.isEmpty else { return .zero }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for point in points {
            minX = min(minX, point.location.x)
            minY = min(minY, point.location.y)
            maxX = max(maxX, point.location.x)
            maxY = max(maxY, point.location.y)
        }

        // Add stroke width padding
        let padding = width / 2
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + width,
            height: maxY - minY + width
        )
    }

    /// Returns true if the stroke has enough points to be meaningful
    var isValid: Bool {
        points.count >= 2
    }
}

// MARK: - Shape Type

/// Types of UI shapes that can be recognized from sketches
enum ShapeType: String, Codable, CaseIterable, Sendable {
    case rectangle
    case roundedRectangle
    case circle
    case ellipse
    case line
    case arrow
    case text
    case button
    case inputField
    case card
    case image
    case icon
    case divider
    case container
    case unknown

    /// Display name for the shape type
    var displayName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .roundedRectangle: return "Rounded Rectangle"
        case .circle: return "Circle"
        case .ellipse: return "Ellipse"
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .text: return "Text"
        case .button: return "Button"
        case .inputField: return "Input Field"
        case .card: return "Card"
        case .image: return "Image"
        case .icon: return "Icon"
        case .divider: return "Divider"
        case .container: return "Container"
        case .unknown: return "Unknown"
        }
    }

    /// Whether this shape type typically contains text
    var containsText: Bool {
        switch self {
        case .text, .button, .inputField:
            return true
        default:
            return false
        }
    }
}

// MARK: - Recognized Shape

/// A shape recognized from a sketch with its properties
struct RecognizedShape: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let type: ShapeType
    let bounds: CodableRect
    let confidence: Double
    let rotation: CGFloat
    let cornerRadius: CGFloat?
    let label: String?

    init(
        id: UUID = UUID(),
        type: ShapeType,
        bounds: CGRect,
        confidence: Double,
        rotation: CGFloat = 0,
        cornerRadius: CGFloat? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.type = type
        self.bounds = CodableRect(bounds)
        self.confidence = confidence
        self.rotation = rotation
        self.cornerRadius = cornerRadius
        self.label = label
    }

    /// Whether this recognition has high enough confidence to be used
    var isHighConfidence: Bool {
        confidence >= 0.7
    }

    /// Whether this recognition has medium confidence
    var isMediumConfidence: Bool {
        confidence >= 0.4 && confidence < 0.7
    }
}

// MARK: - Recognized Sketch

/// The complete result of sketch recognition
struct RecognizedSketch: Codable, Sendable {
    let strokes: [VectorStroke]
    let shapes: [RecognizedShape]
    let processingTime: TimeInterval
    let modelVersion: String

    init(
        strokes: [VectorStroke],
        shapes: [RecognizedShape],
        processingTime: TimeInterval = 0,
        modelVersion: String = "1.0"
    ) {
        self.strokes = strokes
        self.shapes = shapes
        self.processingTime = processingTime
        self.modelVersion = modelVersion
    }

    /// The overall confidence of the recognition
    var averageConfidence: Double {
        guard !shapes.isEmpty else { return 0 }
        return shapes.map(\.confidence).reduce(0, +) / Double(shapes.count)
    }

    /// Returns shapes filtered by minimum confidence
    func shapes(minConfidence: Double) -> [RecognizedShape] {
        shapes.filter { $0.confidence >= minConfidence }
    }
}

// MARK: - Canvas Data

/// Container for all canvas drawing data
struct CanvasData: Codable, Sendable {
    let strokes: [VectorStroke]
    let recognizedShapes: [RecognizedShape]
    let canvasSize: CodableRect
    let version: Int

    init(
        strokes: [VectorStroke] = [],
        recognizedShapes: [RecognizedShape] = [],
        canvasSize: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
        version: Int = 1
    ) {
        self.strokes = strokes
        self.recognizedShapes = recognizedShapes
        self.canvasSize = CodableRect(canvasSize)
        self.version = version
    }

    /// Encodes the canvas data to a Data blob
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes canvas data from a Data blob
    static func decode(from data: Data) throws -> CanvasData {
        try JSONDecoder().decode(CanvasData.self, from: data)
    }

    /// Empty canvas data
    static let empty = CanvasData()
}
