import Foundation
import OSLog

// MARK: - App Loggers

/// Centralized logging infrastructure using OSLog
enum AppLogger {
    /// Subsystem identifier for all NeuralCanvas logs
    static let subsystem = "com.neuralcanvas.app"

    // MARK: - Category Loggers

    /// Logger for ML inference operations (sketch recognition, style extraction)
    static let mlInference = Logger(subsystem: subsystem, category: "ml-inference")

    /// Logger for canvas rendering operations (Metal, drawing)
    static let canvasRendering = Logger(subsystem: subsystem, category: "canvas-rendering")

    /// Logger for persistence operations (SwiftData, file I/O)
    static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// Logger for export operations (SVG, PDF, PNG)
    static let export = Logger(subsystem: subsystem, category: "export")

    /// Logger for UI events and user interactions
    static let uiEvents = Logger(subsystem: subsystem, category: "ui-events")

    /// Logger for general app lifecycle and state
    static let general = Logger(subsystem: subsystem, category: "general")

    /// Logger for performance metrics
    static let performance = Logger(subsystem: subsystem, category: "performance")
}

// MARK: - Signpost Support

/// Signpost names for Instruments profiling
enum SignpostName {
    static let sketchRecognition = "SketchRecognition"
    static let preprocessing = "Preprocessing"
    static let inference = "Inference"
    static let postprocessing = "Postprocessing"
    static let styleExtraction = "StyleExtraction"
    static let styleApplication = "StyleApplication"
    static let canvasRender = "CanvasRender"
    static let export = "Export"
    static let persistence = "Persistence"
}

/// Signpost IDs for matching begin/end events
extension OSSignpostID {
    static func make(for object: AnyObject) -> OSSignpostID {
        OSSignpostID(log: OSLog(subsystem: AppLogger.subsystem, category: .pointsOfInterest), object: object)
    }
}

// MARK: - Logging Helpers

extension Logger {
    /// Logs the start of an operation with timing
    func operationStart(_ operation: String, id: UUID = UUID()) -> UUID {
        self.info("[\(id.uuidString.prefix(8))] Starting: \(operation)")
        return id
    }

    /// Logs the successful completion of an operation
    func operationEnd(_ operation: String, id: UUID, duration: TimeInterval) {
        let durationMs = String(format: "%.2f", duration * 1000)
        self.info("[\(id.uuidString.prefix(8))] Completed: \(operation) in \(durationMs)ms")
    }

    /// Logs the failure of an operation
    func operationFailed(_ operation: String, id: UUID, error: Error) {
        self.error("[\(id.uuidString.prefix(8))] Failed: \(operation) - \(error.localizedDescription)")
    }
}

// MARK: - Performance Logging

/// Utility for measuring and logging performance metrics
final class PerformanceLogger {
    let logger: Logger
    let operation: String
    let id: UUID
    private let startTime: CFAbsoluteTime

    init(logger: Logger = AppLogger.performance, operation: String) {
        self.logger = logger
        self.operation = operation
        self.id = UUID()
        self.startTime = CFAbsoluteTimeGetCurrent()
    }

    /// Logs the start of the operation - call after initialization
    func start() {
        let idStr = self.id.uuidString.prefix(8)
        let op = self.operation
        logger.info("[\(idStr)] Starting: \(op)")
    }

    /// Marks a checkpoint in the operation
    func checkpoint(_ name: String) {
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let elapsedMs = String(format: "%.2f", elapsed * 1000)
        let idStr = self.id.uuidString.prefix(8)
        logger.debug("[\(idStr)] Checkpoint '\(name)': \(elapsedMs)ms")
    }

    /// Completes the operation and logs the total duration
    func complete(success: Bool = true) {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let durationMs = String(format: "%.2f", duration * 1000)
        let idStr = self.id.uuidString.prefix(8)
        let op = self.operation

        if success {
            logger.info("[\(idStr)] Completed: \(op) in \(durationMs)ms")
        } else {
            logger.warning("[\(idStr)] Completed with issues: \(op) in \(durationMs)ms")
        }
    }

    /// Completes the operation with an error
    func fail(error: Error) {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let durationMs = String(format: "%.2f", duration * 1000)
        let idStr = self.id.uuidString.prefix(8)
        let op = self.operation
        logger.error("[\(idStr)] Failed: \(op) after \(durationMs)ms - \(error.localizedDescription)")
    }
}

// MARK: - Memory Logging

extension AppLogger {
    /// Logs current memory usage
    static func logMemoryUsage(context: String) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024 / 1024
            performance.info("Memory usage (\(context)): \(String(format: "%.1f", usedMB))MB")
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension Logger {
    /// Debug-only verbose logging
    func verbose(_ message: String) {
        self.debug("[VERBOSE] \(message)")
    }

    /// Logs object description for debugging
    func debugObject(_ label: String, _ object: Any) {
        self.debug("[\(label)] \(String(describing: object))")
    }
}
#endif
