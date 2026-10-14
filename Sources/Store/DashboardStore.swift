// Sources/Store/DashboardStore.swift
import SwiftUI
import Observation

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

// MARK: - Main Actor Dashboard Store
@Observable
@MainActor
public final class DashboardStore {
    public var state: DashboardState
    public var activeRightTab: RightPanelTab = .upcoming

    // Backward compatibility shim for legacy callers
    public var isShowingBacklog: Bool {
        get { activeRightTab == .backlog }
        set { activeRightTab = newValue ? .backlog : .upcoming }
    }

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

    // MARK: - Navigation Control
    public func selectRightTab(_ tab: RightPanelTab) {
        activeRightTab = tab
    }

    public func toggleBacklog() {
        activeRightTab = (activeRightTab == .backlog) ? .upcoming : .backlog
    }

    // MARK: - Focus Job Operations
    public func toggleFocusJob(id: UUID) {
        guard let idx = state.focusJobs.firstIndex(where: { $0.id == id }) else { return }
        state.focusJobs[idx].isCompleted.toggle()

        if state.focusJobs[idx].isCompleted {
            let job = state.focusJobs[idx]
            recordJobCompletion(job: job)
        } else {
            removeLatestRecord(for: id)
        }

        persist()
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
    }

    // MARK: - Daily Baseline Operations
    public func toggleBaselineTask(id: UUID) {
        guard let idx = state.baselineTasks.firstIndex(where: { $0.id == id }) else { return }
        state.baselineTasks[idx].isCompleted.toggle()

        if state.baselineTasks[idx].isCompleted {
            let task = state.baselineTasks[idx]
            let record = HistoryRecord(
                jobId: task.id,
                title: task.title,
                tag: task.tag,
                completedAt: Date(),
                note: "Daily baseline standard routine."
            )
            state.historyRecords.insert(record, at: 0)
        } else {
            removeLatestRecord(for: id)
        }

        persist()
    }

    public func resetDailyBaseline() {
        for idx in state.baselineTasks.indices {
            state.baselineTasks[idx].isCompleted = false
        }
        persist()
    }

    // MARK: - History Rollback Helper
    private func removeLatestRecord(for jobId: UUID) {
        // Records are sorted newest-first (index 0 is the most recent)
        if let recordIdx = state.historyRecords.firstIndex(where: { $0.jobId == jobId }) {
            state.historyRecords.remove(at: recordIdx)
        }
    }

    // MARK: - Persistence & I/O
    public func reloadFromDisk() {
        guard let reloaded = Self.loadFromDisk() else { return }
        self.state = reloaded
    }

    private func persist() {
        isInternalWrite = true
        Self.writeToDisk(state)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isInternalWrite = false
        }
    }

    private static func writeToDisk(_ stateToSave: DashboardState) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
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
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(DashboardState.self, from: data)
        } catch {
            print("[DashboardStore] Failed to decode JSON state: \(error)")
            return nil
        }
    }
}