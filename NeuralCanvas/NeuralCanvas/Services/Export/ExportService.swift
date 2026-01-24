import Foundation
import AppKit
import PDFKit
import UniformTypeIdentifiers

// MARK: - Export Format

/// Supported export formats
enum ExportFormat: String, CaseIterable, Identifiable {
    case svg = "SVG"
    case pdf = "PDF"
    case png = "PNG"
    case jpeg = "JPEG"

    var id: String { rawValue }

    var fileExtension: String {
        rawValue.lowercased()
    }

    var utType: UTType {
        switch self {
        case .svg: return .svg
        case .pdf: return .pdf
        case .png: return .png
        case .jpeg: return .jpeg
        }
    }

    var displayName: String {
        switch self {
        case .svg: return "Scalable Vector Graphics"
        case .pdf: return "PDF Document"
        case .png: return "PNG Image"
        case .jpeg: return "JPEG Image"
        }
    }

    var isVector: Bool {
        self == .svg || self == .pdf
    }
}

// MARK: - Export Options

/// Options for configuring export
struct ExportOptions {
    /// Export format
    var format: ExportFormat

    /// Export scale (1x, 2x, 3x) - for raster formats
    var scale: CGFloat

    /// JPEG quality (0.0 to 1.0) - only for JPEG
    var jpegQuality: CGFloat

    /// Whether to include background
    var includeBackground: Bool

    /// Whether to crop to content bounds
    var cropToContent: Bool

    /// Padding around content (in points)
    var padding: CGFloat

    /// Maximum dimension for raster exports (0 = unlimited)
    var maxDimension: CGFloat

    init(
        format: ExportFormat = .png,
        scale: CGFloat = 2.0,
        jpegQuality: CGFloat = 0.85,
        includeBackground: Bool = true,
        cropToContent: Bool = false,
        padding: CGFloat = 20,
        maxDimension: CGFloat = 0
    ) {
        self.format = format
        self.scale = scale
        self.jpegQuality = jpegQuality
        self.includeBackground = includeBackground
        self.cropToContent = cropToContent
        self.padding = padding
        self.maxDimension = maxDimension
    }

    /// Default options for each format
    static func defaults(for format: ExportFormat) -> ExportOptions {
        var options = ExportOptions(format: format)

        switch format {
        case .svg, .pdf:
            options.scale = 1.0 // Vector formats don't need scaling
        case .png:
            options.scale = 2.0 // Default to @2x
        case .jpeg:
            options.scale = 2.0
            options.jpegQuality = 0.85
        }

        return options
    }
}

// MARK: - Exporting Protocol

/// Protocol for export operations
/// Note: MainActor-isolated because SwiftData @Model classes aren't Sendable
@MainActor
protocol Exporting {
    /// Exports a wireframe to data
    func export(wireframe: Wireframe, options: ExportOptions) async throws -> Data

    /// Exports shapes directly to data
    func export(shapes: [RecognizedShape], canvasSize: CGSize, options: ExportOptions) async throws -> Data

    /// Validates a filename for export
    func validateFilename(_ filename: String) throws -> String
}

// MARK: - Export Service

/// Service for exporting wireframes to various formats
@MainActor
final class ExportService: Exporting {
    // MARK: - Initialization

    init() {
        AppLogger.export.debug("ExportService initialized")
    }

    // MARK: - Exporting Implementation

    func export(wireframe: Wireframe, options: ExportOptions) async throws -> Data {
        let shapes = try wireframe.getRecognizedShapes()
        let canvasSize = CGSize(width: 1920, height: 1080) // Default canvas size

        return try await export(shapes: shapes, canvasSize: canvasSize, options: options)
    }

    func export(shapes: [RecognizedShape], canvasSize: CGSize, options: ExportOptions) async throws -> Data {
        AppLogger.export.info("Exporting \(shapes.count) shapes as \(options.format.rawValue)")

        // Calculate bounds
        let contentBounds = options.cropToContent
            ? calculateContentBounds(shapes: shapes, padding: options.padding)
            : CGRect(origin: .zero, size: canvasSize)

        switch options.format {
        case .svg:
            return try exportToSVG(shapes: shapes, bounds: contentBounds, options: options)
        case .pdf:
            return try exportToPDF(shapes: shapes, bounds: contentBounds, options: options)
        case .png:
            return try exportToPNG(shapes: shapes, bounds: contentBounds, options: options)
        case .jpeg:
            return try exportToJPEG(shapes: shapes, bounds: contentBounds, options: options)
        }
    }

