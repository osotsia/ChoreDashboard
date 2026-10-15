import Foundation
import CryptoKit

/// Thread-safe file persistence actor managing disk I/O with SHA-256 change validation.
public actor FilePersistenceClient: PersistenceClient {
    public let storageURL: URL
    private var lastPersistedChecksum: SHA256Digest?

    public init(storageURL: URL = AppConfig.storageURL) {
        self.storageURL = storageURL
    }

    public func save(_ state: DashboardState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(state)
        let checksum = SHA256.hash(data: data)
        self.lastPersistedChecksum = checksum

        // Atomic write via temporary file replacement
        try data.write(to: storageURL, options: .atomic)
    }

    public func load() throws -> DashboardState? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return nil }
        let data = try Data(contentsOf: storageURL)
        self.lastPersistedChecksum = SHA256.hash(data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DashboardState.self, from: data)
    }

    public func evaluateExternalChange() throws -> DashboardState? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return nil }
        let data = try Data(contentsOf: storageURL)
        let checksum = SHA256.hash(data: data)

        // Short-circuit if disk file matches last known persisted state
        if let last = lastPersistedChecksum, checksum == last {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(DashboardState.self, from: data)
        self.lastPersistedChecksum = checksum
        return loaded
    }

    /// Synchronous initialization loader to prevent async suspension during application launch.
    public static func loadInitialBlocking(from url: URL) -> DashboardState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(DashboardState.self, from: data)
        } catch {
            print("[FilePersistenceClient] Synchronous load failed: \(error)")
            return nil
        }
    }
}