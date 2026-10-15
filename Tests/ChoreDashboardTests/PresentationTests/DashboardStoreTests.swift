import Testing
import Foundation
@testable import ChoreDashboard

@Suite("DashboardStore Coordinator & Draft State Tests")
@MainActor
struct DashboardStoreTests {

    private func makeStore(tasks: [TaskItem] = []) -> (DashboardStore, InMemoryPersistenceClient, TestClock) {
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 1
        comps.hour = 12
        let clock = TestClock(now: cal.date(from: comps)!, calendar: cal)

        let mockStorage = InMemoryPersistenceClient(initialState: DashboardState(tasks: tasks))
        let store = DashboardStore(
            initialState: DashboardState(tasks: tasks),
            persistenceClient: mockStorage,
            clock: clock,
            enableSystemIntegration: false
        )
        return (store, mockStorage, clock)
    }

    // MARK: - Navigation & Draft Lifecycles

    @Test("Tab switching tracks previous tab and restores it upon dismissDraft")
    func testNavigationAndDraftDismissal() {
        let (store, _, _) = makeStore()

        store.selectRightTab(.backlog)
        store.startCreatingTask()
        #expect(store.activeRightTab == .create)
        #expect(store.previousRightTab == .backlog)

        store.dismissDraft()
        #expect(store.activeRightTab == .backlog)
        #expect(store.taskDraft == nil)
    }

    @Test("commitDraft commits valid draft and dismisses editor")
    func testCommitDraftHappyPath() {
        let (store, _, _) = makeStore()

        store.startCreatingTask()
        store.taskDraft?.title = "Wipe Baseboards"
        store.taskDraft?.tag = "GENERAL"

        store.commitDraft()

        #expect(store.state.tasks.count == 1)
        #expect(store.state.tasks[0].title == "Wipe Baseboards")
        #expect(store.state.tasks[0].tag == "GENERAL")
        #expect(store.taskDraft == nil)
        #expect(store.activeRightTab == .status)
    }

    @Test("commitDraft rejects empty or whitespace-only inputs without state mutation")
    func testCommitDraftRejection() {
        let (store, _, _) = makeStore()

        store.startCreatingTask()
        store.taskDraft?.title = "    "
        store.taskDraft?.tag = "GENERAL"

        store.commitDraft()
        #expect(store.state.tasks.isEmpty)
        #expect(store.taskDraft != nil)

        store.taskDraft?.title = "Valid Title"
        store.taskDraft?.tag = "   "

        store.commitDraft()
        #expect(store.state.tasks.isEmpty)
        #expect(store.taskDraft != nil)
    }

    @Test("TaskDraft.from correctly infers cadences from one-time horizon tasks")
    func testTaskDraftInferenceFromOneTimeTask() {
        let cal = Calendar.current
        let clock = TestClock(now: Date())

        let date60 = cal.date(byAdding: .day, value: 60, to: clock.now)!
        let task60 = TaskItem(title: "T60", tag: "GENERAL", dueDate: date60, recurrence: nil)
        let draft60 = TaskDraft.from(task: task60, clock: clock)

        #expect(draft60.isOneTime == true)
        #expect(draft60.repeatUnit == .month)
        #expect(draft60.repeatCount == 2)

        let date14 = cal.date(byAdding: .day, value: 14, to: clock.now)!
        let task14 = TaskItem(title: "T14", tag: "GENERAL", dueDate: date14, recurrence: nil)
        let draft14 = TaskDraft.from(task: task14, clock: clock)

        #expect(draft14.isOneTime == true)
        #expect(draft14.repeatUnit == .week)
        #expect(draft14.repeatCount == 2)

        let date5 = cal.date(byAdding: .day, value: 5, to: clock.now)!
        let task5 = TaskItem(title: "T5", tag: "GENERAL", dueDate: date5, recurrence: nil)
        let draft5 = TaskDraft.from(task: task5, clock: clock)

        #expect(draft5.isOneTime == true)
        #expect(draft5.repeatUnit == .day)
        #expect(draft5.repeatCount == 5)
    }

    @Test("TaskDraft.from falls back to 1 Day for overdue one-time tasks")
    func testTaskDraftInferenceFromOverdueTask() {
        let cal = Calendar.current
        let clock = TestClock(now: Date())

        let overdueDate = cal.date(byAdding: .day, value: -7, to: clock.now)!
        let overdueTask = TaskItem(title: "Overdue Item", tag: "GENERAL", dueDate: overdueDate, recurrence: nil)
        let draft = TaskDraft.from(task: overdueTask, clock: clock)

        #expect(draft.isOneTime == true)
        #expect(draft.repeatCount == 1)
        #expect(draft.repeatUnit == .day)
        #expect(draft.initialHealthState == .overdue)
    }

    @Test("Editing task without health state change preserves existing due date")
    func testEditingPreservesDueDateWhenHealthUnchanged() {
        let (store, _, clock) = makeStore()
        let originalDue = clock.calendar.date(byAdding: .day, value: 5, to: clock.now)!
        let task = TaskItem(
            title: "Existing Task",
            tag: "GENERAL",
            dueDate: originalDue,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )
        store.state.tasks = [task]

        store.startEditing(task: task)
        store.taskDraft?.title = "Updated Title"
        store.commitDraft()

        #expect(store.state.tasks.count == 1)
        #expect(store.state.tasks[0].title == "Updated Title")
        #expect(store.state.tasks[0].dueDate == originalDue)
    }

