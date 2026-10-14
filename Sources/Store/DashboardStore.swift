// --- File: Sources/Store/DashboardStore.swift ---
import SwiftUI
import Observation
import CryptoKit

public enum RightPanelTab: String, Codable {
    case upcoming
    case backlog
    case history
    case create
    case edit
}

public enum EditableTaskTarget: Identifiable, Equatable {
    case focus(FocusJob)
    case baseline(ChoreItem)
    case horizon(HorizonEvent)

    public var id: UUID {
        switch self {
        case .focus(let j): return j.id
        case .baseline(let c): return c.id
        case .horizon(let h): return h.id
        }
    }

    public static func == (lhs: EditableTaskTarget, rhs: EditableTaskTarget) -> Bool {
        switch (lhs, rhs) {
        case (.focus(let a), .focus(let b)):
            return a.id == b.id && a.title == b.title && a.tag == b.tag && a.notes == b.notes && a.isCompleted == b.isCompleted && a.isOverdue == b.isOverdue
        case (.baseline(let a), .baseline(let b)):
            return a.id == b.id && a.title == b.title && a.tag == b.tag && a.durationMinutes == b.durationMinutes && a.isCompleted == b.isCompleted
        case (.horizon(let a), .horizon(let b)):
            return a.id == b.id && a.title == b.title && a.tag == b.tag && a.notes == b.notes && a.timeAnchor == b.timeAnchor
        default:
            return false
        }
    }
}

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

        source.setEventHandler { onChange() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    deinit {
        source?.cancel()
    }
}

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

@Observable
@MainActor
public final class DashboardStore {
    public var state: DashboardState
    public var activeRightTab: RightPanelTab = .upcoming
    public private(set) var previousRightTab: RightPanelTab = .upcoming
    public var editingTarget: EditableTaskTarget? = nil

    public var isShowingBacklog: Bool {
        get { activeRightTab == .backlog }
        set { selectRightTab(newValue ? .backlog : .upcoming) }
    }

