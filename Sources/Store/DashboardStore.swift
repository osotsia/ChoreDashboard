import SwiftUI
import Observation
import CryptoKit

public enum RightPanelTab: String, Codable {
    case upcoming
    case backlog
    case history
}

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

// MARK: - Thread-Safe Background Storage Engine
private actor StatePersistenceEngine {
    private let storageURL: URL
    private var lastPersistedChecksum: SHA256Digest?

    init(storageURL: URL) {
        self.storageURL = storageURL
    }

    func write(_ state: DashboardState) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            self.lastPersistedChecksum = SHA256.hash(data: data)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("[StatePersistenceEngine] Failed to write state: \(error)")
        }
    }

    func evaluateExternalChange() -> DashboardState? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: storageURL)
            let checksum = SHA256.hash(data: data)

            // Echo suppression: Ignore if matching our internal write
            if let last = lastPersistedChecksum, checksum == last {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode(DashboardState.self, from: data)
            self.lastPersistedChecksum = checksum
            return loaded
        } catch {
            print("[StatePersistenceEngine] Failed to decode external state: \(error)")
            return nil
        }
    }
}

// MARK: - Main Actor Dashboard Store
@Observable
@MainActor
public final class DashboardStore {
    public var state: DashboardState
    public var activeRightTab: RightPanelTab = .upcoming

    public var isShowingBacklog: Bool {
        get { activeRightTab == .backlog }
        set { activeRightTab = newValue ? .backlog : .upcoming }
    }

    private var watcher: DirectoryWatcher?
    private let persistenceEngine: StatePersistenceEngine

    public init() {
        let directoryURL = AppConfig.storageDirectory
        let fileURL = AppConfig.storageURL
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let engine = StatePersistenceEngine(storageURL: fileURL)
        self.persistenceEngine = engine

        if let initial = Self.loadInitialBlocking(from: fileURL) {
            self.state = initial
        } else {
            let fallback = PreviewData.defaultState
            self.state = fallback
            Task {
                await engine.write(fallback)
            }
        }

        self.watcher = DirectoryWatcher(directoryURL: directoryURL) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let updated = await self.persistenceEngine.evaluateExternalChange() {
                    self.state = updated
                }
            }
        }
    }

    // MARK: - Navigation Control
    public func selectRightTab(_ tab: RightPanelTab) {
        activeRightTab = tab
    }

    public func toggleBacklog() {
        activeRightTab = (activeRightTab == .backlog) ? .upcoming : .backlog
    }

    // MARK: - Task Mutations
    public func toggleFocusJob(id: UUID) {
        guard let idx = state.focusJobs.firstIndex(where: { $0.id == id }) else { return }
        
        // Mutate in isolation to prevent exclusivity lock overlaps
        state.focusJobs[idx].isCompleted.toggle()
        let isNowCompleted = state.focusJobs[idx].isCompleted
        let job = state.focusJobs[idx]

        syncHistoryRecord(
            taskId: job.id,
            title: job.title,
            tag: job.tag,
            note: job.notes,
            isCompleted: isNowCompleted
        )
    }

    public func toggleBaselineTask(id: UUID) {
        guard let idx = state.baselineTasks.firstIndex(where: { $0.id == id }) else { return }
        
        // Mutate in isolation to prevent exclusivity lock overlaps
        state.baselineTasks[idx].isCompleted.toggle()
        let isNowCompleted = state.baselineTasks[idx].isCompleted
        let task = state.baselineTasks[idx]

        syncHistoryRecord(
            taskId: task.id,
            title: task.title,
            tag: task.tag,
            note: "Daily baseline standard routine.",
            isCompleted: isNowCompleted
        )
    }

    private func syncHistoryRecord(
        taskId: UUID,
        title: String,
        tag: String,
        note: String,
        isCompleted: Bool
    ) {
        if isCompleted {
            let record = HistoryRecord(
                jobId: taskId,
                title: title,
                tag: tag,
                completedAt: Date(),
                note: note
            )
            state.historyRecords.insert(record, at: 0)
        } else {
            // LIFO Rollback
            if let recordIdx = state.historyRecords.firstIndex(where: { $0.jobId == taskId }) {
                state.historyRecords.remove(at: recordIdx)
            }
        }

        persistAsync()
    }

    public func recordJobCompletion(job: FocusJob, note: String = "") {
        let record = HistoryRecord(
            jobId: job.id,
            title: job.title,
            tag: job.tag,
            completedAt: Date(),
            note: note.isEmpty ? job.notes : note
        )
        state.historyRecords.insert(record, at: 0)
        persistAsync()
    }

    public func resetDailyBaseline() {
        for idx in state.baselineTasks.indices {
            state.baselineTasks[idx].isCompleted = false
        }
        persistAsync()
    }

    public func reloadFromDisk() {
        Task {
            if let reloaded = await persistenceEngine.evaluateExternalChange() {
                self.state = reloaded
            }
        }
    }

    // MARK: - Asynchronous Persistence Dispatch
    private func persistAsync() {
        let snapshot = state
        Task {
            await persistenceEngine.write(snapshot)
        }
    }

    private static func loadInitialBlocking(from url: URL) -> DashboardState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(DashboardState.self, from: data)
        } catch {
            print("[DashboardStore] Synchronous initial load failed: \(error)")
            return nil
        }
    }
}