    @Test("Editing task with health state modification recalculates target due date")
    func testEditingRecalculatesDueDateWhenHealthModified() {
        let (store, _, clock) = makeStore()
        let futureDue = clock.calendar.date(byAdding: .day, value: 14, to: clock.now)!
        let task = TaskItem(
            title: "Existing Task",
            tag: "GENERAL",
            dueDate: futureDue,
            recurrence: RecurrenceRule(count: 2, unit: .week)
        )
        store.state.tasks = [task]

        store.startEditing(task: task)
        store.taskDraft?.initialHealthState = .due
        store.commitDraft()

        #expect(store.state.tasks.count == 1)
        #expect(clock.calendar.isDate(store.state.tasks[0].dueDate, inSameDayAs: clock.now))
    }

    // MARK: - Store Mutators & Concurrency Race Mitigation

    @Test("Store mutators correctly execute domain transformations on state")
    func testStoreMutatorsForwarding() {
        let taskId = UUID()
        let task = TaskItem(id: taskId, title: "Initial Task", tag: "GENERAL", isCompleted: false)
        let (store, _, _) = makeStore(tasks: [task])

        store.toggleTask(id: taskId)
        #expect(store.state.tasks[0].isCompleted == true)
        #expect(store.state.historyRecords.count == 1)

        store.completeHorizonTask(id: taskId)
        #expect(store.state.tasks[0].isCompleted == false)
        #expect(store.state.historyRecords.count == 2)

        store.addCustomTag("INSPECTION")
        #expect(store.state.customTags.contains("INSPECTION"))

        store.deleteTag("INSPECTION")
        #expect(!store.state.customTags.contains("INSPECTION"))

        store.deleteTask(id: taskId)
        #expect(store.state.tasks.isEmpty)
    }

    @Test("resetDailyBaseline resets completed baseline chores and history records via store")
    func testStoreResetDailyBaseline() {
        let (store, _, clock) = makeStore()
        let baseline = TaskItem(
            title: "Stretch",
            tag: "SELF",
            isCompleted: true,
            lastCompletedAt: clock.now,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )
        store.state.tasks = [baseline]
        store.state.historyRecords = [
            HistoryRecord(taskId: baseline.id, title: "Stretch", tag: "SELF", completedAt: clock.now)
        ]

        store.resetDailyBaseline()

        #expect(store.state.tasks[0].isCompleted == false)
        #expect(store.state.historyRecords.isEmpty)
    }

    @Test("persistAsync debounces rapid sequential operations into a single deterministic save")
    func testPersistAsyncDebouncing() async throws {
        let (store, mockStorage, _) = makeStore()

        store.addCustomTag("TAG1")
        store.addCustomTag("TAG2")
        store.addCustomTag("TAG3")

        await store.flushPersistTask()

        let saveCount = await mockStorage.saveCount
        #expect(saveCount == 1)
        let savedTags = await mockStorage.storedState?.customTags ?? []
        #expect(savedTags.contains("TAG1"))
        #expect(savedTags.contains("TAG2"))
        #expect(savedTags.contains("TAG3"))
    }

    @Test("External reload cancels in-flight debounce to prevent clobbering external state")
    func testExternalReloadCancelsInFlightDebounce() async throws {
        let (store, mockStorage, _) = makeStore()

        store.addCustomTag("LOCAL_MUTATION")

        var externalState = store.state
        externalState.tasks.append(TaskItem(title: "External Insert", tag: "EXTERNAL"))
        await mockStorage.stageExternalChange(externalState)

        await store.reloadFromDisk().value
        await store.flushPersistTask()

        #expect(store.state.tasks.contains(where: { $0.title == "External Insert" }))
    }

    @Test("exportState writes valid serialized JSON to a designated file URL")
    func testExportStateWritesValidJSON() throws {
        let (store, _, _) = makeStore()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("export-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try store.exportState(to: tempURL)

        let data = try Data(contentsOf: tempURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DashboardState.self, from: data)

        #expect(decoded == store.state)
    }

    @Test("Persistence throw does not crash store or corrupt in-memory state")
    func testPersistenceFailureDoesNotCorruptStoreState() async {
        let (store, mockStorage, _) = makeStore()
        await mockStorage.setShouldThrowOnSave(true)

        store.addCustomTag("TEST_TAG")
        await store.flushPersistTask()

        #expect(store.state.customTags.contains("TEST_TAG"))
    }

    @Test("commitDraft recovers when target task was deleted externally during draft session")
    func testCommitDraftWhenTaskDeletedExternally() {
        let taskId = UUID()
        let initialTask = TaskItem(id: taskId, title: "Original", tag: "GENERAL")
        let (store, _, _) = makeStore(tasks: [initialTask])

        store.startEditing(task: initialTask)
        store.deleteTask(id: taskId)
        #expect(store.state.tasks.isEmpty)

        store.startEditing(task: initialTask)
        store.taskDraft?.title = "Recreated"
        store.commitDraft()

        #expect(store.state.tasks.count == 1)
        #expect(store.state.tasks[0].id == taskId)
        #expect(store.state.tasks[0].title == "Recreated")
    }
}