import Testing
import Foundation
@testable import ChoreDashboard

@Suite("Midnight Rollover Transition Invariants")
struct RolloverTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    @Test("Rollover uncompletes tasks completed on prior days and advances recurring due dates")
    func testRolloverAdvancesPastTasks() {
        let cal = makeCalendar()
        let day1 = Date(timeIntervalSince1970: 1777636800) // 2026-05-01 12:00:00 UTC
        var clock = TestClock(now: day1, calendar: cal)

        let recurringId = UUID()
        let baselineId = UUID()

        let recurringTask = TaskItem(
            id: recurringId,
            title: "Weekly Scrub",
            tag: "KITCHEN",
            isCompleted: true,
            dueDate: day1,
            lastCompletedAt: day1,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )

        let baselineTask = TaskItem(
            id: baselineId,
            title: "Daily Habit",
            tag: "SELF",
            isCompleted: true,
            dueDate: day1,
            lastCompletedAt: day1,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )

        var state = DashboardState(tasks: [recurringTask, baselineTask])

        // Advance clock across midnight (+1 day)
        clock.advance(byDays: 1)

        let mutated = ChoreEngine.rollover(state: &state, clock: clock)
        #expect(mutated == true)

        // Recurring task: uncompleted, due date pushed 7 days from completedAt
        let expectedDue = cal.date(byAdding: .day, value: 7, to: day1)!
        #expect(state.tasks[0].isCompleted == false)
        #expect(state.tasks[0].dueDate == expectedDue)

        // Baseline task: uncompleted, due date untouched
        #expect(state.tasks[1].isCompleted == false)
        #expect(state.tasks[1].dueDate == day1)
    }

    @Test("Rollover leaves tasks completed today untouched")
    func testRolloverIgnoresTodayCompletions() {
        let cal = makeCalendar()
        let day1 = Date(timeIntervalSince1970: 1777636800)
        let clock = TestClock(now: day1, calendar: cal)

        let baselineTask = TaskItem(
            title: "Habit",
            tag: "SELF",
            isCompleted: true,
            dueDate: day1,
            lastCompletedAt: day1,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )

        var state = DashboardState(tasks: [baselineTask])
        let mutated = ChoreEngine.rollover(state: &state, clock: clock)
        #expect(mutated == false)
        #expect(state.tasks[0].isCompleted == true)
    }
}