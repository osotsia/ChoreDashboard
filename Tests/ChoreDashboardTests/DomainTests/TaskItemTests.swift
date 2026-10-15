import Testing
import Foundation
@testable import ChoreDashboard

struct HealthRatioThresholdCase: Sendable, CustomTestStringConvertible {
    let daysRemaining: Int
    let expectedState: TaskHealthState

    var testDescription: String {
        "\(daysRemaining)% remaining -> \(expectedState.rawValue)"
    }
}

struct TimeAnchorFormattingCase: Sendable, CustomTestStringConvertible {
    let daysOffset: Int
    let expectedString: String

    var testDescription: String {
        "Offset \(daysOffset)d -> \"\(expectedString)\""
    }
}

@Suite("TaskItem Health Heuristics & Cadence Unit Tests")
struct TaskItemTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeReferenceDate() -> Date {
        let cal = makeCalendar()
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 1
        comps.hour = 12
        return cal.date(from: comps)!
    }

    // MARK: - Health Runway Boundaries

    @Test("HealthState evaluates to .good when task is marked complete")
    func testHealthStateCompleted() {
        let cal = makeCalendar()
        let now = makeReferenceDate()
        let overdueDate = cal.date(byAdding: .day, value: -10, to: now)!

        let task = TaskItem(title: "Task", tag: "TEST", isCompleted: true, dueDate: overdueDate)
        #expect(task.healthState(relativeTo: now, calendar: cal) == .good)
    }

    @Test("HealthState identifies .due and .overdue boundaries correctly")
    func testHealthStateImmediateBoundaries() {
        let cal = makeCalendar()
        let now = makeReferenceDate()

        let dueToday = TaskItem(title: "Today", tag: "TEST", dueDate: now)
        #expect(dueToday.healthState(relativeTo: now, calendar: cal) == .due)

        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let overdueTask = TaskItem(title: "Overdue", tag: "TEST", dueDate: yesterday)
        #expect(overdueTask.healthState(relativeTo: now, calendar: cal) == .overdue)
    }

    @Test(
        "HealthState evaluates exact 85%, 60%, and 35% ratio thresholds",
        arguments: [
            HealthRatioThresholdCase(daysRemaining: 85, expectedState: .good),
            HealthRatioThresholdCase(daysRemaining: 84, expectedState: .notYet),
            HealthRatioThresholdCase(daysRemaining: 60, expectedState: .notYet),
            HealthRatioThresholdCase(daysRemaining: 59, expectedState: .halfway),
            HealthRatioThresholdCase(daysRemaining: 35, expectedState: .halfway),
            HealthRatioThresholdCase(daysRemaining: 34, expectedState: .due)
        ]
    )
    func testHealthStateRatios(testCase: HealthRatioThresholdCase) {
        let cal = makeCalendar()
        let now = makeReferenceDate()
        let rule = RecurrenceRule(count: 100, unit: .day)

        let targetDate = cal.date(byAdding: .day, value: testCase.daysRemaining, to: now)!
        let task = TaskItem(title: "Task", tag: "TEST", dueDate: targetDate, recurrence: rule)
        #expect(task.healthState(relativeTo: now, calendar: cal) == testCase.expectedState)
    }

    // MARK: - Time Anchors

    @Test(
        "timeAnchor outputs formatted strings across all calendar horizons",
        arguments: [
            TimeAnchorFormattingCase(daysOffset: -4, expectedString: "Overdue (4d)"),
            TimeAnchorFormattingCase(daysOffset: 0, expectedString: "Today"),
            TimeAnchorFormattingCase(daysOffset: 1, expectedString: "In 1 Day"),
            TimeAnchorFormattingCase(daysOffset: 6, expectedString: "In 6 Days"),
            TimeAnchorFormattingCase(daysOffset: 21, expectedString: "In 3 Weeks (21d)"),
            TimeAnchorFormattingCase(daysOffset: 90, expectedString: "In 3 Months (90d)"),
            TimeAnchorFormattingCase(daysOffset: 365, expectedString: "In 12 Months (365d)"),
            TimeAnchorFormattingCase(daysOffset: -500, expectedString: "Overdue (500d)")
        ]
    )
    func testTimeAnchorStringFormatting(testCase: TimeAnchorFormattingCase) {
        let cal = makeCalendar()
        let now = makeReferenceDate()
        let target = cal.date(byAdding: .day, value: testCase.daysOffset, to: now)!
        let task = TaskItem(title: "T", tag: "TEST", dueDate: target)
        #expect(task.timeAnchor(relativeTo: now, calendar: cal) == testCase.expectedString)
    }

    // MARK: - Cadence Units

    @Test("CadenceUnit correctly computes days and supports circular navigation")
    func testCadenceUnitMethods() {
        #expect(CadenceUnit.day.days(count: 3) == 3)
        #expect(CadenceUnit.week.days(count: 2) == 14)
        #expect(CadenceUnit.month.days(count: 3) == 90)
        #expect(CadenceUnit.year.days(count: 1) == 365)

        #expect(CadenceUnit.day.next() == .week)
        #expect(CadenceUnit.week.next() == .month)
        #expect(CadenceUnit.month.next() == .year)
        #expect(CadenceUnit.year.next() == .day)

        #expect(CadenceUnit.day.previous() == .year)
        #expect(CadenceUnit.year.previous() == .month)
    }

    @Test("isDailyBaseline returns true only for exactly 1-day recurring tasks")
    func testIsDailyBaseline() {
        let daily = TaskItem(title: "Daily", tag: "TEST", recurrence: RecurrenceRule(count: 1, unit: .day))
        let twoDay = TaskItem(title: "TwoDay", tag: "TEST", recurrence: RecurrenceRule(count: 2, unit: .day))
        let weekly = TaskItem(title: "Weekly", tag: "TEST", recurrence: RecurrenceRule(count: 1, unit: .week))
        let oneTime = TaskItem(title: "OneTime", tag: "TEST", recurrence: nil)

        #expect(daily.isDailyBaseline == true)
        #expect(twoDay.isDailyBaseline == false)
        #expect(weekly.isDailyBaseline == false)
        #expect(oneTime.isDailyBaseline == false)
    }

    // MARK: - Clamping & Extreme Horizon Limits

    @Test("TaskItem clamps zero and negative duration to a positive single minute")
    func testTaskItemNegativeDurationClamping() {
        let zeroDuration = TaskItem(title: "Zero", tag: "TEST", durationMinutes: 0)
        let negativeDuration = TaskItem(title: "Negative", tag: "TEST", durationMinutes: -45)

        #expect(zeroDuration.durationMinutes == 1)
        #expect(negativeDuration.durationMinutes == 1)
    }

    @Test("estimatedDaysRemaining clamps to zero when task is overdue")
    func testEstimatedDaysRemainingFloorClamping() {
        let cal = makeCalendar()
        let now = makeReferenceDate()
        let overdueDate = cal.date(byAdding: .day, value: -12, to: now)!

        let overdueTask = TaskItem(title: "Overdue", tag: "TEST", dueDate: overdueDate)
        #expect(overdueTask.estimatedDaysRemaining(relativeTo: now, calendar: cal) == 0)
    }
}