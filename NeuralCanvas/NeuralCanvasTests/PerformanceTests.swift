import XCTest
@testable import NeuralCanvas

/// Performance tests for critical paths
@MainActor
final class PerformanceTests: XCTestCase {

    // MARK: - Sketch to Wireframe Performance

    func testSketchToWireframePerformance() throws {
        // This test measures the complete sketch-to-wireframe pipeline
        // Target: < 500ms on M4 chip

        let recognizer = SketchRecognitionActor()

        // Create a sample sketch image
        let testStrokes = createTestStrokes(count: 10)
        guard let testImage = createTestImage(from: testStrokes) else {
            throw XCTSkip("Could not create test image")
        }

        // Measure performance
        measure {
            let expectation = expectation(description: "Recognition complete")

            Task {
                do {
                    let _ = try await recognizer.processSketch(image: testImage)
                    expectation.fulfill()
                } catch {
                    // Recognition may fail with mock model, but we're measuring time
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 2.0)
        }
    }

    // MARK: - Export Performance

    func testSVGExportPerformance() async throws {
        let exportService = ExportService()

        // Create complex wireframe data
        let shapes = createTestShapes(count: 100)
        let options = ExportOptions(format: .svg)
        let canvasSize = CGSize(width: 1920, height: 1080)

        // Measure export time
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<10 {
            let _ = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = elapsed / 10.0

        // Average should be under 100ms for 100 shapes
        XCTAssertLessThan(averageTime, 0.1, "SVG export took too long: \(averageTime)s")
    }

    func testPNGExportPerformance() async throws {
        let exportService = ExportService()

        let shapes = createTestShapes(count: 50)
        let options = ExportOptions(format: .png, scale: 2.0)
        let canvasSize = CGSize(width: 1920, height: 1080)

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<5 {
            let _ = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = elapsed / 5.0

        // PNG export at 2x scale for 1920x1080 can take several seconds
        // Target: under 5 seconds average per export
        XCTAssertLessThan(averageTime, 5.0, "PNG export took too long: \(averageTime)s")
    }

    // MARK: - Style Extraction Performance

    func testStyleExtractionPerformance() async throws {
        let styleActor = StyleMirrorActor()

        guard let testImage = createSolidColorImage(width: 512, height: 512) else {
            throw XCTSkip("Could not create test image")
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<5 {
            let _ = try? await styleActor.extractStyle(from: testImage)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = elapsed / 5.0

        // Style extraction should be under 300ms
        XCTAssertLessThan(averageTime, 0.3, "Style extraction took too long: \(averageTime)s")
    }

    // MARK: - Serialization Performance

    func testCanvasDataSerializationPerformance() throws {
        let strokes = createTestStrokes(count: 1000)
        let shapes = createTestShapes(count: 500)
        let canvasData = CanvasData(strokes: strokes, recognizedShapes: shapes)

        measure {
            do {
                let encoded = try canvasData.encode()
                let _ = try CanvasData.decode(from: encoded)
            } catch {
                XCTFail("Serialization failed: \(error)")
            }
        }
    }

    func testStyleSerializationPerformance() throws {
        let style = ExtractedStyle.defaultStyle

        measure {
            do {
                let encoded = try style.encode()
                let _ = try ExtractedStyle.decode(from: encoded)
            } catch {
                XCTFail("Serialization failed: \(error)")
            }
        }
    }

    // MARK: - Memory Tests

    func testExportMemoryUsage() async throws {
        let exportService = ExportService()
        let shapes = createTestShapes(count: 200)
        let canvasSize = CGSize(width: 4096, height: 4096)
        let options = ExportOptions(format: .png, scale: 1.0, maxDimension: 4096)

        // This should not cause memory issues
        let data = try await exportService.export(shapes: shapes, canvasSize: canvasSize, options: options)
        XCTAssertFalse(data.isEmpty)
    }

    // MARK: - Test Data Helpers

    private func createTestStrokes(count: Int) -> [VectorStroke] {
        var strokes: [VectorStroke] = []

        for i in 0..<count {
            var points: [StrokePoint] = []
            for j in 0..<20 {
                let x = CGFloat(i * 50 + j * 5)
                let y = CGFloat(i * 30 + j * 3)
                let point = StrokePoint(location: CGPoint(x: x, y: y))
                points.append(point)
            }
            let stroke = VectorStroke(points: points, width: 2.0, color: .black)
            strokes.append(stroke)
        }

        return strokes
    }

    private func createTestShapes(count: Int) -> [RecognizedShape] {
        var shapes: [RecognizedShape] = []
        let shapeTypes: [ShapeType] = [.rectangle, .circle, .button, .inputField, .text]

        for i in 0..<count {
            let type = shapeTypes[i % shapeTypes.count]
            let x = CGFloat((i % 10) * 100)
            let y = CGFloat((i / 10) * 60)
            let bounds = CGRect(x: x, y: y, width: 80, height: 40)
            let shape = RecognizedShape(type: type, bounds: bounds, confidence: 0.85)
            shapes.append(shape)
        }

        return shapes
    }

    private func createTestImage(from strokes: [VectorStroke]) -> CGImage? {
        let width = 800
        let height = 600
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // White background
        context.setFillColor(CGColor.white)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw strokes
        context.setStrokeColor(CGColor.black)
        context.setLineWidth(2)

        for stroke in strokes {
            guard stroke.points.count >= 2 else { continue }
            context.beginPath()
            let first = stroke.points[0].location
            context.move(to: CGPoint(x: first.x, y: CGFloat(height) - first.y))

            for point in stroke.points.dropFirst() {
                context.addLine(to: CGPoint(x: point.location.x, y: CGFloat(height) - point.location.y))
            }
            context.strokePath()
        }

        return context.makeImage()
    }

    private func createSolidColorImage(width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Blue background
        context.setFillColor(CGColor(red: 0, green: 0.5, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // White rectangle
        context.setFillColor(CGColor.white)
        context.fill(CGRect(x: 50, y: 50, width: 200, height: 100))

        return context.makeImage()
    }
}
