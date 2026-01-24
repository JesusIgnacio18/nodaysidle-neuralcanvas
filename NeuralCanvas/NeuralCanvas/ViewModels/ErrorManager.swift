import Foundation
import SwiftUI

// MARK: - Error Severity

/// Severity levels for errors
enum ErrorSeverity: Int, Comparable, Sendable {
    case info = 0       // Informational message
    case warning = 1    // Warning that doesn't block operation
    case error = 2      // Error that blocks operation
    case critical = 3   // Critical error requiring immediate attention

    static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var iconName: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
}

// MARK: - Actionable Error

/// Protocol for errors that can present actions to the user
protocol ActionableError: LocalizedError {
    /// Severity of the error
    var severity: ErrorSeverity { get }

    /// Whether the error can be automatically recovered
    var isRecoverable: Bool { get }

    /// Whether this is a transient error that should be silently retried
    var isTransient: Bool { get }

    /// Available recovery actions
    var recoveryActions: [ErrorRecoveryAction] { get }

    /// Help URL for this error (if any)
    var helpURL: URL? { get }
}

// MARK: - Default Implementation

extension ActionableError {
    var severity: ErrorSeverity { .error }
    var isRecoverable: Bool { false }
    var isTransient: Bool { false }
    var recoveryActions: [ErrorRecoveryAction] { [.dismiss] }
    var helpURL: URL? { nil }
}

// MARK: - Error Recovery Action

/// Actions available for error recovery
struct ErrorRecoveryAction: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let role: ButtonRole?
    let action: @Sendable () async -> Void

    init(title: String, role: ButtonRole? = nil, action: @escaping @Sendable () async -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }

    // Common actions
    static let dismiss = ErrorRecoveryAction(title: "OK", role: nil) { }

    static func retry(_ action: @escaping @Sendable () async -> Void) -> ErrorRecoveryAction {
        ErrorRecoveryAction(title: "Retry", role: nil, action: action)
    }

    static func cancel(_ action: @escaping @Sendable () async -> Void = {}) -> ErrorRecoveryAction {
        ErrorRecoveryAction(title: "Cancel", role: .cancel, action: action)
    }
}

// MARK: - Presentable Error

/// Wrapper for presenting any error with consistent UI
struct PresentableError: Identifiable {
    let id = UUID()
    let underlyingError: Error
    let severity: ErrorSeverity
    let title: String
    let message: String
    let actions: [ErrorRecoveryAction]
    let helpURL: URL?
    let timestamp: Date

    init(
        error: Error,
        severity: ErrorSeverity = .error,
        title: String? = nil,
        actions: [ErrorRecoveryAction]? = nil
    ) {
        self.underlyingError = error
        self.timestamp = Date()

        if let actionable = error as? ActionableError {
            self.severity = actionable.severity
            self.title = title ?? "Error"
            self.message = actionable.errorDescription ?? error.localizedDescription
            self.actions = actions ?? actionable.recoveryActions
            self.helpURL = actionable.helpURL
        } else {
            self.severity = severity
            self.title = title ?? "Error"
            self.message = error.localizedDescription
            self.actions = actions ?? [.dismiss]
            self.helpURL = nil
        }
    }
}

// MARK: - Error Manager

/// Observable manager for app-wide error state
@MainActor
@Observable
final class ErrorManager {
    // MARK: - Properties

    /// Current error to present (if any)
    private(set) var currentError: PresentableError?

    /// Queue of errors to present
    private var errorQueue: [PresentableError] = []

    /// Whether an error alert is currently showing
    private(set) var isShowingError = false

    /// Error history for debugging
    private(set) var errorHistory: [PresentableError] = []
    private let maxHistorySize = 50

    /// Auto-dismiss delay for info/warning messages
    private let autoDismissDelay: TimeInterval = 5.0

    // MARK: - Initialization

    init() {
        AppLogger.general.debug("ErrorManager initialized")
    }

    // MARK: - Public Interface

    /// Presents an error to the user
    func present(_ error: Error, severity: ErrorSeverity = .error, title: String? = nil) {
        let presentable = PresentableError(error: error, severity: severity, title: title)
        queueError(presentable)
    }

    /// Presents an error with custom actions
    func present(_ error: Error, title: String? = nil, actions: [ErrorRecoveryAction]) {
        let presentable = PresentableError(error: error, title: title, actions: actions)
        queueError(presentable)
    }

    /// Shows a simple error message
    func showError(_ message: String, title: String = "Error") {
        let error = SimpleError(message: message)
        present(error, title: title)
    }

    /// Shows a warning message
    func showWarning(_ message: String, title: String = "Warning") {
        let error = SimpleError(message: message)
        present(error, severity: .warning, title: title)
    }

