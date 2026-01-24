import Foundation

// MARK: - Sketch Recognition Errors

/// Errors that can occur during sketch recognition ML inference
enum SketchRecognitionError: LocalizedError {
    case modelNotLoaded
    case inferenceFailure(underlying: Error)
    case invalidInput(reason: String)
    case cancelled
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "The sketch recognition model is not loaded. Please restart the app."
        case .inferenceFailure(let underlying):
            return "Failed to process sketch: \(underlying.localizedDescription)"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .cancelled:
            return "Sketch recognition was cancelled."
        case .checksumMismatch:
            return "Model file appears corrupted. Please reinstall the app."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .modelNotLoaded:
            return "Try restarting the application."
        case .inferenceFailure:
            return "Try simplifying your sketch or drawing again."
        case .invalidInput:
            return "Ensure your sketch is within the canvas bounds."
        case .cancelled:
            return nil
        case .checksumMismatch:
            return "Reinstall the application from the App Store."
        }
    }
}

// MARK: - Style Mirror Errors

/// Errors that can occur during style extraction and application
enum StyleMirrorError: LocalizedError {
    case modelNotLoaded
    case analysisFailure(underlying: Error)
    case insufficientContent
    case unsupportedImageFormat(format: String)
    case incompatibleStyle(reason: String)
    case applicationFailure(underlying: Error)
    case imageTooSmall(width: Int, height: Int)
    case imageTooLarge(width: Int, height: Int)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "The style analysis model is not loaded. Please restart the app."
        case .analysisFailure(let underlying):
            return "Failed to analyze style: \(underlying.localizedDescription)"
        case .insufficientContent:
            return "The image doesn't contain enough UI elements to extract a style."
        case .unsupportedImageFormat(let format):
            return "Unsupported image format: \(format). Please use PNG, JPEG, or HEIC."
        case .incompatibleStyle(let reason):
            return "Style cannot be applied: \(reason)"
        case .applicationFailure(let underlying):
            return "Failed to apply style: \(underlying.localizedDescription)"
        case .imageTooSmall(let width, let height):
            return "Image is too small (\(width)x\(height)). Minimum size is 64x64 pixels."
        case .imageTooLarge(let width, let height):
            return "Image is too large (\(width)x\(height)). Maximum size is 8192x8192 pixels."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .modelNotLoaded:
            return "Try restarting the application."
        case .analysisFailure:
            return "Try with a different screenshot."
        case .insufficientContent:
            return "Use a screenshot with more UI elements like buttons, text, and cards."
        case .unsupportedImageFormat:
            return "Convert your image to PNG or JPEG format."
        case .incompatibleStyle:
            return "Try extracting a style from a different screenshot."
        case .applicationFailure:
            return "Try applying the style again or choose a different preset."
        case .imageTooSmall:
            return "Use a higher resolution screenshot."
        case .imageTooLarge:
            return "Resize the image to be under 8192x8192 pixels."
        }
    }
}

// MARK: - Export Errors

/// Errors that can occur during wireframe export
enum ExportError: LocalizedError {
    case unsupportedFormat(format: String)
    case renderingFailed(underlying: Error)
    case insufficientMemory
    case fileWriteFailed(path: String, underlying: Error)
    case invalidFileName(name: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported export format: \(format)"
        case .renderingFailed(let underlying):
            return "Failed to render wireframe: \(underlying.localizedDescription)"
        case .insufficientMemory:
            return "Not enough memory to export at this resolution."
        case .fileWriteFailed(let path, let underlying):
            return "Failed to write file to \(path): \(underlying.localizedDescription)"
        case .invalidFileName(let name):
            return "Invalid file name: \(name)"
        case .cancelled:
            return "Export was cancelled."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedFormat:
            return "Choose SVG, PDF, PNG, or JPEG format."
        case .renderingFailed:
            return "Try exporting at a lower resolution."
        case .insufficientMemory:
            return "Close other applications or export at a lower resolution."
        case .fileWriteFailed:
            return "Check that you have write permission to the destination folder."
        case .invalidFileName:
            return "Use only letters, numbers, hyphens, and underscores in the file name."
        case .cancelled:
            return nil
        }
    }
}

