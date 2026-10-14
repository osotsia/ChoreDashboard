// Sources/Store/DashboardStore.swift
import SwiftUI
import Observation
import CryptoKit

// MARK: - Navigation Modes
public enum RightPanelTab: String, Codable {
    case upcoming
    case backlog
    case history
    case create
}

// MARK: - Cadence & Health Domain Enums
public enum CadenceUnit: String, CaseIterable, Codable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"

    public func days(count: Int) -> Int {
        switch self {
        case .day:   return count
        case .week:  return count * 7
        case .month: return count * 30
        case .year:  return count * 365
        }
    }

    public func displayString(count: Int) -> String {
        if count == 1 { return rawValue }
        return "\(rawValue)s"
    }

    public func next() -> CadenceUnit {
        let all = Self.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }

    public func previous() -> CadenceUnit {
        let all = Self.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx - 1 + all.count) % all.count]
    }
}

public enum TaskHealthState: String, CaseIterable, Codable {
    case good = "GOOD"
    case notYet = "NOT YET"
    case due = "DUE"
    case overdue = "OVERDUE"

    public var subtitle: String {
        switch self {
        case .good:    return "FRESH"
        case .notYet:  return "RUNNING"
        case .due:     return "TODAY"
        case .overdue: return "URGENT"
        }
    }
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
    public private(set) var previousRightTab: RightPanelTab = .upcoming

    public var isShowingBacklog: Bool {
        get { activeRightTab == .backlog }
        set { selectRightTab(newValue ? .backlog : .upcoming) }
    }

    // Dynamic tag aggregation across active state AND persisted custom tags
    public var availableTags: [String] {
        var tags = Set<String>()

        let sanitize: (String) -> String = { raw in
            let clean = raw.components(separatedBy: CharacterSet(charactersIn: "·-–,"))[0]
            return clean.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }

        for tag in state.customTags {
            let t = sanitize(tag)
            if !t.isEmpty { tags.insert(t) }
        }
        for job in state.focusJobs {
            let t = sanitize(job.tag)
            if !t.isEmpty { tags.insert(t) }
        }
        for task in state.baselineTasks {
            let t = sanitize(task.tag)
            if !t.isEmpty { tags.insert(t) }
        }
        for event in state.upcomingEvents {
            let t = sanitize(event.tag)
            if !t.isEmpty { tags.insert(t) }
        }
        for record in state.historyRecords {
            let t = sanitize(record.tag)
            if !t.isEmpty { tags.insert(t) }
        }

        let sorted = tags.sorted()
        return sorted.isEmpty ? ["KITCHEN", "FLOORS", "APPLIANCE", "PLUMBING"] : sorted
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
        guard tab != activeRightTab else { return }

        if activeRightTab != .create {
            previousRightTab = activeRightTab
        }
        activeRightTab = tab
    }

    public func dismissCreateTask() {
        activeRightTab = previousRightTab
    }

    public func toggleBacklog() {
        selectRightTab(activeRightTab == .backlog ? .upcoming : .backlog)
    }

    // MARK: - Custom Tag Management
    public func addCustomTag(_ tag: String) {
        let clean = tag.components(separatedBy: CharacterSet(charactersIn: "·-–,"))[0]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !clean.isEmpty else { return }

        if !state.customTags.contains(clean) {
            state.customTags.append(clean)
            persistAsync()
        }
    }

    // MARK: - Intelligent Cadence Dispatch Engine
    public func dispatchConfiguredTask(
        title: String,
        tag: String,
        notes: String,
        isOneTime: Bool,
        repeatCount: Int,
        repeatUnit: CadenceUnit,
        healthState: TaskHealthState
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure custom tag is recorded in permanent registry
        addCustomTag(cleanTag)

        // Case 1: Immediate action -> Dispatches to active operations
        if healthState == .due || healthState == .overdue {
            if !isOneTime && repeatUnit == .day && repeatCount == 1 {
                addBaselineTask(title: cleanTitle, tag: cleanTag, durationMinutes: 15)
            } else {
                let notePrefix = (healthState == .overdue) ? "[OVERDUE] " : ""
                addFocusJob(title: cleanTitle, tag: cleanTag, notes: notePrefix + cleanNotes)
            }
            return
        }

        // Case 2: Healthy or pending -> Calculate upcoming horizon anchor
        let intervalDays = isOneTime ? 7 : repeatUnit.days(count: repeatCount)
        let daysUntilDue: Int
        if healthState == .good {
            daysUntilDue = max(1, intervalDays)
        } else {
            daysUntilDue = max(1, intervalDays / 2)
        }

        let timeAnchor: String
        if daysUntilDue == 1 {
            timeAnchor = "In 1 Day"
        } else if daysUntilDue < 14 {
            timeAnchor = "In \(daysUntilDue) Days"
        } else if daysUntilDue < 60 {
            let weeks = max(1, daysUntilDue / 7)
            timeAnchor = "In \(weeks) Weeks (\(daysUntilDue)d)"
        } else {
            let months = max(1, daysUntilDue / 30)
            timeAnchor = "In \(months) Months (\(daysUntilDue)d)"
        }

        addUpcomingEvent(title: cleanTitle, tag: cleanTag, notes: cleanNotes, timeAnchor: timeAnchor)

        // If registered as "GOOD", log initial completion history entry
        if healthState == .good {
            let record = HistoryRecord(
                title: cleanTitle,
                tag: cleanTag,
                completedAt: Date(),
                note: cleanNotes.isEmpty ? "Initial cycle state registered as completed." : cleanNotes
            )
            state.historyRecords.insert(record, at: 0)
        }

        persistAsync()
    }

    // MARK: - Domain Mutation Primitives
    public func addFocusJob(title: String, tag: String, notes: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let job = FocusJob(
            tag: cleanTag.isEmpty ? "OPERATION" : cleanTag,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isCompleted: false
        )
        state.focusJobs.append(job)
        persistAsync()
    }

    public func addBaselineTask(title: String, tag: String, durationMinutes: Int) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        let task = ChoreItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            durationMinutes: max(1, durationMinutes),
            tag: cleanTag.isEmpty ? "General" : cleanTag,
            isCompleted: false
        )
        state.baselineTasks.append(task)
        persistAsync()
    }

    public func addUpcomingEvent(title: String, tag: String, notes: String, timeAnchor: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAnchor = timeAnchor.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = HorizonEvent(
            tag: cleanTag.isEmpty ? "Scheduled" : cleanTag,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            timeAnchor: cleanAnchor.isEmpty ? "Upcoming" : cleanAnchor
        )
        state.upcomingEvents.append(event)
        persistAsync()
    }

    public func toggleFocusJob(id: UUID) {
        guard let idx = state.focusJobs.firstIndex(where: { $0.id == id }) else { return }
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