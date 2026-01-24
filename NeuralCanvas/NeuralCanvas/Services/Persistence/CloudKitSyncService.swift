import Foundation
import SwiftData
import CloudKit

// MARK: - CloudKit Sync Configuration

/// Configuration for CloudKit sync functionality
struct CloudKitSyncConfiguration {
    /// Container identifier for CloudKit
    static let containerIdentifier = "iCloud.com.neuralcanvas.app"

    /// Whether sync is available (requires entitlement and iCloud account)
    static var isSyncAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// The CloudKit container
    static var container: CKContainer {
        CKContainer(identifier: containerIdentifier)
    }
}

// MARK: - Sync State

/// Current state of CloudKit synchronization
enum SyncState: Equatable, Sendable {
    case idle
    case syncing
    case completed
    case failed(String)
    case disabled

    var description: String {
        switch self {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing..."
        case .completed:
            return "Sync complete"
        case .failed(let reason):
            return "Sync failed: \(reason)"
        case .disabled:
            return "Sync disabled"
        }
    }

    var isActive: Bool {
        self == .syncing
    }
}

// MARK: - CloudKit Sync Service

/// Service for managing CloudKit synchronization of style libraries
@MainActor
@Observable
final class CloudKitSyncService {
    // MARK: - Properties

    private let modelContainer: ModelContainer
    private(set) var syncState: SyncState = .idle
    private(set) var lastSyncDate: Date?

    private var syncTask: Task<Void, Never>?

    // MARK: - Initialization

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer

        // Check initial availability
        if !CloudKitSyncConfiguration.isSyncAvailable {
            syncState = .disabled
        }

        AppLogger.persistence.debug("CloudKitSyncService initialized")
    }

    // MARK: - Sync Operations

    /// Starts synchronization for libraries with sync enabled
    func startSync() {
        guard CloudKitSyncConfiguration.isSyncAvailable else {
            syncState = .disabled
            return
        }

        guard syncState != .syncing else {
            AppLogger.persistence.debug("Sync already in progress")
            return
        }

        syncTask = Task { [weak self] in
            await self?.performSync()
        }
    }

    /// Stops any ongoing synchronization
    func stopSync() {
        syncTask?.cancel()
        syncTask = nil

        if syncState == .syncing {
            syncState = .idle
        }
    }

    /// Forces a full sync refresh
    func forceRefresh() async {
        stopSync()
        await performSync()
    }

    // MARK: - Private Sync Implementation

    private func performSync() async {
        syncState = .syncing
        AppLogger.persistence.info("Starting CloudKit sync")

        do {
            // Get all libraries with sync enabled
            let mainContext = modelContainer.mainContext
            let predicate = #Predicate<StyleLibrary> { library in
                library.isSyncEnabled == true
            }
            let descriptor = FetchDescriptor<StyleLibrary>(predicate: predicate)
            let syncEnabledLibraries = try mainContext.fetch(descriptor)

            guard !syncEnabledLibraries.isEmpty else {
                AppLogger.persistence.debug("No libraries with sync enabled")
                syncState = .completed
                lastSyncDate = Date()
                return
            }

            // Sync each library
            for library in syncEnabledLibraries {
                try await syncLibrary(library)
            }

            syncState = .completed
            lastSyncDate = Date()
            AppLogger.persistence.info("CloudKit sync completed successfully")

        } catch {
            syncState = .failed(error.localizedDescription)
            AppLogger.persistence.error("CloudKit sync failed: \(error.localizedDescription)")
        }
    }

    private func syncLibrary(_ library: StyleLibrary) async throws {
        // This is a placeholder for actual CloudKit sync implementation
        // Full implementation would:
        // 1. Query CloudKit for remote changes
        // 2. Resolve conflicts
        // 3. Upload local changes
        // 4. Download remote changes

        AppLogger.persistence.debug("Syncing library: \(library.name)")

        // Simulate sync delay for now
        try await Task.sleep(for: .milliseconds(100))
    }
}

// MARK: - Conflict Resolution

/// Strategy for resolving sync conflicts
enum ConflictResolutionStrategy {
    case localWins
    case remoteWins
    case mostRecent
    case merge

