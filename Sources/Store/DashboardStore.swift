// Sources/Store/DashboardStore.swift
import SwiftUI
import Observation
import CryptoKit
import UniformTypeIdentifiers

// MARK: - Navigation Tabs
public enum RightPanelTab: String, Codable, Sendable {
    case status
    case backlog
    case history
    case create
    case edit
}

// MARK: - Operational Snapshot
public struct TodayOperationalSnapshot: Sendable {
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

// MARK: - Monthly Pacing Snapshot (Race Telemetry)
public struct MonthlyPacingSnapshot: Sendable {
    public let monthTitle: String
    public let currentDay: Int
    public let totalDaysInMonth: Int
    public let actualCompleted: Int
    public let totalMonthlyQuota: Int
    public let deltaLead: Int
    public let actualProgressRatio: Double
    public let expectedProgressRatio: Double
    public let isLeading: Bool
}

// MARK: - Task Draft Model (Centralized Form State)
public struct TaskDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var isNew: Bool
    public var title: String
    public var tag: String
    public var durationMinutes: Int
    public var isOneTime: Bool
    public var repeatCount: Int
    public var repeatUnit: CadenceUnit
    public var targetDueDate: Date
    public var initialHealthState: TaskHealthState

    public init(
        id: UUID = UUID(),
        isNew: Bool = true,
        title: String = "",
        tag: String = "",
        durationMinutes: Int = 15,
        isOneTime: Bool = false,
        repeatCount: Int = 1,
        repeatUnit: CadenceUnit = .week,
        targetDueDate: Date = Date(),
        initialHealthState: TaskHealthState = .due
    ) {
        self.id = id
        self.isNew = isNew
        self.title = title
        self.tag = tag
        self.durationMinutes = durationMinutes
        self.isOneTime = isOneTime
        self.repeatCount = repeatCount
        self.repeatUnit = repeatUnit
        self.targetDueDate = targetDueDate
        self.initialHealthState = initialHealthState
    }

    public static func from(task: TaskItem) -> TaskDraft {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let taskDue = calendar.startOfDay(for: task.dueDate)

        let isOneTime = task.isOneTime
        let repeatCount: Int
        let repeatUnit: CadenceUnit

        if isOneTime {
            let diffDays = calendar.dateComponents([.day], from: today, to: taskDue).day ?? 0
            if diffDays > 0 {
                if diffDays % 30 == 0 {
                    repeatCount = max(1, diffDays / 30)
                    repeatUnit = .month
                } else if diffDays % 7 == 0 {
                    repeatCount = max(1, diffDays / 7)
                    repeatUnit = .week
                } else {
                    repeatCount = max(1, diffDays)
                    repeatUnit = .day
                }
            } else {
                repeatCount = 1
                repeatUnit = .day
            }
        } else {
            repeatCount = task.recurrence?.count ?? 1
            repeatUnit = task.recurrence?.unit ?? .week
        }

        return TaskDraft(
            id: task.id,
            isNew: false,
            title: task.title,
            tag: task.tag,
            durationMinutes: task.durationMinutes,
            isOneTime: isOneTime,
            repeatCount: repeatCount,
            repeatUnit: repeatUnit,
            targetDueDate: task.dueDate,
            initialHealthState: task.healthState()
        )
    }
}

// MARK: - File System Observer
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

// MARK: - Actor-Bound Persistence Engine
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

// MARK: - Observable Dashboard Store
@Observable
@MainActor
public final class DashboardStore {
    public var state: DashboardState
    public var activeRightTab: RightPanelTab = .status
    public private(set) var previousRightTab: RightPanelTab = .status
    public var taskDraft: TaskDraft? = nil

    private var watcher: DirectoryWatcher?
    private let persistenceEngine: StatePersistenceEngine
    private var persistTask: Task<Void, Never>?

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

        rolloverRecurringTasksIfNeeded()