    /// Shows an info message
    func showInfo(_ message: String, title: String = "Info") {
        let error = SimpleError(message: message)
        present(error, severity: .info, title: title)
    }

    /// Dismisses the current error
    func dismissCurrent() {
        currentError = nil
        isShowingError = false

        // Show next queued error if any
        Task {
            try? await Task.sleep(for: .milliseconds(300)) // Brief delay for animation
            await MainActor.run {
                self.showNextError()
            }
        }
    }

    /// Clears all errors
    func clearAll() {
        currentError = nil
        errorQueue.removeAll()
        isShowingError = false
    }

    // MARK: - Private Methods

    private func queueError(_ error: PresentableError) {
        // Add to history
        errorHistory.append(error)
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst()
        }

        // Log the error
        logError(error)

        // Queue or present immediately
        if isShowingError {
            errorQueue.append(error)
        } else {
            showError(error)
        }
    }

    private func showError(_ error: PresentableError) {
        currentError = error
        isShowingError = true

        // Auto-dismiss for non-critical errors after delay
        if error.severity < .error && error.actions.count == 1 {
            Task {
                try? await Task.sleep(for: .seconds(autoDismissDelay))
                await MainActor.run {
                    if self.currentError?.id == error.id {
                        self.dismissCurrent()
                    }
                }
            }
        }
    }

    private func showNextError() {
        guard !errorQueue.isEmpty else { return }
        let next = errorQueue.removeFirst()
        showError(next)
    }

    private func logError(_ error: PresentableError) {
        switch error.severity {
        case .info:
            AppLogger.general.info("[\(error.title)] \(error.message)")
        case .warning:
            AppLogger.general.warning("[\(error.title)] \(error.message)")
        case .error, .critical:
            AppLogger.general.error("[\(error.title)] \(error.message)")
        }
    }
}

// MARK: - Simple Error

/// Simple error for showing messages
struct SimpleError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

// MARK: - Error Handling Extensions

extension SketchRecognitionError: ActionableError {
    var severity: ErrorSeverity {
        switch self {
        case .modelNotLoaded, .checksumMismatch: return .critical
        case .inferenceFailure: return .error
        case .invalidInput: return .warning
        case .cancelled: return .info
        }
    }

    var isTransient: Bool {
        switch self {
        case .inferenceFailure: return true
        default: return false
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .invalidInput, .inferenceFailure: return true
        default: return false
        }
    }
}

extension StyleMirrorError: ActionableError {
    var severity: ErrorSeverity {
        switch self {
        case .modelNotLoaded: return .critical
        case .analysisFailure: return .error
        case .insufficientContent, .unsupportedImageFormat, .incompatibleStyle, .applicationFailure, .imageTooSmall, .imageTooLarge: return .warning
        }
    }

    var isTransient: Bool {
        switch self {
        case .analysisFailure: return true
        default: return false
        }
    }
}

extension ExportError: ActionableError {
    var severity: ErrorSeverity {
        switch self {
        case .insufficientMemory: return .critical
        case .renderingFailed, .fileWriteFailed: return .error
        case .unsupportedFormat, .invalidFileName, .cancelled: return .warning
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .insufficientMemory: return true
        case .fileWriteFailed: return true
        default: return false
        }
    }
}

extension PersistenceError: ActionableError {
    var severity: ErrorSeverity {
        switch self {
        case .migrationRequired, .migrationFailed, .containerInitializationFailed: return .critical
        case .saveFailed, .deleteFailed, .dataCorrupted: return .error
        case .fetchFailed: return .warning
        }
    }

    var isTransient: Bool {
        switch self {
        case .saveFailed, .fetchFailed: return true
        default: return false
        }
    }
}

extension RenderingError: ActionableError {
    var severity: ErrorSeverity {
        switch self {
        case .deviceNotAvailable: return .critical
        case .shaderCompilationFailed, .pipelineCreationFailed: return .critical
        case .textureAllocationFailed: return .error
        case .commandBufferFailed, .viewportInvalid: return .error
        }
    }
}

// MARK: - Silent Recovery Handler

/// Handles automatic recovery from transient errors
actor SilentRecoveryHandler {
    private let retryManager = RetryManager(configuration: .default)

    /// Attempts to execute an operation with silent recovery
    func execute<T>(
        operation: @Sendable () async throws -> T,
        onRecovery: (@Sendable () -> Void)? = nil,
        onFinalFailure: (@Sendable (Error) -> Void)? = nil
    ) async throws -> T {
        do {
            return try await retryManager.execute(
                operation: operation,
                shouldRetry: { error in
                    if let actionable = error as? ActionableError {
                        return actionable.isTransient
                    }
                    return false
                }
            )
        } catch {
            onFinalFailure?(error)
            throw error
        }
    }
}
