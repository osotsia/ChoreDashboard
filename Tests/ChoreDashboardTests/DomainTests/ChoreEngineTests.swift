import Testing
import Foundation
@testable import ChoreDashboard

@Suite("ChoreEngine Mutation Tests")
struct ChoreEngineTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeClock() -> TestClock {
        let date = Date(timeIntervalSince1970: 1777636800) // 2026-05-01 12:00:00 UTC
        return TestClock(now: date, calendar: makeCalendar())
    }

    @Test("toggleTask toggles completion and manages history entries")
    func testToggleTask() {
        let clock = makeClock()
        let taskId = UUID()
        let task = TaskItem(id: taskId, title: "Clean Floor", tag: "KITCHEN", isCompleted: false)
        var state = DashboardState(tasks: [task])

        // First toggle: completes task, inserts history
        ChoreEngine.toggleTask(state: &state, id: taskId, clock: clock)
        #expect(state.tasks[0].isCompleted == true)
        #expect(state.tasks[0].lastCompletedAt == clock.now)
        #expect(state.historyRecords.count == 1)
        #expect(state.historyRecords[0].taskId == taskId)

        // Second toggle: uncompletes task, removes history
        ChoreEngine.toggleTask(state: &state, id: taskId, clock: clock)
        #expect(state.tasks[0].isCompleted == false)
        #expect(state.historyRecords.isEmpty)
    }

    @Test("completeHorizonTask removes one-time tasks and logs history")
    func testCompleteOneTimeHorizonTask() {
        let clock = makeClock()
        let taskId = UUID()
        let task = TaskItem(id: taskId, title: "Buy Filter", tag: "GENERAL", recurrence: nil)
        var state = DashboardState(tasks: [task])

        ChoreEngine.completeHorizonTask(state: &state, id: taskId, clock: clock)
        #expect(state.tasks.isEmpty)
        #expect(state.historyRecords.count == 1)
        #expect(state.historyRecords[0].taskId == taskId)
    }

    @Test("completeHorizonTask advances recurring task due date by recurrence interval")
    func testCompleteRecurringHorizonTask() {
        let clock = makeClock()
        let taskId = UUID()
        let task = TaskItem(
            id: taskId,
            title: "Replace Filter",
            tag: "GENERAL",
            recurrence: RecurrenceRule(count: 2, unit: .week)
        )
        var state = DashboardState(tasks: [task])

        ChoreEngine.completeHorizonTask(state: &state, id: taskId, clock: clock)
        #expect(state.tasks.count == 1)
        #expect(state.tasks[0].isCompleted == false)
        let expectedDue = clock.calendar.date(byAdding: .day, value: 14, to: clock.now)!
        #expect(state.tasks[0].dueDate == expectedDue)
        #expect(state.historyRecords.count == 1)
    }

    @Test("resetDailyBaseline unchecks baseline tasks and removes today's records")
    func testResetDailyBaseline() {
        let clock = makeClock()
        let baselineId = UUID()
        let focusId = UUID()

        let baselineTask = TaskItem(
            id: baselineId,
            title: "Morning Stretch",
            tag: "SELF",
            isCompleted: true,
            lastCompletedAt: clock.now,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )
        let focusTask = TaskItem(
            id: focusId,
            title: "Deep Clean",
            tag: "KITCHEN",
            isCompleted: true,
            lastCompletedAt: clock.now,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )

        var state = DashboardState(
            tasks: [baselineTask, focusTask],
            historyRecords: [
                HistoryRecord(taskId: baselineId, title: "Morning Stretch", tag: "SELF", completedAt: clock.now),
                HistoryRecord(taskId: focusId, title: "Deep Clean", tag: "KITCHEN", completedAt: clock.now)
            ]
        )

        ChoreEngine.resetDailyBaseline(state: &state, clock: clock)

        #expect(state.tasks[0].isCompleted == false)
        #expect(state.tasks[0].lastCompletedAt == nil)
        // Focus task must remain unaffected
        #expect(state.tasks[1].isCompleted == true)
        // History: only focus record survives
        #expect(state.historyRecords.count == 1)
        #expect(state.historyRecords[0].taskId == focusId)
    }

    @Test("deleteTag reassigns referencing tasks and history to fallback tag")
    func testDeleteTagCascadesFallback() {
        let taskId = UUID()
        let task = TaskItem(id: taskId, title: "Special Job", tag: "CUSTOM")
        let history = HistoryRecord(taskId: taskId, title: "Special Job", tag: "CUSTOM")
        var state = DashboardState(tasks: [task], historyRecords: [history], customTags: ["CUSTOM"])

        ChoreEngine.deleteTag(state: &state, tag: "CUSTOM")

        #expect(!state.customTags.contains("CUSTOM"))
        #expect(state.tasks[0].tag == "GENERAL")
        #expect(state.historyRecords[0].tag == "GENERAL")
    }
}