        self.watcher = DirectoryWatcher(directoryURL: directoryURL) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let updated = await self.persistenceEngine.evaluateExternalChange() {
                    self.state = updated
                    self.rolloverRecurringTasksIfNeeded()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rolloverRecurringTasksIfNeeded()
            }
        }

        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rolloverRecurringTasksIfNeeded()
            }
        }
    }

    // MARK: - Recurrence Rollover Engine
    public func rolloverRecurringTasksIfNeeded(referenceDate: Date = Date()) {
        let calendar = Calendar.current
        var didMutate = false

        for i in state.tasks.indices {
            guard let recurrence = state.tasks[i].recurrence else { continue }
            guard state.tasks[i].isCompleted, let completedAt = state.tasks[i].lastCompletedAt else { continue }

            if !calendar.isDateInToday(completedAt) {
                state.tasks[i].isCompleted = false
                if !state.tasks[i].isDailyBaseline {
                    let intervalDays = recurrence.intervalDays
                    state.tasks[i].dueDate = calendar.date(byAdding: .day, value: intervalDays, to: completedAt) ?? state.tasks[i].dueDate
                }
                didMutate = true
            }
        }

        if didMutate {
            persistAsync()
        }
    }

    // MARK: - Stateless Projections
    public var baselineTasks: [TaskItem] {
        state.tasks.filter { $0.isDailyBaseline }
    }

    public var baselineTotalMinutes: Int {
        baselineTasks.reduce(0) { $0 + $1.durationMinutes }
    }

    public var focusQueue: [TaskItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return state.tasks.filter { task in
            guard !task.isDailyBaseline else { return false }

            let taskDue = calendar.startOfDay(for: task.dueDate)
            let isOverdueOrDueToday = taskDue <= today

            if task.isCompleted {
                if let completedAt = task.lastCompletedAt {
                    return calendar.isDateInToday(completedAt)
                }
                return isOverdueOrDueToday
            }
            return isOverdueOrDueToday
        }
    }

    public var upcomingEvents: [TaskItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return state.tasks.filter { task in
            guard !task.isDailyBaseline else { return false }
            let taskDue = calendar.startOfDay(for: task.dueDate)
            return taskDue > today && !task.isCompleted
        }
    }

    public var sortedUpcomingEvents: [TaskItem] {
        upcomingEvents.sorted {
            let days0 = $0.estimatedDaysRemaining()
            let days1 = $1.estimatedDaysRemaining()
            if days0 != days1 { return days0 < days1 }
            return $0.title < $1.title
        }
    }

    public var todaySnapshot: TodayOperationalSnapshot {
        let fQueue = focusQueue
        let fTotal = fQueue.count
        let fDone = fQueue.filter { $0.isCompleted }.count
        let fOverdue = fQueue.filter { $0.healthState() == .overdue && !$0.isCompleted }.count
        let fRemaining = fTotal - fDone

        let bTasks = baselineTasks
        let bTotal = bTasks.count
        let bDone = bTasks.filter { $0.isCompleted }.count
        let bRemaining = bTotal - bDone
        let bMinsLeft = bTasks.filter { !$0.isCompleted }.reduce(0) { $0 + $1.durationMinutes }

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

    /// Dynamic Monthly Pacing Telemetry ("Race of the Month")
    public var monthlyPacing: MonthlyPacingSnapshot {
        let calendar = Calendar.current
        let now = Date()

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "LLLL"
        let monthTitle = monthFormatter.string(from: now).uppercased()

        let totalDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = calendar.component(.day, from: now)
        let timeElapsedRatio = min(1.0, Double(currentDay) / Double(totalDays))

        // 1. Calculate Monthly Maintenance Quota (Qm)
        // Excludes 24-hour daily baseline routines to prevent inflating the monthly upkeep bar by 93 tasks.
        var maintenanceQuota: Double = 0
        for task in state.tasks where !task.isDailyBaseline {
            if let recurrence = task.recurrence {
                let intervalDays = max(1, recurrence.intervalDays)
                let runsPerMonth = Double(totalDays) / Double(intervalDays)
                maintenanceQuota += runsPerMonth
            } else {
                maintenanceQuota += 1 // One-time task
            }
        }

        // Fallback for edge cases where the user only has daily baseline tasks
        if maintenanceQuota == 0 {
            maintenanceQuota = Double(max(1, baselineTasks.count * totalDays))
        }

        let totalMonthlyQuota = max(1, Int(round(maintenanceQuota)))

        // 2. Count actual completions logged in the current calendar month
        let completionsThisMonth = state.historyRecords.filter { record in
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .month) &&
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .year)
        }.count

        // 3. Expected maintenance completions based on elapsed time
        let expected = Double(totalMonthlyQuota) * timeElapsedRatio
        let delta = completionsThisMonth - Int(round(expected))

        let actualRatio = min(1.0, Double(completionsThisMonth) / Double(totalMonthlyQuota))

        return MonthlyPacingSnapshot(
            monthTitle: monthTitle,
            currentDay: currentDay,
            totalDaysInMonth: totalDays,
            actualCompleted: completionsThisMonth,
            totalMonthlyQuota: totalMonthlyQuota,
            deltaLead: delta,
            actualProgressRatio: actualRatio,
            expectedProgressRatio: timeElapsedRatio,
            isLeading: delta >= 0
        )
    }

    public var availableTags: [String] {
        var tags = Set<String>()
        for tag in state.customTags { tags.insert(tag) }
        for task in state.tasks { tags.insert(task.tag) }
        for record in state.historyRecords { tags.insert(record.tag) }

        let clean = tags.filter { !$0.isEmpty }.sorted()
        return clean.isEmpty ? ["KITCHEN", "BATHROOM", "GENERAL", "SELF"] : clean
    }

    // MARK: - Navigation Control
    public func selectRightTab(_ tab: RightPanelTab) {
        guard tab != activeRightTab else { return }
        if tab == .create && taskDraft == nil {
            startCreatingTask()
            return
        }
        if activeRightTab != .create && activeRightTab != .edit {
            previousRightTab = activeRightTab
        }
        activeRightTab = tab
    }

    public func dismissDraft() {
        taskDraft = nil
        activeRightTab = previousRightTab
    }

    // MARK: - Draft & Task Modification Actions
    public func startCreatingTask() {
        let defaultTag = availableTags.first ?? "GENERAL"
        taskDraft = TaskDraft(
            id: UUID(),
            isNew: true,
            title: "",
            tag: defaultTag,
            durationMinutes: 15,
            isOneTime: false,
            repeatCount: 1,
            repeatUnit: .week,
            targetDueDate: Date(),
            initialHealthState: .due
        )
        selectRightTab(.create)
    }

    public func startEditing(task: TaskItem) {
        taskDraft = TaskDraft.from(task: task)
        selectRightTab(.edit)
    }

    public func commitDraft() {
        guard let draft = taskDraft else { return }
        let cleanTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTag = draft.tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanTitle.isEmpty, !cleanTag.isEmpty else { return }

        addCustomTag(cleanTag)

        let recurrence: RecurrenceRule? = draft.isOneTime
            ? nil
            : RecurrenceRule(count: draft.repeatCount, unit: draft.repeatUnit)

        let calendar = Calendar.current
        let today = Date()
        let resolvedDueDate: Date

        if draft.isOneTime {
            if draft.initialHealthState == .overdue {
                resolvedDueDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            } else if draft.initialHealthState == .due {
                resolvedDueDate = today
            } else {
                let intervalDays = draft.repeatUnit.days(count: draft.repeatCount)
                resolvedDueDate = calendar.date(byAdding: .day, value: max(1, intervalDays), to: today) ?? today
            }
        } else {
            let computeDateForHealth: (TaskHealthState) -> Date = { health in
                let interval = recurrence?.intervalDays ?? 7
                switch health {
                case .overdue:
                    return calendar.date(byAdding: .day, value: -1, to: today) ?? today
                case .due:
                    return today
                case .halfway:
                    return calendar.date(byAdding: .day, value: max(1, interval / 2), to: today) ?? today
                case .notYet:
                    return calendar.date(byAdding: .day, value: max(1, Int(round(Double(interval) * 0.75))), to: today) ?? today
                case .good:
                    return calendar.date(byAdding: .day, value: max(1, interval), to: today) ?? today
                }
            }

            if draft.isNew {
                resolvedDueDate = computeDateForHealth(draft.initialHealthState)
            } else if let existing = state.tasks.first(where: { $0.id == draft.id }),
                      existing.healthState() == draft.initialHealthState && existing.recurrence == recurrence {
                resolvedDueDate = existing.dueDate
            } else {
                resolvedDueDate = computeDateForHealth(draft.initialHealthState)
            }
        }

        if draft.isNew {
            let newTask = TaskItem(
                id: draft.id,
                title: cleanTitle,
                tag: cleanTag,
                durationMinutes: draft.durationMinutes,
                isCompleted: false,
                dueDate: resolvedDueDate,
                lastCompletedAt: nil,
                recurrence: recurrence
            )
            state.tasks.append(newTask)
        } else {
            if let idx = state.tasks.firstIndex(where: { $0.id == draft.id }) {
                state.tasks[idx].title = cleanTitle
                state.tasks[idx].tag = cleanTag
                state.tasks[idx].durationMinutes = draft.durationMinutes
                state.tasks[idx].recurrence = recurrence
                state.tasks[idx].dueDate = resolvedDueDate
            }
        }

        dismissDraft()
        persistAsync()
    }

    public func deleteTask(id: UUID) {
        state.tasks.removeAll(where: { $0.id == id })
        dismissDraft()
        persistAsync()
    }

    // MARK: - Task Execution & Completion
    public func toggleTask(id: UUID) {
        guard let idx = state.tasks.firstIndex(where: { $0.id == id }) else { return }
        state.tasks[idx].isCompleted.toggle()
        let task = state.tasks[idx]

        if task.isCompleted {
            state.tasks[idx].lastCompletedAt = Date()
            let record = HistoryRecord(
                taskId: task.id,
                title: task.title,
                tag: task.tag,
                completedAt: Date()
            )
            state.historyRecords.insert(record, at: 0)
        } else {
            if let recordIdx = state.historyRecords.firstIndex(where: { $0.taskId == task.id }) {
                state.historyRecords.remove(at: recordIdx)
            }
        }
        persistAsync()
    }

    public func completeHorizonTask(id: UUID) {
        guard let idx = state.tasks.firstIndex(where: { $0.id == id }) else { return }
        let task = state.tasks[idx]

        let record = HistoryRecord(
            taskId: task.id,
            title: task.title,
            tag: task.tag,
            completedAt: Date()
        )
        state.historyRecords.insert(record, at: 0)

        if task.isOneTime {
            state.tasks.remove(at: idx)
        } else {
            let intervalDays = task.recurrence?.intervalDays ?? 7
            let nextDue = Calendar.current.date(byAdding: .day, value: intervalDays, to: Date()) ?? Date()
            state.tasks[idx].dueDate = nextDue
            state.tasks[idx].lastCompletedAt = Date()
            state.tasks[idx].isCompleted = false
        }
        persistAsync()
    }

    /// Resets daily baseline chores and removes today's baseline completions from history.
    public func resetDailyBaseline() {
        let calendar = Calendar.current
        let baselineTaskIds = Set(state.tasks.filter { $0.isDailyBaseline }.map { $0.id })

        // 1. Uncheck baseline chores and clear today's lastCompletedAt
        for idx in state.tasks.indices where state.tasks[idx].isDailyBaseline {
            state.tasks[idx].isCompleted = false
            if let last = state.tasks[idx].lastCompletedAt, calendar.isDateInToday(last) {
                state.tasks[idx].lastCompletedAt = nil
            }
        }

        // 2. Wipe today's history records for these daily baseline tasks
        state.historyRecords.removeAll { record in
            guard let taskId = record.taskId, baselineTaskIds.contains(taskId) else { return false }
            return calendar.isDateInToday(record.completedAt)
        }

        persistAsync()
    }

    // MARK: - Tag Management
    public func addCustomTag(_ tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
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

        for i in state.tasks.indices where state.tasks[i].tag.uppercased() == clean {
            state.tasks[i].tag = fallbackTag
        }
        for i in state.historyRecords.indices where state.historyRecords[i].tag.uppercased() == clean {
            state.historyRecords[i].tag = fallbackTag
        }
        persistAsync()
    }

    public func reloadFromDisk() {
        Task {
            if let reloaded = await persistenceEngine.evaluateExternalChange() {
                self.state = reloaded
                self.rolloverRecurringTasksIfNeeded()
            }
        }
    }

    // MARK: - Data Export
    @MainActor
    public func exportStateToDisk() {
        let panel = NSSavePanel()
        panel.title = "Export Chore Dashboard State"
        panel.prompt = "Export"

        let dateStr = Date().formatted(.iso8601.year().month().day())
        panel.nameFieldStringValue = "ChoreDashboard-state-\(dateStr).json"
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let targetURL = panel.url {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(state)
                try data.write(to: targetURL, options: .atomic)
            } catch {
                print("[DashboardStore] Failed to export state: \(error)")
            }
        }
    }

    // MARK: - Persistence
    private func persistAsync() {
        persistTask?.cancel()
        let snapshot = state
        persistTask = Task { [persistenceEngine] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
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
            print("[DashboardStore] Synchronous load failed: \(error)")
            return nil
        }
    }
}