    func validateFilename(_ filename: String) throws -> String {
        var sanitized = filename

        // Remove path traversal sequences
        sanitized = sanitized.replacingOccurrences(of: "..", with: "")
        sanitized = sanitized.replacingOccurrences(of: "/", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "_")

        // Remove or replace invalid characters
        let invalidCharacters = CharacterSet(charactersIn: "<>:\"|?*\0")
        sanitized = sanitized.components(separatedBy: invalidCharacters).joined(separator: "_")

        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if empty
        guard !sanitized.isEmpty else {
            throw ExportError.invalidFileName(name: filename)
        }

        // Enforce max length (255 is typical filesystem limit)
        if sanitized.count > 255 {
            sanitized = String(sanitized.prefix(255))
        }

        return sanitized
    }

    // MARK: - Private Helpers

    private func calculateContentBounds(shapes: [RecognizedShape], padding: CGFloat) -> CGRect {
        guard !shapes.isEmpty else {
            return CGRect(x: 0, y: 0, width: 100, height: 100)
        }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for shape in shapes {
            let bounds = shape.bounds.cgRect
            minX = min(minX, bounds.minX)
            minY = min(minY, bounds.minY)
            maxX = max(maxX, bounds.maxX)
            maxY = max(maxY, bounds.maxY)
        }

        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + padding * 2,
            height: maxY - minY + padding * 2
        )
    }
}

// MARK: - SVG Export

