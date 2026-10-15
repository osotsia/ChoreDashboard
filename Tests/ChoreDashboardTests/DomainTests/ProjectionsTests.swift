import Testing
import Foundation
@testable import ChoreDashboard

@Suite("ChoreProjections Mathematical Invariants")
struct ProjectionsTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeClock() -> TestClock {
        let date = Date(timeIntervalSince1970: 1777636800) // 2026-05-01 12:00:00 UTC
        return TestClock(now: date, calendar: makeCalendar())
    }

    @Test("Baseline, FocusQueue, and UpcomingEvents partitions are mutually disjoint")
    func testQueuePartitioningDisjointness() {
        let clock = makeClock()
        let state = PreviewData.defaultState

        let baseline = Set(ChoreProjections.baselineTasks(for: state).map(\.id))
        let focus = Set(ChoreProjections.focusQueue(for: state, clock: clock).map(\.id))
        let upcoming = Set(ChoreProjections.upcomingEvents(for: state, clock: clock).map(\.id))

        #expect(baseline.isDisjoint(with: focus))
        #expect(baseline.isDisjoint(with: upcoming))
        #expect(focus.isDisjoint(with: upcoming))
    }

    @Test("TodayOperationalSnapshot clearance rate evaluates correctly")
    func testTodaySnapshotClearanceRate() {
        let clock = makeClock()
        let t1 = TaskItem(title: "B1", tag: "SELF", isCompleted: true, recurrence: RecurrenceRule(count: 1, unit: .day))
        let t2 = TaskItem(title: "B2", tag: "SELF", isCompleted: false, recurrence: RecurrenceRule(count: 1, unit: .day))
        let t3 = TaskItem(title: "F1", tag: "KITCHEN", isCompleted: false, dueDate: clock.now, recurrence: RecurrenceRule(count: 1, unit: .week))

        let state = DashboardState(tasks: [t1, t2, t3])
        let snapshot = ChoreProjections.todaySnapshot(for: state, clock: clock)

        #expect(snapshot.totalTasks == 3)
        #expect(snapshot.completedTasks == 1)
        #expect(abs(snapshot.clearanceRate - (1.0 / 3.0)) < 0.001)
    }

    @Test("Monthly pacing reflects lead when completions exceed time-elapsed quota pace")
    func testMonthlyPacingLead() {
        let clock = makeClock() // Day 1 of May (1/31 elapsed)
        let taskId = UUID()
        let t1 = TaskItem(id: taskId, title: "F1", tag: "KITCHEN", dueDate: clock.now, recurrence: RecurrenceRule(count: 1, unit: .week))
        let history = [
            HistoryRecord(taskId: taskId, title: "F1", tag: "KITCHEN", completedAt: clock.now),
            HistoryRecord(taskId: taskId, title: "F1", tag: "KITCHEN", completedAt: clock.now)
        ]

        let state = DashboardState(tasks: [t1], historyRecords: history)
        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clock)

        #expect(pacing.currentDay == 1)
        #expect(pacing.actualCompleted == 2)
        #expect(pacing.isLeading == true)
        #expect(pacing.deltaLead > 0)
    }
}