import XCTest
@testable import NeuralCanvas

/// Unit tests for ExportService
@MainActor
final class ExportServiceTests: XCTestCase {

    var exportService: ExportService!

    override func setUp() async throws {
        try await super.setUp()
        exportService = ExportService()
    }

    override func tearDown() async throws {
        exportService = nil
        try await super.tearDown()
    }

    // MARK: - Format Tests

    func testExportFormatFileExtensions() {
        XCTAssertEqual(ExportFormat.svg.fileExtension, "svg")
        XCTAssertEqual(ExportFormat.pdf.fileExtension, "pdf")
        XCTAssertEqual(ExportFormat.png.fileExtension, "png")
        XCTAssertEqual(ExportFormat.jpeg.fileExtension, "jpeg")
    }

    func testExportFormatIsVector() {
        XCTAssertTrue(ExportFormat.svg.isVector)
        XCTAssertTrue(ExportFormat.pdf.isVector)
        XCTAssertFalse(ExportFormat.png.isVector)
        XCTAssertFalse(ExportFormat.jpeg.isVector)
    }

    // MARK: - Options Tests

    func testExportOptionsDefaults() {
        let svgOptions = ExportOptions.defaults(for: .svg)
        XCTAssertEqual(svgOptions.format, .svg)
        XCTAssertEqual(svgOptions.scale, 1.0)

        let pngOptions = ExportOptions.defaults(for: .png)
        XCTAssertEqual(pngOptions.format, .png)
        XCTAssertEqual(pngOptions.scale, 2.0)
    }

    // MARK: - Filename Validation Tests

    func testFilenameValidation() throws {
        // Valid names
        let validName = try exportService.validateFilename("MyWireframe")
        XCTAssertEqual(validName, "MyWireframe")

        let nameWithSpaces = try exportService.validateFilename("My Wireframe Design")
        XCTAssertEqual(nameWithSpaces, "My Wireframe Design")

        let nameWithHyphens = try exportService.validateFilename("my-wireframe-v1")
        XCTAssertEqual(nameWithHyphens, "my-wireframe-v1")
    }

    func testFilenameValidationRemovesPathTraversal() throws {
        let sanitized = try exportService.validateFilename("../../../etc/passwd")
        XCTAssertFalse(sanitized.contains(".."))
        XCTAssertFalse(sanitized.contains("/"))
    }

    func testFilenameValidationRemovesInvalidCharacters() throws {
        let sanitized = try exportService.validateFilename("my<file>name:test")
        XCTAssertFalse(sanitized.contains("<"))
        XCTAssertFalse(sanitized.contains(">"))
        XCTAssertFalse(sanitized.contains(":"))
    }

    func testFilenameValidationRejectsEmpty() {
        XCTAssertThrowsError(try exportService.validateFilename("")) { error in
            guard case ExportError.invalidFileName = error else {
                XCTFail("Expected invalidFileName error")
                return
            }
        }
    }

    func testFilenameValidationEnforcesMaxLength() throws {
        let longName = String(repeating: "a", count: 300)
        let sanitized = try exportService.validateFilename(longName)
        XCTAssertLessThanOrEqual(sanitized.count, 255)
    }

    // MARK: - SVG Export Tests

    func testSVGExportEmptyShapes() async throws {
        let shapes: [RecognizedShape] = []
        let canvasSize = CGSize(width: 800, height: 600)
        let options = ExportOptions(format: .svg)

        let data = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options)

        XCTAssertFalse(data.isEmpty)

