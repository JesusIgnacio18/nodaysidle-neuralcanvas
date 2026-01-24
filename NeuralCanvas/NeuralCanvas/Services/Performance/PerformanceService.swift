import Foundation
import Combine
import os.signpost

// MARK: - Performance Metrics

/// Performance metrics collected during operation
struct PerformanceMetrics: Sendable {
    /// Average inference latency in milliseconds
    var averageInferenceLatency: Double = 0

    /// Average frame time in milliseconds
    var averageFrameTime: Double = 0

    /// Current memory usage in bytes
    var memoryUsage: UInt64 = 0

    /// Peak memory usage in bytes
    var peakMemoryUsage: UInt64 = 0

    /// Frame rate (frames per second)
    var frameRate: Double = 60.0

    /// Number of ML inferences performed
    var inferenceCount: Int = 0

    /// Number of dropped frames
    var droppedFrameCount: Int = 0

    /// Whether memory pressure is detected
    var isUnderMemoryPressure: Bool = false

    /// Timestamp of last update
    var lastUpdated: Date = Date()
}

// MARK: - Frame Rate Mode

/// Target frame rate modes
enum FrameRateMode: Int, Sendable {
    case full = 60      // Normal operation
    case reduced = 30   // During ML processing
    case minimal = 15   // Under memory pressure

    var targetFPS: Int { rawValue }

    var frameInterval: TimeInterval {
        1.0 / Double(rawValue)
    }
}

// MARK: - Performance Service Protocol

/// Protocol for performance monitoring
protocol PerformanceMonitoring: AnyObject, Sendable {
    /// Current metrics
    var metrics: PerformanceMetrics { get }

    /// Current frame rate mode
    var frameRateMode: FrameRateMode { get }

    /// Records an inference latency measurement
    func recordInferenceLatency(_ latency: TimeInterval)

    /// Records a frame time measurement
    func recordFrameTime(_ frameTime: TimeInterval)

    /// Sets the frame rate mode
    func setFrameRateMode(_ mode: FrameRateMode)

    /// Handles memory pressure notification
    func handleMemoryPressure()

    /// Clears caches to free memory
    func clearCaches()
}

// MARK: - Performance Service

/// Service for monitoring and optimizing app performance
@MainActor
@Observable
final class PerformanceService {
    // MARK: - Properties

    private(set) var metrics = PerformanceMetrics()
    private(set) var frameRateMode: FrameRateMode = .full

    private var inferenceLatencies: [TimeInterval] = []
    private var frameTimes: [TimeInterval] = []
    private let maxSampleCount = 100

    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var metricsUpdateTimer: Timer?

    // MARK: - Signpost

    private let signpostLog = OSLog(subsystem: AppLogger.subsystem, category: .pointsOfInterest)

    // MARK: - Callbacks

    var onMemoryWarning: (() -> Void)?
    var onFrameRateModeChanged: ((FrameRateMode) -> Void)?

    // MARK: - Memory Thresholds

    private let memoryWarningThreshold: UInt64 = 400 * 1024 * 1024  // 400MB
    private let memoryCriticalThreshold: UInt64 = 500 * 1024 * 1024 // 500MB

    // MARK: - Initialization

    init() {
        setupMemoryPressureMonitoring()
        startMetricsCollection()
        AppLogger.performance.info("PerformanceService initialized")
    }

    /// Call this method to clean up resources before the service is deallocated
    func cleanup() {
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        metricsUpdateTimer?.invalidate()
        metricsUpdateTimer = nil
    }

    // MARK: - Setup