extension ExportService {
    private func exportToSVG(shapes: [RecognizedShape], bounds: CGRect, options: ExportOptions) throws -> Data {
        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="\(bounds.origin.x) \(bounds.origin.y) \(bounds.width) \(bounds.height)" width="\(Int(bounds.width))" height="\(Int(bounds.height))">

        """

        // Add background if requested
        if options.includeBackground {
            svg += """
              <rect x="\(bounds.origin.x)" y="\(bounds.origin.y)" width="\(bounds.width)" height="\(bounds.height)" fill="white"/>

            """
        }

        // Add shapes
        for shape in shapes {
            svg += shapeToSVGElement(shape)
        }

        svg += "</svg>\n"

        guard let data = svg.data(using: .utf8) else {
            throw ExportError.renderingFailed(underlying: NSError(
                domain: "ExportService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode SVG as UTF-8"]
            ))
        }

        AppLogger.export.info("SVG export complete: \(data.count) bytes")
        return data
    }

    private func shapeToSVGElement(_ shape: RecognizedShape) -> String {
        let bounds = shape.bounds.cgRect
        let cornerRadius = shape.cornerRadius ?? 0

        var element: String

        switch shape.type {
        case .rectangle, .card, .container:
            if cornerRadius > 0 {
                element = """
                  <rect x="\(bounds.minX)" y="\(bounds.minY)" width="\(bounds.width)" height="\(bounds.height)" rx="\(cornerRadius)" fill="none" stroke="#333" stroke-width="2"/>

                """
            } else {
                element = """
                  <rect x="\(bounds.minX)" y="\(bounds.minY)" width="\(bounds.width)" height="\(bounds.height)" fill="none" stroke="#333" stroke-width="2"/>

                """
            }

        case .roundedRectangle:
            let rx = cornerRadius > 0 ? cornerRadius : min(bounds.width, bounds.height) * 0.1
            element = """
              <rect x="\(bounds.minX)" y="\(bounds.minY)" width="\(bounds.width)" height="\(bounds.height)" rx="\(rx)" fill="none" stroke="#333" stroke-width="2"/>

            """

        case .circle:
            let cx = bounds.midX
            let cy = bounds.midY
            let r = min(bounds.width, bounds.height) / 2
            element = """
              <circle cx="\(cx)" cy="\(cy)" r="\(r)" fill="none" stroke="#333" stroke-width="2"/>

            """

        case .ellipse:
            let cx = bounds.midX
            let cy = bounds.midY
            let rx = bounds.width / 2
            let ry = bounds.height / 2
            element = """
              <ellipse cx="\(cx)" cy="\(cy)" rx="\(rx)" ry="\(ry)" fill="none" stroke="#333" stroke-width="2"/>

            """

        case .line:
            element = """
              <line x1="\(bounds.minX)" y1="\(bounds.midY)" x2="\(bounds.maxX)" y2="\(bounds.midY)" stroke="#333" stroke-width="2"/>

            """

        case .arrow:
            let markerSize = min(bounds.width, bounds.height) * 0.2
            element = """
              <defs>
                <marker id="arrowhead-\(shape.id)" markerWidth="\(markerSize)" markerHeight="\(markerSize)" refX="0" refY="\(markerSize/2)" orient="auto">
                  <polygon points="0 0, \(markerSize) \(markerSize/2), 0 \(markerSize)" fill="#333"/>
                </marker>
              </defs>
              <line x1="\(bounds.minX)" y1="\(bounds.midY)" x2="\(bounds.maxX)" y2="\(bounds.midY)" stroke="#333" stroke-width="2" marker-end="url(#arrowhead-\(shape.id))"/>

            """

        case .button:
            let rx = cornerRadius > 0 ? cornerRadius : 8
            element = """
              <rect x="\(bounds.minX)" y="\(bounds.minY)" width="\(bounds.width)" height="\(bounds.height)" rx="\(rx)" fill="#007AFF" stroke="none"/>
              <text x="\(bounds.midX)" y="\(bounds.midY)" text-anchor="middle" dominant-baseline="central" fill="white" font-family="system-ui" font-size="14">\(shape.label ?? "Button")</text>

            """

        case .inputField:
            element = """
              <rect x="\(bounds.minX)" y="\(bounds.minY)" width="\(bounds.width)" height="\(bounds.height)" rx="4" fill="white" stroke="#ccc" stroke-width="1"/>
              <text x="\(bounds.minX + 8)" y="\(bounds.midY)" dominant-baseline="central" fill="#999" font-family="system-ui" font-size="14">\(shape.label ?? "Input")</text>

            """

        case .text:
            element = """
              <text x="\(bounds.minX)" y="\(bounds.maxY - 4)" fill="#333" font-family="system-ui" font-size="14">\(shape.label ?? "Text")</text>

            """

        case .image, .icon:
            element = """
              <rect x="\(bounds.minX)" y="\(bounds.minY)" width="\(bounds.width)" height="\(bounds.height)" fill="#f0f0f0" stroke="#ccc" stroke-width="1"/>
              <line x1="\(bounds.minX)" y1="\(bounds.minY)" x2="\(bounds.maxX)" y2="\(bounds.maxY)" stroke="#ccc" stroke-width="1"/>
              <line x1="\(bounds.maxX)" y1="\(bounds.minY)" x2="\(bounds.minX)" y2="\(bounds.maxY)" stroke="#ccc" stroke-width="1"/>

            """

        case .divider:
            element = """
              <line x1="\(bounds.minX)" y1="\(bounds.midY)" x2="\(bounds.maxX)" y2="\(bounds.midY)" stroke="#e0e0e0" stroke-width="1"/>

            """

        case .unknown:
            element = """
              <rect x="\(bounds.minX)" y="\(bounds.minY)" width="\(bounds.width)" height="\(bounds.height)" fill="none" stroke="#999" stroke-width="1" stroke-dasharray="4"/>

            """
        }

        return element
    }
}

// MARK: - PDF Export

extension ExportService {
    private func exportToPDF(shapes: [RecognizedShape], bounds: CGRect, options: ExportOptions) throws -> Data {
        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw ExportError.renderingFailed(underlying: NSError(
                domain: "ExportService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"]
            ))
        }

        var mediaBox = bounds
        context.beginPDFPage([kCGPDFContextMediaBox as String: NSValue(rect: mediaBox)] as CFDictionary)

        // Draw background
        if options.includeBackground {
            context.setFillColor(CGColor.white)
            context.fill(bounds)
        }

        // Draw shapes
        for shape in shapes {
            drawShapeInContext(shape, context: context)
        }

        context.endPDFPage()
        context.closePDF()

        AppLogger.export.info("PDF export complete: \(pdfData.length) bytes")
        return pdfData as Data
    }

    private func drawShapeInContext(_ shape: RecognizedShape, context: CGContext) {
        let bounds = shape.bounds.cgRect
        let cornerRadius = shape.cornerRadius ?? 0

        context.saveGState()

        // Set default stroke/fill
        context.setStrokeColor(CGColor(gray: 0.2, alpha: 1.0))
        context.setLineWidth(2.0)

        switch shape.type {
        case .rectangle, .card, .container:
            let path: CGPath
            if cornerRadius > 0 {
                path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            } else {
                path = CGPath(rect: bounds, transform: nil)
            }
            context.addPath(path)
            context.strokePath()

        case .roundedRectangle:
            let rx = cornerRadius > 0 ? cornerRadius : min(bounds.width, bounds.height) * 0.1
            let path = CGPath(roundedRect: bounds, cornerWidth: rx, cornerHeight: rx, transform: nil)
            context.addPath(path)
            context.strokePath()

        case .circle:
            context.strokeEllipse(in: bounds)

        case .ellipse:
            context.strokeEllipse(in: bounds)

        case .line, .divider:
            context.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
            context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
            context.strokePath()

        case .arrow:
            // Draw line
            context.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
            context.addLine(to: CGPoint(x: bounds.maxX - 10, y: bounds.midY))
            context.strokePath()

            // Draw arrowhead
            context.setFillColor(CGColor(gray: 0.2, alpha: 1.0))
            context.move(to: CGPoint(x: bounds.maxX, y: bounds.midY))
            context.addLine(to: CGPoint(x: bounds.maxX - 10, y: bounds.midY - 5))
            context.addLine(to: CGPoint(x: bounds.maxX - 10, y: bounds.midY + 5))
            context.closePath()
            context.fillPath()

        case .button:
            context.setFillColor(CGColor(red: 0, green: 0.478, blue: 1, alpha: 1))
            let rx = cornerRadius > 0 ? cornerRadius : 8
            let path = CGPath(roundedRect: bounds, cornerWidth: rx, cornerHeight: rx, transform: nil)
            context.addPath(path)
            context.fillPath()

        case .inputField:
            context.setFillColor(CGColor.white)
            context.setStrokeColor(CGColor(gray: 0.8, alpha: 1.0))
            context.setLineWidth(1.0)
            let path = CGPath(roundedRect: bounds, cornerWidth: 4, cornerHeight: 4, transform: nil)
            context.addPath(path)
            context.drawPath(using: .fillStroke)

        case .text:
            // Text rendering in CGContext is complex, just draw placeholder
            context.setFillColor(CGColor(gray: 0.2, alpha: 1.0))
            context.fill(CGRect(x: bounds.minX, y: bounds.midY - 7, width: bounds.width * 0.8, height: 14))

        case .image, .icon:
            context.setFillColor(CGColor(gray: 0.94, alpha: 1.0))
            context.fill(bounds)
            context.setStrokeColor(CGColor(gray: 0.8, alpha: 1.0))
            context.setLineWidth(1.0)
            context.stroke(bounds)
            // Draw X
            context.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            context.move(to: CGPoint(x: bounds.maxX, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
            context.strokePath()

        case .unknown:
            context.setLineDash(phase: 0, lengths: [4, 4])
            context.stroke(bounds)
        }

        context.restoreGState()
    }
}

// MARK: - PNG/JPEG Export

extension ExportService {
    private func exportToPNG(shapes: [RecognizedShape], bounds: CGRect, options: ExportOptions) throws -> Data {
        let image = try renderToImage(shapes: shapes, bounds: bounds, options: options)

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw ExportError.renderingFailed(underlying: NSError(
                domain: "ExportService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"]
            ))
        }

        AppLogger.export.info("PNG export complete: \(pngData.count) bytes")
        return pngData
    }

    private func exportToJPEG(shapes: [RecognizedShape], bounds: CGRect, options: ExportOptions) throws -> Data {
        let image = try renderToImage(shapes: shapes, bounds: bounds, options: options)

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(
                using: .jpeg,
                properties: [.compressionFactor: options.jpegQuality]
              ) else {
            throw ExportError.renderingFailed(underlying: NSError(
                domain: "ExportService",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode JPEG"]
            ))
        }

        AppLogger.export.info("JPEG export complete: \(jpegData.count) bytes")
        return jpegData
    }

    private func renderToImage(shapes: [RecognizedShape], bounds: CGRect, options: ExportOptions) throws -> NSImage {
        let scale = options.scale
        var targetSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        // Apply max dimension constraint
        if options.maxDimension > 0 {
            let maxSize = max(targetSize.width, targetSize.height)
            if maxSize > options.maxDimension {
                let factor = options.maxDimension / maxSize
                targetSize.width *= factor
                targetSize.height *= factor
            }
        }

        // Check for memory constraints (rough estimate: 4 bytes per pixel)
        let estimatedMemory = targetSize.width * targetSize.height * 4
        let memoryLimit: CGFloat = 500 * 1024 * 1024 // 500MB
        if estimatedMemory > memoryLimit {
            throw ExportError.insufficientMemory
        }

        let image = NSImage(size: targetSize)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            throw ExportError.renderingFailed(underlying: NSError(
                domain: "ExportService",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get graphics context"]
            ))
        }

        // Scale and translate
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)

        // Draw background
        if options.includeBackground {
            context.setFillColor(CGColor.white)
            context.fill(bounds)
        }

        // Draw shapes
        for shape in shapes {
            drawShapeInContext(shape, context: context)
        }

        image.unlockFocus()
        return image
    }
}