    public var availableTags: [String] {
        var tags = Set<String>()

        // Split only on bullets or commas so hyphens (e.g. POST-MORTEM) remain intact
        let sanitize: (String) -> String = { raw in
            let clean = raw.components(separatedBy: CharacterSet(charactersIn: "·,"))[0]
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
            // Backup corrupt file if present to preserve user data
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let backupURL = fileURL.deletingPathExtension()
                    .appendingPathExtension("corrupt.\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.copyItem(at: fileURL, to: backupURL)
                print("[DashboardStore] Corrupted state.json preserved to \(backupURL.lastPathComponent)")
            }

            let fallback = PreviewData.defaultState
            self.state = fallback
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                Task {
                    await engine.write(fallback)
                }
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

    public func selectRightTab(_ tab: RightPanelTab) {
        guard tab != activeRightTab else { return }

        if activeRightTab == .edit && tab != .edit {
            editingTarget = nil
        }

        if activeRightTab != .create && activeRightTab != .edit {
            previousRightTab = activeRightTab
        }
        activeRightTab = tab
    }

    public func dismissCreateTask() {
        activeRightTab = previousRightTab
    }

    public func dismissEditTask() {
        editingTarget = nil
        activeRightTab = previousRightTab
    }

    public func toggleBacklog() {
        selectRightTab(activeRightTab == .backlog ? .upcoming : .backlog)
    }

    public func startEditing(focusJob: FocusJob) {
        editingTarget = .focus(focusJob)
        selectRightTab(.edit)
    }

    public func startEditing(baselineTask: ChoreItem) {
        editingTarget = .baseline(baselineTask)
        selectRightTab(.edit)
    }

    public func startEditing(upcomingEvent: HorizonEvent) {
        editingTarget = .horizon(upcomingEvent)
        selectRightTab(.edit)
    }

    public func applyEditedTask(
        target: EditableTaskTarget,
        title: String,
        tag: String,
        notes: String,
        durationMinutes: Int,
        isOneTime: Bool,
        repeatCount: Int,
        repeatUnit: CadenceUnit,
        healthState: TaskHealthState
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetId = target.id

        addCustomTag(cleanTag)

        let originalCompleted: Bool
        switch target {
        case .focus(let job):
            originalCompleted = job.isCompleted
            state.focusJobs.removeAll(where: { $0.id == targetId })
        case .baseline(let task):
            originalCompleted = task.isCompleted
            state.baselineTasks.removeAll(where: { $0.id == targetId })
        case .horizon:
            originalCompleted = false
            state.upcomingEvents.removeAll(where: { $0.id == targetId })
        }

        if healthState == .due || healthState == .overdue {
            if !isOneTime && repeatUnit == .day && repeatCount == 1 {
                let task = ChoreItem(
                    id: targetId,
                    title: cleanTitle,
                    durationMinutes: durationMinutes,
                    tag: cleanTag,
                    isCompleted: originalCompleted
                )
                state.baselineTasks.append(task)
            } else {
                let job = FocusJob(
                    id: targetId,
                    tag: cleanTag,
                    title: cleanTitle,
                    notes: cleanNotes,
                    isCompleted: originalCompleted,
                    isOverdue: healthState == .overdue
                )
                state.focusJobs.append(job)
            }
        } else {
            let intervalDays = isOneTime ? 7 : repeatUnit.days(count: repeatCount)
            let daysUntilDue = (healthState == .good) ? max(1, intervalDays) : max(1, intervalDays / 2)
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

            let event = HorizonEvent(
                id: targetId,
                tag: cleanTag,
                title: cleanTitle,
                notes: cleanNotes,
                timeAnchor: timeAnchor
            )
            state.upcomingEvents.append(event)
        }

        dismissEditTask()
        persistAsync()
    }

    public func deleteTask(target: EditableTaskTarget) {
        let targetId = target.id
        switch target {
        case .focus:
            state.focusJobs.removeAll(where: { $0.id == targetId })
        case .baseline:
            state.baselineTasks.removeAll(where: { $0.id == targetId })
        case .horizon:
            state.upcomingEvents.removeAll(where: { $0.id == targetId })
        }
        dismissEditTask()
        persistAsync()
    }

    public func addCustomTag(_ tag: String) {
        let clean = tag.components(separatedBy: CharacterSet(charactersIn: "·,"))[0]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !clean.isEmpty else { return }

        if !state.customTags.contains(clean) {
            state.customTags.append(clean)
            persistAsync()
        }
    }

    public func deleteCustomTag(_ tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        state.customTags.removeAll(where: { $0.uppercased() == clean })
        persistAsync()
    }

    public func dispatchConfiguredTask(
        title: String,
        tag: String,
        notes: String,
        durationMinutes: Int,
        isOneTime: Bool,
        repeatCount: Int,
        repeatUnit: CadenceUnit,
        healthState: TaskHealthState
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let newId = UUID()

        addCustomTag(cleanTag)

        if healthState == .due || healthState == .overdue {
            if !isOneTime && repeatUnit == .day && repeatCount == 1 {
                let task = ChoreItem(
                    id: newId,
                    title: cleanTitle,
                    durationMinutes: durationMinutes,
                    tag: cleanTag,
                    isCompleted: false
                )
                state.baselineTasks.append(task)
            } else {
                let job = FocusJob(
                    id: newId,
                    tag: cleanTag,
                    title: cleanTitle,
                    notes: cleanNotes,
                    isCompleted: false,
                    isOverdue: healthState == .overdue
                )
                state.focusJobs.append(job)
            }
            persistAsync()
            return
        }

        let intervalDays = isOneTime ? 7 : repeatUnit.days(count: repeatCount)
        let daysUntilDue = (healthState == .good) ? max(1, intervalDays) : max(1, intervalDays / 2)

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

        let event = HorizonEvent(
            id: newId,
            tag: cleanTag,
            title: cleanTitle,
            notes: cleanNotes,
            timeAnchor: timeAnchor
        )
        state.upcomingEvents.append(event)

        if healthState == .good {
            let record = HistoryRecord(
                jobId: newId,
                title: cleanTitle,
                tag: cleanTag,
                completedAt: Date(),
                note: cleanNotes.isEmpty ? "Initial cycle state registered as completed." : cleanNotes
            )
            state.historyRecords.insert(record, at: 0)
        }

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