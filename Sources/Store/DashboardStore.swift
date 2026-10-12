import SwiftUI
import Observation

// MARK: - Dedicated Non-Isolated File System Monitor
private final class DirectoryWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1

    init?(directoryURL: URL, onChange: @escaping @Sendable () -> Void) {
        let descriptor = open(directoryURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        self.descriptor = descriptor

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler {
            onChange()
        }

        source.setCancelHandler {
            close(descriptor)
        }

        source.resume()
        self.source = source
    }

    deinit {
        source?.cancel()
    }
}

// MARK: - Main Actor Dashboard Store
@Observable
@MainActor
public final class DashboardStore {
    public var state: DashboardState

    private var watcher: DirectoryWatcher?
    private var isInternalWrite: Bool = false

    public init() {
        let directoryURL = AppConfig.storageDirectory
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        if let loaded = Self.loadFromDisk() {
            self.state = loaded
        } else {
            let initial = PreviewData.defaultState
            self.state = initial
            Self.writeToDisk(initial)
        }

        self.watcher = DirectoryWatcher(directoryURL: directoryURL) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.isInternalWrite { return }
                self.reloadFromDisk()
            }
        }
    }

    public func toggleBaselineTask(id: UUID) {
        guard let idx = state.baselineTasks.firstIndex(where: { $0.id == id }) else { return }
        state.baselineTasks[idx].isCompleted.toggle()
        persist()
    }

    public func resetDailyBaseline() {
        for idx in state.baselineTasks.indices {
            state.baselineTasks[idx].isCompleted = false
        }
        persist()
    }

    public func reloadFromDisk() {
        guard let reloaded = Self.loadFromDisk() else { return }
        self.state = reloaded
    }

    private func persist() {
        isInternalWrite = true
        Self.writeToDisk(state)
        
        // Clear flag after standard I/O cycle to allow external edits to be captured again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isInternalWrite = false
        }
    }

    private static func writeToDisk(_ stateToSave: DashboardState) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(stateToSave)
            try data.write(to: AppConfig.storageURL, options: .atomic)
        } catch {
            print("[DashboardStore] Failed to write state to disk: \(error)")
        }
    }

    private static func loadFromDisk() -> DashboardState? {
        guard FileManager.default.fileExists(atPath: AppConfig.storageURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: AppConfig.storageURL)
            return try JSONDecoder().decode(DashboardState.self, from: data)
        } catch {
            print("[DashboardStore] Failed to decode JSON state: \(error)")
            return nil
        }
    }
}