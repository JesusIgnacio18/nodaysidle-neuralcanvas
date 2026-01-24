import Foundation

// MARK: - Undo/Redo Manager

/// Manages undo/redo history for canvas operations using snapshot approach
@MainActor
@Observable
final class UndoRedoManager {
    // MARK: - Types

    /// A snapshot of canvas state for undo/redo
    struct CanvasSnapshot: Sendable {
        let strokes: [VectorStroke]
        let recognizedShapes: [RecognizedShape]
        let timestamp: Date

        init(strokes: [VectorStroke], recognizedShapes: [RecognizedShape]) {
            self.strokes = strokes
            self.recognizedShapes = recognizedShapes
            self.timestamp = Date()
        }
    }

    // MARK: - Properties

    /// Maximum number of snapshots to keep in history
    private let maxHistorySize: Int

    /// History stack for undo
    private var undoStack: [CanvasSnapshot] = []

    /// Stack for redo operations
    private var redoStack: [CanvasSnapshot] = []

    /// Whether undo is available
    var canUndo: Bool { !undoStack.isEmpty }

    /// Whether redo is available
    var canRedo: Bool { !redoStack.isEmpty }

    /// Number of undo steps available
    var undoCount: Int { undoStack.count }

    /// Number of redo steps available
    var redoCount: Int { redoStack.count }

    // MARK: - Initialization

    init(maxHistorySize: Int = 50) {
        self.maxHistorySize = maxHistorySize
        AppLogger.uiEvents.debug("UndoRedoManager initialized with max history: \(maxHistorySize)")
    }

    // MARK: - Public Methods

    /// Pushes a new snapshot onto the undo stack
    func pushSnapshot(strokes: [VectorStroke], shapes: [RecognizedShape]) {
        let snapshot = CanvasSnapshot(strokes: strokes, recognizedShapes: shapes)

        // Clear redo stack when new action is performed
        redoStack.removeAll()

        // Add to undo stack
        undoStack.append(snapshot)

        // Trim history if it exceeds max size
        while undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }

        AppLogger.uiEvents.debug("Pushed snapshot, undo stack size: \(self.undoStack.count)")
    }

    /// Performs undo operation and returns the previous state
    func undo(currentStrokes: [VectorStroke], currentShapes: [RecognizedShape]) -> CanvasSnapshot? {
        guard let previousSnapshot = undoStack.popLast() else {
            return nil
        }

        // Save current state to redo stack
        let currentSnapshot = CanvasSnapshot(strokes: currentStrokes, recognizedShapes: currentShapes)
        redoStack.append(currentSnapshot)

        AppLogger.uiEvents.debug("Undo performed, undo stack: \(self.undoStack.count), redo stack: \(self.redoStack.count)")

        return previousSnapshot
    }

    /// Performs redo operation and returns the next state
    func redo(currentStrokes: [VectorStroke], currentShapes: [RecognizedShape]) -> CanvasSnapshot? {
        guard let nextSnapshot = redoStack.popLast() else {
            return nil
        }

        // Save current state to undo stack
        let currentSnapshot = CanvasSnapshot(strokes: currentStrokes, recognizedShapes: currentShapes)
        undoStack.append(currentSnapshot)

        AppLogger.uiEvents.debug("Redo performed, undo stack: \(self.undoStack.count), redo stack: \(self.redoStack.count)")

        return nextSnapshot
    }

    /// Clears all history
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        AppLogger.uiEvents.debug("Undo/redo history cleared")
    }

    /// Estimates memory usage of the history
    var estimatedMemoryUsage: Int {
        let undoSize = undoStack.reduce(0) { result, snapshot in
            result + estimateSnapshotSize(snapshot)
        }
        let redoSize = redoStack.reduce(0) { result, snapshot in
            result + estimateSnapshotSize(snapshot)
        }
        return undoSize + redoSize
    }

    // MARK: - Private Methods

    private func estimateSnapshotSize(_ snapshot: CanvasSnapshot) -> Int {
        // Rough estimate: each StrokePoint is ~40 bytes, each RecognizedShape is ~100 bytes
        let strokePointCount = snapshot.strokes.reduce(0) { $0 + $1.points.count }
        let strokeSize = strokePointCount * 40 + snapshot.strokes.count * 50
        let shapeSize = snapshot.recognizedShapes.count * 100
        return strokeSize + shapeSize
    }
}

// MARK: - Canvas State Extension for Undo/Redo

extension CanvasState {
    /// Creates a snapshot of the current state
    func createSnapshot() -> UndoRedoManager.CanvasSnapshot {
        UndoRedoManager.CanvasSnapshot(strokes: strokes, recognizedShapes: recognizedShapes)
    }

    /// Restores state from a snapshot
    func restore(from snapshot: UndoRedoManager.CanvasSnapshot) {
        strokes = snapshot.strokes
        recognizedShapes = snapshot.recognizedShapes
    }
}

// MARK: - Undo Action Types

/// Types of actions that can be undone
enum UndoableAction: Sendable {
    case addStroke(VectorStroke)
    case removeStroke(UUID)
    case modifyStroke(original: VectorStroke, modified: VectorStroke)
    case addShape(RecognizedShape)
    case removeShape(UUID)
    case modifyShape(original: RecognizedShape, modified: RecognizedShape)
    case batchModification(strokes: [VectorStroke], shapes: [RecognizedShape])
    case clearCanvas

    var description: String {
        switch self {
        case .addStroke: return "Add Stroke"
        case .removeStroke: return "Remove Stroke"
        case .modifyStroke: return "Modify Stroke"
        case .addShape: return "Add Shape"
        case .removeShape: return "Remove Shape"
        case .modifyShape: return "Modify Shape"
        case .batchModification: return "Batch Modification"
        case .clearCanvas: return "Clear Canvas"
        }
    }
}