// MARK: - Persistence Errors

/// Errors that can occur during data persistence
enum PersistenceError: LocalizedError {
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case migrationRequired(fromVersion: Int, toVersion: Int)
    case migrationFailed(underlying: Error)
    case dataCorrupted(entity: String)
    case containerInitializationFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let underlying):
            return "Failed to save data: \(underlying.localizedDescription)"
        case .fetchFailed(let underlying):
            return "Failed to load data: \(underlying.localizedDescription)"
        case .deleteFailed(let underlying):
            return "Failed to delete data: \(underlying.localizedDescription)"
        case .migrationRequired(let fromVersion, let toVersion):
            return "Database migration required from version \(fromVersion) to \(toVersion)."
        case .migrationFailed(let underlying):
            return "Database migration failed: \(underlying.localizedDescription)"
        case .dataCorrupted(let entity):
            return "Data for \(entity) appears corrupted."
        case .containerInitializationFailed(let underlying):
            return "Failed to initialize data storage: \(underlying.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .saveFailed:
            return "Try saving again. If the problem persists, restart the app."
        case .fetchFailed:
            return "Try restarting the application."
        case .deleteFailed:
            return "Try deleting again or restart the application."
        case .migrationRequired:
            return "The app will attempt to migrate your data automatically."
        case .migrationFailed:
            return "Your data may need to be recovered. Contact support if issues persist."
        case .dataCorrupted:
            return "The affected item may need to be recreated."
        case .containerInitializationFailed:
            return "Try restarting the application. If the problem persists, reinstall the app."
        }
    }
}

// MARK: - Rendering Errors

/// Errors that can occur during canvas rendering
enum RenderingError: LocalizedError {
    case deviceNotAvailable
    case shaderCompilationFailed(shaderName: String, underlying: Error)
    case textureAllocationFailed(width: Int, height: Int)
    case pipelineCreationFailed(underlying: Error)
    case commandBufferFailed(underlying: Error)
    case viewportInvalid(reason: String)

    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Metal GPU is not available on this device."
        case .shaderCompilationFailed(let shaderName, let underlying):
            return "Failed to compile shader '\(shaderName)': \(underlying.localizedDescription)"
        case .textureAllocationFailed(let width, let height):
            return "Failed to allocate texture of size \(width)x\(height)."
        case .pipelineCreationFailed(let underlying):
            return "Failed to create render pipeline: \(underlying.localizedDescription)"
        case .commandBufferFailed(let underlying):
            return "Render command failed: \(underlying.localizedDescription)"
        case .viewportInvalid(let reason):
            return "Invalid viewport: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .deviceNotAvailable:
            return "NeuralCanvas requires a Mac with Metal support."
        case .shaderCompilationFailed:
            return "This is an internal error. Please report this issue."
        case .textureAllocationFailed:
            return "Try reducing the canvas size or closing other applications."
        case .pipelineCreationFailed:
            return "Try restarting the application."
        case .commandBufferFailed:
            return "Try the operation again."
        case .viewportInvalid:
            return "Reset the canvas zoom and position."
        }
    }
}

// MARK: - Validation Errors

/// Errors for input validation
enum ValidationError: LocalizedError {
    case emptyName(field: String)
    case nameTooLong(field: String, maxLength: Int)
    case invalidCharacters(field: String, invalidChars: String)
    case outOfRange(field: String, min: Double, max: Double, actual: Double)

    var errorDescription: String? {
        switch self {
        case .emptyName(let field):
            return "\(field) cannot be empty."
        case .nameTooLong(let field, let maxLength):
            return "\(field) must be \(maxLength) characters or less."
        case .invalidCharacters(let field, let invalidChars):
            return "\(field) contains invalid characters: \(invalidChars)"
        case .outOfRange(let field, let min, let max, let actual):
            return "\(field) must be between \(min) and \(max). Got \(actual)."
        }
    }
}