    private func setupMemoryPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)

        source.setEventHandler { [weak self] in
            guard let self = self else { return }

            let event = source.data

            if event.contains(.critical) {
                AppLogger.performance.error("Critical memory pressure detected")
                Task { @MainActor in
                    self.handleCriticalMemoryPressure()
                }
            } else if event.contains(.warning) {
                AppLogger.performance.warning("Memory pressure warning")
                Task { @MainActor in
                    self.handleMemoryWarning()
                }
            }
        }

        source.resume()
        memoryPressureSource = source
    }

    private func startMetricsCollection() {
        // Update metrics every second
        metricsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
    }

    // MARK: - Metrics Collection

    func recordInferenceLatency(_ latency: TimeInterval) {
        inferenceLatencies.append(latency)
        if inferenceLatencies.count > maxSampleCount {
            inferenceLatencies.removeFirst()
        }

        metrics.inferenceCount += 1

        let latencyMs = latency * 1000
        AppLogger.performance.debug("Inference latency: \(String(format: "%.2f", latencyMs))ms")

        // Log warning if latency exceeds target
        if latency > 0.5 {
            AppLogger.performance.warning("Inference latency (\(String(format: "%.2f", latencyMs))ms) exceeds 500ms target")
        }
    }

    func recordFrameTime(_ frameTime: TimeInterval) {
        frameTimes.append(frameTime)
        if frameTimes.count > maxSampleCount {
            frameTimes.removeFirst()
        }

        // Track dropped frames (>16.7ms for 60fps)
        let targetFrameTime = frameRateMode.frameInterval
        if frameTime > targetFrameTime * 1.5 {
            metrics.droppedFrameCount += 1
        }
    }

    private func updateMetrics() {
        // Update memory usage
        metrics.memoryUsage = getCurrentMemoryUsage()
        metrics.peakMemoryUsage = max(metrics.peakMemoryUsage, metrics.memoryUsage)

        // Check memory pressure
        metrics.isUnderMemoryPressure = metrics.memoryUsage > memoryWarningThreshold

        // Calculate averages
        if !inferenceLatencies.isEmpty {
            let avgLatency = inferenceLatencies.reduce(0, +) / Double(inferenceLatencies.count)
            metrics.averageInferenceLatency = avgLatency * 1000 // Convert to ms
        }

        if !frameTimes.isEmpty {
            let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
            metrics.averageFrameTime = avgFrameTime * 1000 // Convert to ms
            metrics.frameRate = 1.0 / avgFrameTime
        }

        metrics.lastUpdated = Date()

        // Auto-adjust frame rate based on performance
        autoAdjustFrameRate()

        // Log periodic status
        let fps = self.metrics.frameRate
        let memMB = self.metrics.memoryUsage / 1024 / 1024
        AppLogger.performance.debug("Metrics: FPS=\(String(format: "%.1f", fps)), Memory=\(memMB)MB")
    }

    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return UInt64(info.resident_size)
        }
        return 0
    }

    // MARK: - Frame Rate Management

    func setFrameRateMode(_ mode: FrameRateMode) {
        guard frameRateMode != mode else { return }

        frameRateMode = mode
        AppLogger.performance.info("Frame rate mode changed to \(mode.targetFPS)fps")
        onFrameRateModeChanged?(mode)
    }

    private func autoAdjustFrameRate() {
        // Reduce frame rate under memory pressure
        if metrics.memoryUsage > memoryCriticalThreshold {
            setFrameRateMode(.minimal)
        } else if metrics.memoryUsage > memoryWarningThreshold {
            if frameRateMode == .full {
                setFrameRateMode(.reduced)
            }
        } else if metrics.isUnderMemoryPressure {
            // Stay at reduced until pressure clears
        } else {
            // Allow return to full frame rate
            if frameRateMode != .full {
                setFrameRateMode(.full)
            }
        }
    }

    // MARK: - Memory Pressure Handling

    private func handleMemoryWarning() {
        metrics.isUnderMemoryPressure = true
        setFrameRateMode(.reduced)
        onMemoryWarning?()

        // Clear non-essential caches
        clearNonEssentialCaches()
    }

    private func handleCriticalMemoryPressure() {
        metrics.isUnderMemoryPressure = true
        setFrameRateMode(.minimal)
        onMemoryWarning?()

        // Clear all caches
        clearAllCaches()
    }

    func clearNonEssentialCaches() {
        AppLogger.performance.info("Clearing non-essential caches")
        // This will be called by services that register with the performance service
    }

    func clearAllCaches() {
        AppLogger.performance.info("Clearing all caches")
        // This will be called by services that register with the performance service
    }

    // MARK: - Signpost Support

    /// Begins a signpost interval for performance profiling
    func beginSignpost(_ name: StaticString, id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: signpostLog, name: name, signpostID: id)
    }

    /// Ends a signpost interval
    func endSignpost(_ name: StaticString, id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: signpostLog, name: name, signpostID: id)
    }

    /// Emits a signpost event
    func emitSignpost(_ name: StaticString) {
        os_signpost(.event, log: signpostLog, name: name)
    }
}

// MARK: - Retry Manager

/// Manages retry logic with exponential backoff
final class RetryManager: Sendable {
    /// Configuration for retry behavior
    struct Configuration: Sendable {
        let maxRetries: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double

        static let `default` = Configuration(
            maxRetries: 3,
            initialDelay: 0.1,
            maxDelay: 2.0,
            multiplier: 2.0
        )

        static let memory = Configuration(
            maxRetries: 5,
            initialDelay: 0.5,
            maxDelay: 5.0,
            multiplier: 1.5
        )
    }

    private let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    /// Executes an operation with retry logic
    func execute<T>(
        operation: @Sendable () async throws -> T,
        shouldRetry: @Sendable (Error) -> Bool = { _ in true }
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = configuration.initialDelay

        for attempt in 0..<configuration.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                guard shouldRetry(error), attempt < configuration.maxRetries - 1 else {
                    throw error
                }

                AppLogger.performance.debug("Retry attempt \(attempt + 1) after \(String(format: "%.2f", currentDelay))s")

                try await Task.sleep(for: .seconds(currentDelay))

                currentDelay = min(currentDelay * configuration.multiplier, configuration.maxDelay)
            }
        }

        throw lastError ?? NSError(domain: "RetryManager", code: -1, userInfo: nil)
    }
}

// MARK: - Performance Monitor View

/// View showing current performance metrics (debug only)
#if DEBUG
import SwiftUI

struct PerformanceMonitorView: View {
    let service: PerformanceService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Performance")
                .font(.headline)

            HStack {
                Label("\(String(format: "%.1f", service.metrics.frameRate)) FPS", systemImage: "speedometer")
                Spacer()
                Label("\(service.metrics.memoryUsage / 1024 / 1024) MB", systemImage: "memorychip")
            }
            .font(.caption)

            if service.metrics.isUnderMemoryPressure {
                Label("Memory Pressure", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            Text("Avg Inference: \(String(format: "%.1f", service.metrics.averageInferenceLatency))ms")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Dropped Frames: \(service.metrics.droppedFrameCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
#endif
