import SwiftUI
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
public final class DashboardStore {
    // MARK: - State
    public var state: DashboardState
    public var activeRightTab: RightPanelTab = .status
    public private(set) var previousRightTab: RightPanelTab = .status
    public var taskDraft: TaskDraft? = nil

    // MARK: - Injected Dependencies
    public let clock: Clock
    private let persistenceClient: any PersistenceClient
    private var watcher: DirectoryWatcher?
    private var persistTask: Task<Void, Never>?

    // MARK: - Initializer
    public init(
        initialState: DashboardState? = nil,
        persistenceClient: (any PersistenceClient)? = nil,
        clock: Clock = SystemClock(),
        enableSystemIntegration: Bool = true
    ) {
        self.clock = clock

        let storageURL = AppConfig.storageURL
        let resolvedClient = persistenceClient ?? FilePersistenceClient(storageURL: storageURL)
        self.persistenceClient = resolvedClient

        if let explicit = initialState {
            self.state = explicit
        } else if let loaded = FilePersistenceClient.loadInitialBlocking(from: storageURL) {
            self.state = loaded
        } else {
            var fallback = PreviewData.defaultState
            if fallback.trackingStartDate == nil {
                fallback.trackingStartDate = clock.now
            }
            self.state = fallback
            Task { try? await resolvedClient.save(fallback) }
        }

        rolloverRecurringTasksIfNeeded()

        guard enableSystemIntegration else { return }

        let directoryURL = AppConfig.storageDirectory
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        self.watcher = DirectoryWatcher(directoryURL: directoryURL) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let updated = try? await self.persistenceClient.evaluateExternalChange() {
                    self.persistTask?.cancel()
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

    // MARK: - Domain Rollover
    public func rolloverRecurringTasksIfNeeded() {
        if ChoreEngine.rollover(state: &state, clock: clock) {
            persistAsync()
        }
    }

    // MARK: - Stateless Projections
    public var baselineTasks: [TaskItem] { ChoreProjections.baselineTasks(for: state) }
    public var baselineTotalMinutes: Int { ChoreProjections.baselineTotalMinutes(for: state) }
    public var focusQueue: [TaskItem] { ChoreProjections.focusQueue(for: state, clock: clock) }
    public var upcomingEvents: [TaskItem] { ChoreProjections.upcomingEvents(for: state, clock: clock) }
    public var sortedUpcomingEvents: [TaskItem] { ChoreProjections.sortedUpcomingEvents(for: state, clock: clock) }
    public var todaySnapshot: TodayOperationalSnapshot { ChoreProjections.todaySnapshot(for: state, clock: clock) }
    public var monthlyPacing: MonthlyPacingSnapshot { ChoreProjections.monthlyPacing(for: state, clock: clock) }
    public var baselineCompliance: BaselineComplianceSnapshot { ChoreProjections.baselineCompliance(for: state, clock: clock) }
    public var availableTags: [String] { ChoreProjections.availableTags(for: state) }

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

    // MARK: - Task Form Operations
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
            targetDueDate: clock.now,
            initialHealthState: .due,
            isCompleted: false,
            lastCompletedAt: nil
        )
        selectRightTab(.create)
    }

    public func startEditing(task: TaskItem) {
        taskDraft = TaskDraft.from(task: task, clock: clock)
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
            isCompleted: draft.isCompleted,
            dueDate: resolvedDueDate,
            lastCompletedAt: draft.lastCompletedAt,
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

    // MARK: - Task Execution & Mutators
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

    public func addCustomTag(_ tag: String) {
        ChoreEngine.addCustomTag(state: &state, tag: tag)
        persistAsync()
    }

    public func deleteTag(_ tag: String) {
        ChoreEngine.deleteTag(state: &state, tag: tag)
        persistAsync()
    }

    @discardableResult
    public func reloadFromDisk() -> Task<Void, Never> {
        Task {
            let reloaded: DashboardState?
            if let external = try? await persistenceClient.evaluateExternalChange() {
                reloaded = external
            } else {
                reloaded = try? await persistenceClient.load()
            }

            if let reloaded = reloaded {
                self.persistTask?.cancel()
                self.state = reloaded
                self.rolloverRecurringTasksIfNeeded()
            }
        }
    }

    // MARK: - Data Export
    public func exportState(to targetURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: targetURL, options: .atomic)
    }

    @MainActor
    public func exportStateToDisk() {
        let panel = NSSavePanel()
        panel.title = "Export Chore Dashboard State"
        panel.prompt = "Export"

        let dateStr = clock.now.formatted(.iso8601.year().month().day())
        panel.nameFieldStringValue = "ChoreDashboard-state-\(dateStr).json"
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let targetURL = panel.url {
            do {
                try exportState(to: targetURL)
            } catch {
                print("[DashboardStore] Export failed: \(error)")
            }
        }
    }

    // MARK: - Async Persistence Dispatch
    public func flushPersistTask() async {
        await persistTask?.value
    }

    private func persistAsync() {
        persistTask?.cancel()
        let snapshot = state
        persistTask = Task { [persistenceClient] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await persistenceClient.save(snapshot)
        }
    }
}