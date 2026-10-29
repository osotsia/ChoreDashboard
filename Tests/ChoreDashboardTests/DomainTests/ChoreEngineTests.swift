import Testing
import Foundation
@testable import ChoreDashboard

struct DueDateTestCase: Sendable, CustomTestStringConvertible {
    let health: TaskHealthState
    let isOneTime: Bool
    let repeatCount: Int
    let repeatUnit: CadenceUnit
    let expectedDayOffset: Int

    var testDescription: String {
        "Health: \(health.rawValue), OneTime: \(isOneTime), Offset: \(expectedDayOffset)d"
    }
}

@Suite("ChoreEngine State Transitions & Boundary Tests")
struct ChoreEngineTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeClock(year: Int = 2026, month: Int = 5, day: Int = 1) -> TestClock {
        let cal = makeCalendar()
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        let date = cal.date(from: comps)!
        return TestClock(now: date, calendar: cal)
    }

    // MARK: - Toggle Task

    @Test("toggleTask completes an active task and appends a history record")
    func testToggleTaskHappyPath() {
        let clock = makeClock()
        let taskId = UUID()
        let task = TaskItem(id: taskId, title: "Clean Floor", tag: "KITCHEN", isCompleted: false)
        var state = DashboardState(tasks: [task])

        ChoreEngine.toggleTask(state: &state, id: taskId, clock: clock)

        #expect(state.tasks[0].isCompleted == true)
        #expect(state.tasks[0].lastCompletedAt == clock.now)
        #expect(state.historyRecords.count == 1)
        #expect(state.historyRecords[0].taskId == taskId)
        #expect(state.historyRecords[0].completedAt == clock.now)
    }

    @Test("toggleTask uncompletes task and removes associated history record without affecting other records")
    func testToggleTaskUncomplete() {
        let clock = makeClock()
        let taskId = UUID()
        let otherTaskId = UUID()
        let task = TaskItem(id: taskId, title: "Clean Floor", tag: "KITCHEN", isCompleted: true, lastCompletedAt: clock.now)
        let recordToPreserve = HistoryRecord(taskId: otherTaskId, title: "Other", tag: "GENERAL", completedAt: clock.now)
        let recordToRemove = HistoryRecord(taskId: taskId, title: "Clean Floor", tag: "KITCHEN", completedAt: clock.now)
        var state = DashboardState(tasks: [task], historyRecords: [recordToRemove, recordToPreserve])

        ChoreEngine.toggleTask(state: &state, id: taskId, clock: clock)

        #expect(state.tasks[0].isCompleted == false)
        #expect(state.historyRecords.count == 1)
        #expect(state.historyRecords[0].taskId == otherTaskId)
    }

    @Test("toggleTask with non-existent UUID performs no mutations")
    func testToggleTaskNonExistentId() {
        let clock = makeClock()
        let task = TaskItem(title: "Existing", tag: "GENERAL")
        var state = DashboardState(tasks: [task], historyRecords: [])

        ChoreEngine.toggleTask(state: &state, id: UUID(), clock: clock)

        #expect(state.tasks[0].isCompleted == false)
        #expect(state.historyRecords.isEmpty)
    }

    // MARK: - Horizon Completions

    @Test("completeHorizonTask removes one-time task from inventory and records history")
    func testCompleteOneTimeHorizonTask() {
        let clock = makeClock()
        let taskId = UUID()
        let task = TaskItem(id: taskId, title: "Order Filters", tag: "GENERAL", recurrence: nil)
        var state = DashboardState(tasks: [task])

        ChoreEngine.completeHorizonTask(state: &state, id: taskId, clock: clock)

        #expect(state.tasks.isEmpty)
        #expect(state.historyRecords.count == 1)
        #expect(state.historyRecords[0].taskId == taskId)
    }

    @Test("completeHorizonTask advances recurring task due date relative to execution time")
    func testCompleteRecurringHorizonTask() {
        let clock = makeClock()
        let taskId = UUID()
        let task = TaskItem(
            id: taskId,
            title: "Replace Air Filter",
            tag: "GENERAL",
            dueDate: clock.now,
            recurrence: RecurrenceRule(count: 3, unit: .month)
        )
        var state = DashboardState(tasks: [task])

        ChoreEngine.completeHorizonTask(state: &state, id: taskId, clock: clock)

        #expect(state.tasks.count == 1)
        #expect(state.tasks[0].isCompleted == false)
        let expectedDue = clock.calendar.date(byAdding: .day, value: 90, to: clock.now)!
        #expect(state.tasks[0].dueDate == expectedDue)
        #expect(state.tasks[0].lastCompletedAt == clock.now)
    }

    @Test("completeHorizonTask ignores non-existent ID")
    func testCompleteHorizonTaskMissingId() {
        let clock = makeClock()
        var state = DashboardState(tasks: [TaskItem(title: "Task", tag: "GENERAL")])

        ChoreEngine.completeHorizonTask(state: &state, id: UUID(), clock: clock)

        #expect(state.tasks.count == 1)
        #expect(state.historyRecords.isEmpty)
    }

    // MARK: - Baseline Reset

    @Test("resetDailyBaseline resets only tasks completed today and purges today's history")
    func testResetDailyBaselineSelectivity() {
        let cal = makeCalendar()
        let todayClock = makeClock(year: 2026, month: 5, day: 2)
        let yesterday = cal.date(byAdding: .day, value: -1, to: todayClock.now)!

        let b1 = TaskItem(id: UUID(), title: "B1", tag: "SELF", isCompleted: true, lastCompletedAt: todayClock.now, recurrence: RecurrenceRule(count: 1, unit: .day))
        let b2 = TaskItem(id: UUID(), title: "B2", tag: "SELF", isCompleted: true, lastCompletedAt: yesterday, recurrence: RecurrenceRule(count: 1, unit: .day))
        let focus = TaskItem(id: UUID(), title: "Focus", tag: "KITCHEN", isCompleted: true, lastCompletedAt: todayClock.now, recurrence: RecurrenceRule(count: 1, unit: .week))

        var state = DashboardState(
            tasks: [b1, b2, focus],
            historyRecords: [
                HistoryRecord(taskId: b1.id, title: "B1", tag: "SELF", completedAt: todayClock.now),
                HistoryRecord(taskId: b2.id, title: "B2", tag: "SELF", completedAt: yesterday),
                HistoryRecord(taskId: focus.id, title: "Focus", tag: "KITCHEN", completedAt: todayClock.now)
            ]
        )

        ChoreEngine.resetDailyBaseline(state: &state, clock: todayClock)

        #expect(state.tasks[0].isCompleted == false)
        #expect(state.tasks[0].lastCompletedAt == nil)

        #expect(state.tasks[1].isCompleted == false)
        #expect(state.tasks[1].lastCompletedAt == yesterday)

        #expect(state.tasks[2].isCompleted == true)

        #expect(state.historyRecords.count == 2)
        #expect(!state.historyRecords.contains(where: { $0.taskId == b1.id }))
        #expect(state.historyRecords.contains(where: { $0.taskId == b2.id }))
        #expect(state.historyRecords.contains(where: { $0.taskId == focus.id }))
    }

    // MARK: - Upsert & Delete

    @Test("upsertTask inserts new task, appends to task array, and registers its tag")
    func testUpsertTaskNew() {
        var state = DashboardState(tasks: [], customTags: ["GENERAL"])
        let newTask = TaskItem(title: "Scrub Drain", tag: "PLUMBING")

        ChoreEngine.upsertTask(state: &state, task: newTask)

        #expect(state.tasks.count == 1)
        #expect(state.tasks[0].id == newTask.id)
        #expect(state.tasks[0].title == "Scrub Drain")
        #expect(state.customTags.contains("PLUMBING"))
    }

    @Test("upsertTask updates an existing task in place without duplicating")
    func testUpsertTaskExisting() {
        let existingId = UUID()
        let original = TaskItem(id: existingId, title: "Old Title", tag: "GENERAL", durationMinutes: 10)
        var state = DashboardState(tasks: [original], customTags: ["GENERAL"])

        var modified = original
        modified.title = "New Title"
        modified.durationMinutes = 25

        ChoreEngine.upsertTask(state: &state, task: modified)

        #expect(state.tasks.count == 1)
        #expect(state.tasks[0].id == existingId)
        #expect(state.tasks[0].title == "New Title")
        #expect(state.tasks[0].durationMinutes == 25)
    }

    @Test("deleteTask removes target task by ID and leaves non-matching tasks intact")
    func testDeleteTask() {
        let id1 = UUID()
        let id2 = UUID()
        let task1 = TaskItem(id: id1, title: "T1", tag: "GENERAL")
        let task2 = TaskItem(id: id2, title: "T2", tag: "GENERAL")
        var state = DashboardState(tasks: [task1, task2])

        ChoreEngine.deleteTask(state: &state, id: id1)
        #expect(state.tasks.count == 1)
        #expect(state.tasks[0].id == id2)

        ChoreEngine.deleteTask(state: &state, id: UUID())
        #expect(state.tasks.count == 1)
        #expect(state.tasks[0].id == id2)
    }

    @Test("clearAllData purges all tasks, history records, and custom tags while resetting trackingStartDate")
    func testClearAllData() {
        let clock = makeClock()
        let task = TaskItem(title: "Task", tag: "GENERAL")
        let record = HistoryRecord(title: "Record", tag: "GENERAL")
        var state = DashboardState(tasks: [task], historyRecords: [record], customTags: ["GENERAL", "CUSTOM"])

        ChoreEngine.clearAllData(state: &state, clock: clock)

        #expect(state.tasks.isEmpty)
        #expect(state.historyRecords.isEmpty)
        #expect(state.customTags.isEmpty)
        #expect(state.trackingStartDate == clock.now)
    }

    // MARK: - Tag Management & Deduplication

    @Test("isValidTag evaluates formatting rules and rejects punctuation characters")
    func testIsValidTagValidation() {
        #expect(ChoreEngine.isValidTag("VALID") == true)
        #expect(ChoreEngine.isValidTag("DEEP CLEAN") == true)
        #expect(ChoreEngine.isValidTag("") == false)
        #expect(ChoreEngine.isValidTag("   ") == false)
        #expect(ChoreEngine.isValidTag("TAG·WITH·DOT") == false)
        #expect(ChoreEngine.isValidTag("TAG,WITH,COMMA") == false)
    }

    @Test("addCustomTag sanitizes whitespace, uppercases, prevents duplicates, and ignores invalid strings")
    func testAddCustomTagSanitization() {
        var state = DashboardState(customTags: ["EXISTING"])

        ChoreEngine.addCustomTag(state: &state, tag: "  new_tag  \n")
        ChoreEngine.addCustomTag(state: &state, tag: "EXISTING")
        ChoreEngine.addCustomTag(state: &state, tag: "   ")
        ChoreEngine.addCustomTag(state: &state, tag: "INVALID·TAG")

        #expect(state.customTags.count == 2)
        #expect(state.customTags.contains("NEW_TAG"))
        #expect(!state.customTags.contains("INVALID·TAG"))
    }

    @Test("deleteTag reassigns tasks and history; uses OPERATIONS when GENERAL is deleted and updates customTags")
    func testDeleteTagFallbackRouting() {
        let taskGeneral = TaskItem(title: "T1", tag: "GENERAL")
        let historyGeneral = HistoryRecord(title: "H1", tag: "GENERAL")
        let taskCustom = TaskItem(title: "T2", tag: "CUSTOM")
        let historyCustom = HistoryRecord(title: "H2", tag: "CUSTOM")

        var state = DashboardState(
            tasks: [taskGeneral, taskCustom],
            historyRecords: [historyGeneral, historyCustom],
            customTags: ["GENERAL", "CUSTOM"]
        )

        ChoreEngine.deleteTag(state: &state, tag: "CUSTOM")
        #expect(!state.customTags.contains("CUSTOM"))
        #expect(state.customTags.contains("GENERAL"))
        #expect(state.tasks[1].tag == "GENERAL")
        #expect(state.historyRecords[1].tag == "GENERAL")

        ChoreEngine.deleteTag(state: &state, tag: "GENERAL")
        #expect(!state.customTags.contains("GENERAL"))
        #expect(state.customTags.contains("OPERATIONS"))
        #expect(state.tasks[0].tag == "OPERATIONS")
        #expect(state.historyRecords[0].tag == "OPERATIONS")
    }

    // MARK: - Parameterized Calculate Due Date Heuristics

    @Test(
        "calculateDueDate accurately projects dates across health states and cadences",
        arguments: [
            DueDateTestCase(health: .overdue, isOneTime: true, repeatCount: 1, repeatUnit: .day, expectedDayOffset: -1),
            DueDateTestCase(health: .due, isOneTime: true, repeatCount: 1, repeatUnit: .day, expectedDayOffset: 0),
            DueDateTestCase(health: .good, isOneTime: true, repeatCount: 2, repeatUnit: .week, expectedDayOffset: 14),
            DueDateTestCase(health: .overdue, isOneTime: false, repeatCount: 20, repeatUnit: .day, expectedDayOffset: -1),
            DueDateTestCase(health: .due, isOneTime: false, repeatCount: 20, repeatUnit: .day, expectedDayOffset: 0),
            DueDateTestCase(health: .halfway, isOneTime: false, repeatCount: 20, repeatUnit: .day, expectedDayOffset: 10),
            DueDateTestCase(health: .notYet, isOneTime: false, repeatCount: 20, repeatUnit: .day, expectedDayOffset: 15),
            DueDateTestCase(health: .good, isOneTime: false, repeatCount: 20, repeatUnit: .day, expectedDayOffset: 20)
        ]
    )
    func testCalculateDueDateBranches(testCase: DueDateTestCase) {
        let cal = makeCalendar()
        let clock = makeClock(year: 2026, month: 5, day: 10)
        let recurrence = testCase.isOneTime ? nil : RecurrenceRule(count: testCase.repeatCount, unit: testCase.repeatUnit)

        let calculatedDate = ChoreEngine.calculateDueDate(
            health: testCase.health,
            recurrence: recurrence,
            isOneTime: testCase.isOneTime,
            repeatCount: testCase.repeatCount,
            repeatUnit: testCase.repeatUnit,
            clock: clock
        )

        let offset = cal.dateComponents([.day], from: clock.now, to: calculatedDate).day ?? 0
        #expect(offset == testCase.expectedDayOffset)
    }

    @Test("calculateDueDate handles minimal single-day cadence intervals gracefully")
    func testCalculateDueDateMinimalIntervalDefense() {
        let cal = makeCalendar()
        let clock = makeClock(year: 2026, month: 5, day: 10)
        let singleDayRecurrence = RecurrenceRule(count: 1, unit: .day)

        let recHalf = ChoreEngine.calculateDueDate(health: .halfway, recurrence: singleDayRecurrence, isOneTime: false, repeatCount: 1, repeatUnit: .day, clock: clock)
        #expect(cal.dateComponents([.day], from: clock.now, to: recHalf).day == 1)

        let recNotYet = ChoreEngine.calculateDueDate(health: .notYet, recurrence: singleDayRecurrence, isOneTime: false, repeatCount: 1, repeatUnit: .day, clock: clock)
        #expect(cal.dateComponents([.day], from: clock.now, to: recNotYet).day == 1)
    }

    // MARK: - Fine-Grained Runway Ratio Calculations

    @Test("calculateDueDate with runwayRatio correctly scales target date across entire unit interval")
    func testCalculateDueDateFromRunwayRatio() {
        let cal = makeCalendar()
        let clock = makeClock(year: 2026, month: 5, day: 10)
        let recurrence = RecurrenceRule(count: 20, unit: .day) // 20-day interval

        // 1. Full 100% Runway -> +20 days
        let date100 = ChoreEngine.calculateDueDate(runwayRatio: 1.0, isOverdue: false, recurrence: recurrence, isOneTime: false, repeatCount: 20, repeatUnit: .day, clock: clock)
        #expect(cal.dateComponents([.day], from: clock.now, to: date100).day == 20)

        // 2. 50% Runway -> +10 days
        let date50 = ChoreEngine.calculateDueDate(runwayRatio: 0.5, isOverdue: false, recurrence: recurrence, isOneTime: false, repeatCount: 20, repeatUnit: .day, clock: clock)
        #expect(cal.dateComponents([.day], from: clock.now, to: date50).day == 10)

        // 3. 0% Runway (Due Today) -> +0 days
        let date0 = ChoreEngine.calculateDueDate(runwayRatio: 0.0, isOverdue: false, recurrence: recurrence, isOneTime: false, repeatCount: 20, repeatUnit: .day, clock: clock)
        #expect(cal.dateComponents([.day], from: clock.now, to: date0).day == 0)

        // 4. Overdue Decay Hazard -> -1 day
        let dateOverdue = ChoreEngine.calculateDueDate(runwayRatio: 0.5, isOverdue: true, recurrence: recurrence, isOneTime: false, repeatCount: 20, repeatUnit: .day, clock: clock)
        #expect(cal.dateComponents([.day], from: clock.now, to: dateOverdue).day == -1)
    }

    @Test("healthState projection accurately categorizes fine-grained runway ratios")
    func testHealthStateFromRunwayRatio() {
        #expect(ChoreEngine.healthState(for: 1.0, isOverdue: false) == .good)
        #expect(ChoreEngine.healthState(for: 0.85, isOverdue: false) == .good)
        #expect(ChoreEngine.healthState(for: 0.84, isOverdue: false) == .notYet)
        #expect(ChoreEngine.healthState(for: 0.60, isOverdue: false) == .notYet)
        #expect(ChoreEngine.healthState(for: 0.59, isOverdue: false) == .halfway)
        #expect(ChoreEngine.healthState(for: 0.35, isOverdue: false) == .halfway)
        #expect(ChoreEngine.healthState(for: 0.34, isOverdue: false) == .due)
        #expect(ChoreEngine.healthState(for: 0.0, isOverdue: false) == .due)
        #expect(ChoreEngine.healthState(for: 0.9, isOverdue: true) == .overdue)
    }
}