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

    private let clock: Clock = SystemClock()
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
    public func rolloverRecurringTasksIfNeeded() {
        if ChoreEngine.rollover(state: &state, clock: clock) {
            persistAsync()
        }
    }

    // MARK: - Stateless Projections
    public var baselineTasks: [TaskItem] {
        ChoreProjections.baselineTasks(for: state)
    }

    public var baselineTotalMinutes: Int {
        ChoreProjections.baselineTotalMinutes(for: state)
    }

    public var focusQueue: [TaskItem] {
        ChoreProjections.focusQueue(for: state, clock: clock)
    }

    public var upcomingEvents: [TaskItem] {
        ChoreProjections.upcomingEvents(for: state, clock: clock)
    }

    public var sortedUpcomingEvents: [TaskItem] {
        ChoreProjections.sortedUpcomingEvents(for: state, clock: clock)
    }

    public var todaySnapshot: TodayOperationalSnapshot {
        ChoreProjections.todaySnapshot(for: state, clock: clock)
    }

    public var monthlyPacing: MonthlyPacingSnapshot {
        ChoreProjections.monthlyPacing(for: state, clock: clock)
    }

    public var availableTags: [String] {
        ChoreProjections.availableTags(for: state)
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

        let recurrence: RecurrenceRule? = draft.isOneTime
            ? nil
            : RecurrenceRule(count: draft.repeatCount, unit: draft.repeatUnit)

        let resolvedDueDate: Date
        if !draft.isNew,
           let existing = state.tasks.first(where: { $0.id == draft.id }),
           existing.healthState(using: clock) == draft.initialHealthState && existing.recurrence == recurrence {
            resolvedDueDate = existing.dueDate
        } else {
            resolvedDueDate = ChoreEngine.calculateDueDate(
                health: draft.initialHealthState,
                recurrence: recurrence,
                isOneTime: draft.isOneTime,
                repeatCount: draft.repeatCount,
                repeatUnit: draft.repeatUnit,
                clock: clock
            )
        }

        let task = TaskItem(
            id: draft.id,
            title: cleanTitle,
            tag: cleanTag,
            durationMinutes: draft.durationMinutes,
            isCompleted: false,
            dueDate: resolvedDueDate,
            lastCompletedAt: nil,
            recurrence: recurrence
        )

        ChoreEngine.upsertTask(state: &state, task: task)
        dismissDraft()
        persistAsync()
    }

    public func deleteTask(id: UUID) {
        ChoreEngine.deleteTask(state: &state, id: id)
        dismissDraft()
        persistAsync()
    }

    // MARK: - Task Execution & Completion
    public func toggleTask(id: UUID) {
        ChoreEngine.toggleTask(state: &state, id: id, clock: clock)
        persistAsync()
    }

    public func completeHorizonTask(id: UUID) {
        ChoreEngine.completeHorizonTask(state: &state, id: id, clock: clock)
        persistAsync()
    }

    public func resetDailyBaseline() {
        ChoreEngine.resetDailyBaseline(state: &state, clock: clock)
        persistAsync()
    }

    // MARK: - Tag Management
    public func addCustomTag(_ tag: String) {
        ChoreEngine.addCustomTag(state: &state, tag: tag)
        persistAsync()
    }

    public func deleteTag(_ tag: String) {
        ChoreEngine.deleteTag(state: &state, tag: tag)
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