        let svgString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(svgString)
        XCTAssertTrue(svgString?.contains("<svg") ?? false)
        XCTAssertTrue(svgString?.contains("</svg>") ?? false)
    }

    func testSVGExportWithShapes() async throws {
        let shapes = [
            RecognizedShape(type: .rectangle, bounds: CGRect(x: 10, y: 10, width: 100, height: 50), confidence: 0.9),
            RecognizedShape(type: .circle, bounds: CGRect(x: 150, y: 10, width: 50, height: 50), confidence: 0.85)
        ]
        let canvasSize = CGSize(width: 800, height: 600)
        let options = ExportOptions(format: .svg)

        let data = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options)

        let svgString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(svgString)
        XCTAssertTrue(svgString?.contains("<rect") ?? false)
        XCTAssertTrue(svgString?.contains("<circle") ?? false)
    }

    func testSVGExportWithBackground() async throws {
        let shapes = [RecognizedShape(type: .rectangle, bounds: CGRect(x: 10, y: 10, width: 100, height: 50), confidence: 0.9)]
        let canvasSize = CGSize(width: 800, height: 600)
        let options = ExportOptions(format: .svg, includeBackground: true)

        let data = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options)

        let svgString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(svgString)
        // Background should be a rect with white fill
        XCTAssertTrue(svgString?.contains("fill=\"white\"") ?? false)
    }

    // MARK: - PDF Export Tests

    func testPDFExportProducesValidPDF() async throws {
        let shapes = [RecognizedShape(type: .rectangle, bounds: CGRect(x: 10, y: 10, width: 100, height: 50), confidence: 0.9)]
        let canvasSize = CGSize(width: 800, height: 600)
        let options = ExportOptions(format: .pdf)

        let data = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options)

        XCTAssertFalse(data.isEmpty)
        // PDF files start with %PDF-
        let headerString = String(data: data.prefix(5), encoding: .ascii)
        XCTAssertEqual(headerString, "%PDF-")
    }

    // MARK: - PNG Export Tests

    func testPNGExportProducesValidPNG() async throws {
        let shapes = [RecognizedShape(type: .rectangle, bounds: CGRect(x: 10, y: 10, width: 100, height: 50), confidence: 0.9)]
        let canvasSize = CGSize(width: 800, height: 600)
        let options = ExportOptions(format: .png)

        let data = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options)

        XCTAssertFalse(data.isEmpty)
        // PNG files start with specific magic bytes
        let header = Array(data.prefix(8))
        XCTAssertEqual(header[0], 0x89)
        XCTAssertEqual(header[1], 0x50) // P
        XCTAssertEqual(header[2], 0x4E) // N
        XCTAssertEqual(header[3], 0x47) // G
    }

    func testPNGExportRespectScale() async throws {
        let shapes = [RecognizedShape(type: .rectangle, bounds: CGRect(x: 0, y: 0, width: 100, height: 100), confidence: 0.9)]
        let canvasSize = CGSize(width: 100, height: 100)

        let options1x = ExportOptions(format: .png, scale: 1.0)
        let data1x = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options1x)

        let options2x = ExportOptions(format: .png, scale: 2.0)
        let data2x = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options2x)

        // 2x scale should produce larger file (more pixels)
        XCTAssertGreaterThan(data2x.count, data1x.count)
    }

    // MARK: - JPEG Export Tests

    func testJPEGExportProducesValidJPEG() async throws {
        let shapes = [RecognizedShape(type: .rectangle, bounds: CGRect(x: 10, y: 10, width: 100, height: 50), confidence: 0.9)]
        let canvasSize = CGSize(width: 800, height: 600)
        let options = ExportOptions(format: .jpeg)

        let data = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options)

        XCTAssertFalse(data.isEmpty)
        // JPEG files start with FFD8
        XCTAssertEqual(data[0], 0xFF)
        XCTAssertEqual(data[1], 0xD8)
    }

    func testJPEGExportQualityAffectsSize() async throws {
        let shapes = [
            RecognizedShape(type: .rectangle, bounds: CGRect(x: 0, y: 0, width: 200, height: 200), confidence: 0.9),
            RecognizedShape(type: .circle, bounds: CGRect(x: 200, y: 0, width: 200, height: 200), confidence: 0.9)
        ]
        let canvasSize = CGSize(width: 400, height: 400)

        let lowQualityOptions = ExportOptions(format: .jpeg, jpegQuality: 0.3)
        let lowQualityData = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: lowQualityOptions)

        let highQualityOptions = ExportOptions(format: .jpeg, jpegQuality: 0.95)
        let highQualityData = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: highQualityOptions)

        // Higher quality generally means larger file
        XCTAssertGreaterThan(highQualityData.count, lowQualityData.count)
    }

    // MARK: - Shape Rendering Tests

    func testExportAllShapeTypes() async throws {
        let shapeTypes: [ShapeType] = [.rectangle, .roundedRectangle, .circle, .ellipse, .line, .arrow, .button, .inputField, .text, .image, .icon, .divider]

        for shapeType in shapeTypes {
            let shapes = [RecognizedShape(type: shapeType, bounds: CGRect(x: 10, y: 10, width: 100, height: 50), confidence: 0.9, label: "Test")]
            let options = ExportOptions(format: .svg)

            let data = try await exportService.export(shapes: shapes, canvasSize: CGSize(width: 200, height: 100), options: options)
            XCTAssertFalse(data.isEmpty, "Export failed for shape type: \(shapeType)")
        }
    }

    // MARK: - Crop to Content Tests

    func testExportCropToContent() async throws {
        let shapes = [
            RecognizedShape(type: .rectangle, bounds: CGRect(x: 100, y: 100, width: 50, height: 50), confidence: 0.9)
        ]
        let canvasSize = CGSize(width: 1000, height: 1000)

        let noCropOptions = ExportOptions(format: .svg, cropToContent: false)
        let noCropData = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: noCropOptions)
        let noCropSVG = String(data: noCropData, encoding: .utf8) ?? ""

        let cropOptions = ExportOptions(format: .svg, cropToContent: true, padding: 10)
        let cropData = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: cropOptions)
        let cropSVG = String(data: cropData, encoding: .utf8) ?? ""

        // Cropped SVG should have smaller viewBox
        XCTAssertTrue(noCropSVG.contains("1000"))  // Full canvas size
        XCTAssertFalse(cropSVG.contains("1000"))   // Cropped, shouldn't have 1000
    }
}
