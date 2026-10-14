import SwiftUI
import Observation
import CryptoKit

public enum RightPanelTab: String, Codable {
    case status
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

    public var title: String {
        switch self {
        case .focus(let j): return j.title
        case .baseline(let c): return c.title
        case .horizon(let h): return h.title
        }
    }

    public var tag: String {
        switch self {
        case .focus(let j): return j.tag
        case .baseline(let c): return c.tag
        case .horizon(let h): return h.tag
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
        count == 1 ? rawValue : "\(rawValue)s"
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

public struct TodayOperationalSnapshot {
    public let focusTotal: Int
    public let focusCompleted: Int
    public let focusOverdue: Int
    public let focusRemaining: Int

    public let baselineTotal: Int
    public let baselineCompleted: Int
    public let baselineRemaining: Int
    public let baselineMinutesRemaining: Int

    public let totalTasks: Int
    public let completedTasks: Int
    public let clearanceRate: Double
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
            if let last = lastPersistedChecksum, checksum == last { return nil }

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
    public var activeRightTab: RightPanelTab = .status
    public private(set) var previousRightTab: RightPanelTab = .status
    public var editingTarget: EditableTaskTarget? = nil

    public var isShowingBacklog: Bool {
        get { activeRightTab == .backlog }
        set { selectRightTab(newValue ? .backlog : .status) }
    }

    public var todaySnapshot: TodayOperationalSnapshot {
        let fTotal = state.focusJobs.count
        let fDone = state.focusJobs.filter { $0.isCompleted }.count
        let fOverdue = state.focusJobs.filter { $0.isOverdue && !$0.isCompleted }.count
        let fRemaining = fTotal - fDone

        let bTotal = state.baselineTasks.count
        let bDone = state.baselineTasks.filter { $0.isCompleted }.count
        let bRemaining = bTotal - bDone
        let bMinsLeft = state.baselineTasks.filter { !$0.isCompleted }.reduce(0) { $0 + $1.durationMinutes }

        let total = fTotal + bTotal
        let completed = fDone + bDone
        let rate = total > 0 ? Double(completed) / Double(total) : 1.0

        return TodayOperationalSnapshot(
            focusTotal: fTotal,
            focusCompleted: fDone,
            focusOverdue: fOverdue,
            focusRemaining: fRemaining,
            baselineTotal: bTotal,
            baselineCompleted: bDone,
            baselineRemaining: bRemaining,
            baselineMinutesRemaining: bMinsLeft,
            totalTasks: total,
            completedTasks: completed,
            clearanceRate: rate
        )
    }

    public var sortedUpcomingEvents: [HorizonEvent] {
        state.upcomingEvents.sorted {
            if $0.estimatedDaysRemaining != $1.estimatedDaysRemaining {
                return $0.estimatedDaysRemaining < $1.estimatedDaysRemaining
            }
            return $0.title < $1.title
        }
    }

    public var availableTags: [String] {
        var tags = Set<String>()
        let sanitize: (String) -> String = { raw in
            raw.components(separatedBy: CharacterSet(charactersIn: "·,"))[0]
                .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }

        for tag in state.customTags { tags.insert(sanitize(tag)) }
        for job in state.focusJobs { tags.insert(sanitize(job.tag)) }
        for task in state.baselineTasks { tags.insert(sanitize(task.tag)) }
        for event in state.upcomingEvents { tags.insert(sanitize(event.tag)) }
        for record in state.historyRecords { tags.insert(sanitize(record.tag)) }

        let clean = tags.filter { !$0.isEmpty }.sorted()
        return clean.isEmpty ? ["KITCHEN", "FLOORS", "APPLIANCE", "PLUMBING"] : clean
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
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                Task { await engine.write(fallback) }
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
        selectRightTab(activeRightTab == .backlog ? .status : .backlog)
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
        durationMinutes: Int,
        isOneTime: Bool,
        repeatCount: Int,
        repeatUnit: CadenceUnit,
        healthState: TaskHealthState
    ) {
        let targetId = target.id
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

        routeTaskAssignment(
            id: targetId,
            title: title,
            tag: tag,
            durationMinutes: durationMinutes,
            isOneTime: isOneTime,
            repeatCount: repeatCount,
            repeatUnit: repeatUnit,
            healthState: healthState,
            isCompleted: originalCompleted
        )

        dismissEditTask()
        persistAsync()
    }

    public func deleteTask(target: EditableTaskTarget) {
        let targetId = target.id
        switch target {
        case .focus:    state.focusJobs.removeAll(where: { $0.id == targetId })
        case .baseline: state.baselineTasks.removeAll(where: { $0.id == targetId })
        case .horizon:  state.upcomingEvents.removeAll(where: { $0.id == targetId })
        }
        dismissEditTask()
        persistAsync()
    }

    public func dispatchConfiguredTask(
        title: String,
        tag: String,
        durationMinutes: Int,
        isOneTime: Bool,
        repeatCount: Int,
        repeatUnit: CadenceUnit,
        healthState: TaskHealthState
    ) {
        let newId = UUID()
        routeTaskAssignment(
            id: newId,
            title: title,
            tag: tag,
            durationMinutes: durationMinutes,
            isOneTime: isOneTime,
            repeatCount: repeatCount,
            repeatUnit: repeatUnit,
            healthState: healthState,
            isCompleted: false
        )

        if healthState == .good {
            let record = HistoryRecord(
                jobId: newId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                tag: tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                completedAt: Date()
            )
            state.historyRecords.insert(record, at: 0)
        }

        persistAsync()
    }

    private func routeTaskAssignment(
        id: UUID,
        title: String,
        tag: String,
        durationMinutes: Int,
        isOneTime: Bool,
        repeatCount: Int,
        repeatUnit: CadenceUnit,
        healthState: TaskHealthState,
        isCompleted: Bool
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        addCustomTag(cleanTag)

        if healthState == .due || healthState == .overdue {
            if !isOneTime && repeatUnit == .day && repeatCount == 1 {
                let task = ChoreItem(
                    id: id,
                    title: cleanTitle,
                    durationMinutes: durationMinutes,
                    tag: cleanTag,
                    isCompleted: isCompleted
                )
                state.baselineTasks.append(task)
            } else {
                let job = FocusJob(
                    id: id,
                    tag: cleanTag,
                    title: cleanTitle,
                    isCompleted: isCompleted,
                    isOverdue: healthState == .overdue
                )
                state.focusJobs.append(job)
            }
        } else {
            let intervalDays = isOneTime ? 7 : repeatUnit.days(count: repeatCount)
            let daysUntilDue = (healthState == .good) ? max(1, intervalDays) : max(1, intervalDays / 2)
            let timeAnchor = Self.computeTimeAnchor(daysUntilDue: daysUntilDue)

            let event = HorizonEvent(
                id: id,
                tag: cleanTag,
                title: cleanTitle,
                timeAnchor: timeAnchor,
                repeatCount: repeatCount,
                repeatUnit: repeatUnit,
                healthState: healthState
            )
            state.upcomingEvents.append(event)
        }
    }

    public static func computeTimeAnchor(daysUntilDue: Int) -> String {
        if daysUntilDue == 1 {
            return "In 1 Day"
        } else if daysUntilDue < 14 {
            return "In \(daysUntilDue) Days"
        } else if daysUntilDue < 60 {
            let weeks = max(1, daysUntilDue / 7)
            return "In \(weeks) Weeks (\(daysUntilDue)d)"
        } else {
            let months = max(1, daysUntilDue / 30)
            return "In \(months) Months (\(daysUntilDue)d)"
        }
    }

    public func addCustomTag(_ tag: String) {
        let clean = tag.components(separatedBy: CharacterSet(charactersIn: "·,"))[0]
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return }
        if !state.customTags.contains(clean) {
            state.customTags.append(clean)
            persistAsync()
        }
    }

    public func deleteTag(_ tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return }

        state.customTags.removeAll(where: { $0.uppercased() == clean })

        let fallbackTag = clean == "GENERAL" ? "OPERATIONS" : "GENERAL"

        for i in state.focusJobs.indices {
            if state.focusJobs[i].tag.uppercased() == clean {
                state.focusJobs[i].tag = fallbackTag
            }
        }
        for i in state.baselineTasks.indices {
            if state.baselineTasks[i].tag.uppercased() == clean {
                state.baselineTasks[i].tag = fallbackTag
            }
        }
        for i in state.upcomingEvents.indices {
            if state.upcomingEvents[i].tag.uppercased() == clean {
                state.upcomingEvents[i].tag = fallbackTag
            }
        }
        for i in state.historyRecords.indices {
            if state.historyRecords[i].tag.uppercased() == clean {
                state.historyRecords[i].tag = fallbackTag
            }
        }

        persistAsync()
    }

    public func deleteCustomTag(_ tag: String) {
        deleteTag(tag)
    }

    public func toggleFocusJob(id: UUID) {
        guard let idx = state.focusJobs.firstIndex(where: { $0.id == id }) else { return }
        state.focusJobs[idx].isCompleted.toggle()
        let job = state.focusJobs[idx]
        syncHistoryRecord(taskId: job.id, title: job.title, tag: job.tag, isCompleted: job.isCompleted)
    }

    public func toggleBaselineTask(id: UUID) {
        guard let idx = state.baselineTasks.firstIndex(where: { $0.id == id }) else { return }
        state.baselineTasks[idx].isCompleted.toggle()
        let task = state.baselineTasks[idx]
        syncHistoryRecord(taskId: task.id, title: task.title, tag: task.tag, isCompleted: task.isCompleted)
    }

    private func syncHistoryRecord(taskId: UUID, title: String, tag: String, isCompleted: Bool) {
        if isCompleted {
            let record = HistoryRecord(jobId: taskId, title: title, tag: tag, completedAt: Date())
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
        Task { await persistenceEngine.write(snapshot) }
    }

    private static func loadInitialBlocking(from url: URL) -> DashboardState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(DashboardState.self, from: data)
        } catch {
            print("[DashboardStore] Synchronous load failed: \(error)")
            return nil
        }
    }
}