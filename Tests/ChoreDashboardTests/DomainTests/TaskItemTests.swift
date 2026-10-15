import Testing
import Foundation
@testable import ChoreDashboard

@Suite("Task Item Domain Model Tests")
struct TaskItemTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeReferenceDate() -> Date {
        // 2026-05-01 12:00:00 UTC
        Date(timeIntervalSince1970: 1777636800)
    }

    @Test("HealthState evaluates to DUE when start of due date equals start of current day")
    func testHealthStateDueToday() {
        let cal = makeCalendar()
        let refDate = makeReferenceDate()
        let clock = TestClock(now: refDate, calendar: cal)

        let task = TaskItem(
            title: "Test Task",
            tag: "TEST",
            isCompleted: false,
            dueDate: refDate,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )

        #expect(task.healthState(using: clock) == .due)
    }

    @Test("HealthState evaluates to OVERDUE when due date is in the past")
    func testHealthStateOverdue() {
        let cal = makeCalendar()
        let refDate = makeReferenceDate()
        let yesterday = cal.date(byAdding: .day, value: -1, to: refDate)!
        let clock = TestClock(now: refDate, calendar: cal)

        let task = TaskItem(
            title: "Overdue Task",
            tag: "TEST",
            isCompleted: false,
            dueDate: yesterday,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )

        #expect(task.healthState(using: clock) == .overdue)
    }

    @Test("HealthState returns GOOD when task is completed, regardless of due date")
    func testHealthStateCompletedIsGood() {
        let cal = makeCalendar()
        let refDate = makeReferenceDate()
        let past = cal.date(byAdding: .day, value: -5, to: refDate)!
        let clock = TestClock(now: refDate, calendar: cal)

        let task = TaskItem(
            title: "Completed Task",
            tag: "TEST",
            isCompleted: true,
            dueDate: past,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )

        #expect(task.healthState(using: clock) == .good)
    }

    @Test("Estimated days remaining returns zero for overdue or due tasks")
    func testEstimatedDaysRemaining() {
        let cal = makeCalendar()
        let refDate = makeReferenceDate()
        let past = cal.date(byAdding: .day, value: -3, to: refDate)!

        let overdueTask = TaskItem(title: "Task", tag: "TEST", dueDate: past)
        #expect(overdueTask.estimatedDaysRemaining(relativeTo: refDate, calendar: cal) == 0)

        let future = cal.date(byAdding: .day, value: 4, to: refDate)!
        let futureTask = TaskItem(title: "Task", tag: "TEST", dueDate: future)
        #expect(futureTask.estimatedDaysRemaining(relativeTo: refDate, calendar: cal) == 4)
    }
}