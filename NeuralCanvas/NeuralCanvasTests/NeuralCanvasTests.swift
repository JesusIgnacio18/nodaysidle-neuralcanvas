import XCTest
@testable import NeuralCanvas

final class NeuralCanvasTests: XCTestCase {

    // MARK: - VectorTypes Tests

    func testCodableColorInitialization() {
        let color = CodableColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 0.8)
        XCTAssertEqual(color.red, 1.0)
        XCTAssertEqual(color.green, 0.5)
        XCTAssertEqual(color.blue, 0.25)
        XCTAssertEqual(color.alpha, 0.8)
    }

    func testCodableColorHexInitialization() {
        let color = CodableColor(hex: "#FF5733")
        XCTAssertNotNil(color)
        XCTAssertEqual(Double(color?.red ?? 0), 1.0, accuracy: 0.01)
        XCTAssertEqual(Double(color?.green ?? 0), 0.341, accuracy: 0.01)
        XCTAssertEqual(Double(color?.blue ?? 0), 0.2, accuracy: 0.01)
    }

    func testCodableColorHexString() {
        let color = CodableColor(red: 1.0, green: 0.0, blue: 0.0)
        XCTAssertEqual(color.hexString, "#FF0000")
    }

    func testVectorStrokeBounds() {
        let points = [
            StrokePoint(location: CGPoint(x: 10, y: 10)),
            StrokePoint(location: CGPoint(x: 50, y: 50)),
            StrokePoint(location: CGPoint(x: 30, y: 80))
        ]
        let stroke = VectorStroke(points: points, width: 4.0)
        let bounds = stroke.bounds

        XCTAssertEqual(bounds.minX, 8, accuracy: 0.01) // 10 - 2 (half width)
        XCTAssertEqual(bounds.minY, 8, accuracy: 0.01)
        XCTAssertEqual(bounds.maxX, 52, accuracy: 0.01) // 50 + 2
        XCTAssertEqual(bounds.maxY, 82, accuracy: 0.01) // 80 + 2
    }

    func testVectorStrokeValidity() {
        let singlePoint = VectorStroke(points: [StrokePoint(location: CGPoint(x: 0, y: 0))])
        XCTAssertFalse(singlePoint.isValid)

        let twoPoints = VectorStroke(points: [
            StrokePoint(location: CGPoint(x: 0, y: 0)),
            StrokePoint(location: CGPoint(x: 10, y: 10))
        ])
        XCTAssertTrue(twoPoints.isValid)
    }

    func testRecognizedShapeConfidence() {
        let highConfidence = RecognizedShape(type: .rectangle, bounds: .zero, confidence: 0.8)
        XCTAssertTrue(highConfidence.isHighConfidence)
        XCTAssertFalse(highConfidence.isMediumConfidence)

        let mediumConfidence = RecognizedShape(type: .circle, bounds: .zero, confidence: 0.5)
        XCTAssertFalse(mediumConfidence.isHighConfidence)
        XCTAssertTrue(mediumConfidence.isMediumConfidence)

        let lowConfidence = RecognizedShape(type: .line, bounds: .zero, confidence: 0.2)
        XCTAssertFalse(lowConfidence.isHighConfidence)
        XCTAssertFalse(lowConfidence.isMediumConfidence)
    }

    func testCanvasDataSerialization() throws {
        let stroke = VectorStroke(
            points: [
                StrokePoint(location: CGPoint(x: 0, y: 0)),
                StrokePoint(location: CGPoint(x: 100, y: 100))
            ],
            width: 3.0,
            color: .black
        )
        let shape = RecognizedShape(type: .rectangle, bounds: CGRect(x: 10, y: 10, width: 50, height: 30), confidence: 0.9)

        let originalData = CanvasData(strokes: [stroke], recognizedShapes: [shape])
        let encoded = try originalData.encode()
        let decoded = try CanvasData.decode(from: encoded)

        XCTAssertEqual(decoded.strokes.count, 1)
        XCTAssertEqual(decoded.recognizedShapes.count, 1)
        XCTAssertEqual(decoded.strokes.first?.width, 3.0)
        XCTAssertEqual(decoded.recognizedShapes.first?.type, .rectangle)
    }

    // MARK: - StyleTypes Tests

    func testColorPaletteDefaults() {
        let lightPalette = ColorPalette.defaultLight
        XCTAssertNotNil(lightPalette.primary)
        XCTAssertNotNil(lightPalette.background)

        let darkPalette = ColorPalette.defaultDark
        XCTAssertNotNil(darkPalette.primary)
        XCTAssertNotNil(darkPalette.background)
    }

    func testTypographyScaleValues() {
        let scale = TypographyScale.macOSDefault
        XCTAssertGreaterThan(scale.largeTitle, scale.body)
        XCTAssertGreaterThan(scale.body, scale.caption1)
    }

    func testSpacingSystemMultipliers() {
        let spacing = SpacingSystem.standard4pt
        XCTAssertEqual(spacing.baseUnit, 4)
        XCTAssertEqual(spacing.sm, 8)
        XCTAssertEqual(spacing.md, 16)
    }

    func testExtractedStyleSerialization() throws {
        let style = ExtractedStyle.defaultStyle
        let encoded = try style.encode()
        let decoded = try ExtractedStyle.decode(from: encoded)

        XCTAssertEqual(style.colorPalette.primary.hexString, decoded.colorPalette.primary.hexString)
        XCTAssertEqual(style.typography.body, decoded.typography.body)
        XCTAssertEqual(style.spacing.baseUnit, decoded.spacing.baseUnit)
    }

    // MARK: - Error Tests

    func testSketchRecognitionErrorDescriptions() {
        let error = SketchRecognitionError.modelNotLoaded
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testStyleMirrorErrorDescriptions() {
        let error = StyleMirrorError.imageTooSmall(width: 32, height: 32)
        XCTAssertTrue(error.errorDescription?.contains("32") ?? false)
    }

    func testExportErrorDescriptions() {
        let error = ExportError.unsupportedFormat(format: "bmp")
        XCTAssertTrue(error.errorDescription?.contains("bmp") ?? false)
    }

    func testPersistenceErrorDescriptions() {
        let underlyingError = NSError(domain: "test", code: 1)
        let error = PersistenceError.saveFailed(underlying: underlyingError)
        XCTAssertNotNil(error.errorDescription)
    }

    func testRenderingErrorDescriptions() {
        let error = RenderingError.deviceNotAvailable
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }
}