    /// Resolves a conflict between local and remote style presets
    func resolve(local: StylePreset, remote: StylePresetDTO) -> StylePresetResolution {
        switch self {
        case .localWins:
            return .keepLocal

        case .remoteWins:
            return .useRemote

        case .mostRecent:
            if local.modifiedAt > remote.modifiedAt {
                return .keepLocal
            } else {
                return .useRemote
            }

        case .merge:
            // For style presets, we can't really merge, so use most recent
            return local.modifiedAt > remote.modifiedAt ? .keepLocal : .useRemote
        }
    }
}

/// Result of conflict resolution
enum StylePresetResolution {
    case keepLocal
    case useRemote
    case merged(StylePresetDTO)
}

// MARK: - Data Transfer Objects for CloudKit

/// DTO for syncing style presets via CloudKit
struct StylePresetDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let colorPaletteData: Data
    let typographyData: Data
    let spacingData: Data
    let cornerRadiusData: Data
    let shadowsData: Data
    let isBuiltIn: Bool
    let createdAt: Date
    let modifiedAt: Date
    let styleDescription: String?

    init(from preset: StylePreset) {
        self.id = preset.id
        self.name = preset.name
        self.colorPaletteData = preset.colorPaletteData
        self.typographyData = preset.typographyData
        self.spacingData = preset.spacingData
        self.cornerRadiusData = preset.cornerRadiusData
        self.shadowsData = preset.shadowsData
        self.isBuiltIn = preset.isBuiltIn
        self.createdAt = preset.createdAt
        self.modifiedAt = preset.modifiedAt
        self.styleDescription = preset.styleDescription
    }

    /// Converts back to a StylePreset
    func toStylePreset(library: StyleLibrary?) -> StylePreset {
        StylePreset(
            id: id,
            name: name,
            colorPaletteData: colorPaletteData,
            typographyData: typographyData,
            spacingData: spacingData,
            cornerRadiusData: cornerRadiusData,
            shadowsData: shadowsData,
            isBuiltIn: isBuiltIn,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            styleDescription: styleDescription,
            library: library
        )
    }
}

/// DTO for syncing style libraries via CloudKit
struct StyleLibraryDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let createdAt: Date
    let modifiedAt: Date
    let libraryDescription: String?
    let presets: [StylePresetDTO]

    init(from library: StyleLibrary) {
        self.id = library.id
        self.name = library.name
        self.createdAt = library.createdAt
        self.modifiedAt = library.modifiedAt
        self.libraryDescription = library.libraryDescription
        self.presets = library.presets.map { StylePresetDTO(from: $0) }
    }
}

// MARK: - Sync Settings

/// User preferences for CloudKit sync
/// Note: Cannot use @Observable with @AppStorage, so use UserDefaults directly
@MainActor
final class SyncSettings {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let cloudKitSyncEnabled = "cloudKitSyncEnabled"
        static let syncConflictStrategy = "syncConflictStrategy"
        static let syncOnLaunch = "syncOnLaunch"
        static let backgroundSyncEnabled = "backgroundSyncEnabled"
    }

    /// Whether sync is enabled globally
    var isSyncEnabled: Bool {
        get { defaults.bool(forKey: Keys.cloudKitSyncEnabled) }
        set { defaults.set(newValue, forKey: Keys.cloudKitSyncEnabled) }
    }

    /// Conflict resolution strategy preference
    var conflictStrategyRaw: String {
        get { defaults.string(forKey: Keys.syncConflictStrategy) ?? "mostRecent" }
        set { defaults.set(newValue, forKey: Keys.syncConflictStrategy) }
    }

    var conflictStrategy: ConflictResolutionStrategy {
        switch conflictStrategyRaw {
        case "localWins": return .localWins
        case "remoteWins": return .remoteWins
        case "merge": return .merge
        default: return .mostRecent
        }
    }

    /// Whether to sync automatically on app launch
    var syncOnLaunch: Bool {
        get { defaults.object(forKey: Keys.syncOnLaunch) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.syncOnLaunch) }
    }

    /// Whether to sync in background
    var backgroundSyncEnabled: Bool {
        get { defaults.object(forKey: Keys.backgroundSyncEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.backgroundSyncEnabled) }
    }
}
