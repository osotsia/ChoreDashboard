import Testing
import Foundation
@testable import ChoreDashboard

@Suite("ChoreProjections Partition & Queue Operations")
struct ProjectionsTests {

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
        return TestClock(now: cal.date(from: comps)!, calendar: cal)
    }

    // MARK: - Queue Disjointness & Partition Tests

    @Test("Queue partitioning maintains absolute mutual disjointness across dynamic states")
    func testDynamicQueueDisjointness() {
        let clock = makeClock(year: 2026, month: 5, day: 15)
        let cal = clock.calendar

        let baseline = TaskItem(title: "Baseline", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let focusOverdue = TaskItem(title: "Overdue", tag: "KITCHEN", dueDate: cal.date(byAdding: .day, value: -3, to: clock.now)!)
        let focusToday = TaskItem(title: "DueToday", tag: "KITCHEN", dueDate: clock.now)
        let focusDoneToday = TaskItem(
            title: "DoneToday",
            tag: "KITCHEN",
            isCompleted: true,
            dueDate: clock.now,
            lastCompletedAt: clock.now
        )
        let upcoming = TaskItem(title: "Upcoming", tag: "GENERAL", dueDate: cal.date(byAdding: .day, value: 4, to: clock.now)!)

        let state = DashboardState(tasks: [baseline, focusOverdue, focusToday, focusDoneToday, upcoming])

        let baseSet = Set(ChoreProjections.baselineTasks(for: state).map(\.id))
        let focusSet = Set(ChoreProjections.focusQueue(for: state, clock: clock).map(\.id))
        let upSet = Set(ChoreProjections.upcomingEvents(for: state, clock: clock).map(\.id))

        #expect(baseSet.isDisjoint(with: focusSet))
        #expect(baseSet.isDisjoint(with: upSet))
        #expect(focusSet.isDisjoint(with: upSet))

        #expect(baseSet.count == 1)
        #expect(focusSet.count == 3)
        #expect(upSet.count == 1)
    }

    @Test("sortedUpcomingEvents sorts primarily by days remaining and secondary by title")
    func testSortedUpcomingEventsOrdering() {
        let clock = makeClock(year: 2026, month: 5, day: 1)
        let cal = clock.calendar

        let taskFar = TaskItem(title: "Z Task", tag: "TEST", dueDate: cal.date(byAdding: .day, value: 10, to: clock.now)!)
        let taskNearB = TaskItem(title: "B Task", tag: "TEST", dueDate: cal.date(byAdding: .day, value: 2, to: clock.now)!)
        let taskNearA = TaskItem(title: "A Task", tag: "TEST", dueDate: cal.date(byAdding: .day, value: 2, to: clock.now)!)

        let state = DashboardState(tasks: [taskFar, taskNearB, taskNearA])
        let sorted = ChoreProjections.sortedUpcomingEvents(for: state, clock: clock)

        #expect(sorted.map(\.title) == ["A Task", "B Task", "Z Task"])
    }

    // MARK: - Today Operational Snapshot Tests

    @Test("todaySnapshot correctly calculates task clearance, overdue counters, and telemetry metrics")
    func testTodaySnapshotCalculations() {
        let clock = makeClock(year: 2026, month: 5, day: 1)
        let cal = clock.calendar

        let overdueTask = TaskItem(
            title: "Overdue",
            tag: "KITCHEN",
            isCompleted: false,
            dueDate: cal.date(byAdding: .day, value: -2, to: clock.now)!
        )
        let dueTask = TaskItem(
            title: "Due Today",
            tag: "KITCHEN",
            isCompleted: false,
            dueDate: clock.now
        )
        let completedFocus = TaskItem(
            title: "Completed Focus",
            tag: "KITCHEN",
            isCompleted: true,
            dueDate: clock.now,
            lastCompletedAt: clock.now
        )
        let baselineDone = TaskItem(
            title: "Base Done",
            tag: "SELF",
            durationMinutes: 10,
            isCompleted: true,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )
        let baselineRemaining = TaskItem(
            title: "Base Left",
            tag: "SELF",
            durationMinutes: 20,
            isCompleted: false,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )
        let upcoming = TaskItem(
            title: "Upcoming",
            tag: "GENERAL",
            dueDate: cal.date(byAdding: .day, value: 5, to: clock.now)!
        )

        let state = DashboardState(tasks: [
            overdueTask,
            dueTask,
            completedFocus,
            baselineDone,
            baselineRemaining,
            upcoming
        ])

        let snapshot = ChoreProjections.todaySnapshot(for: state, clock: clock)

        #expect(snapshot.focusTotal == 3)
        #expect(snapshot.focusCompleted == 1)
        #expect(snapshot.focusOverdue == 1)
        #expect(snapshot.focusRemaining == 2)

        #expect(snapshot.baselineTotal == 2)
        #expect(snapshot.baselineCompleted == 1)
        #expect(snapshot.baselineRemaining == 1)
        #expect(snapshot.baselineMinutesRemaining == 20)

        #expect(snapshot.totalTasks == 5)
        #expect(snapshot.completedTasks == 2)
        #expect(snapshot.clearanceRate == 0.4)
    }

    @Test("todaySnapshot returns 100% clearance rate on empty task inventory")
    func testTodaySnapshotEmptyState() {
        let clock = makeClock(year: 2026, month: 5, day: 1)
        let state = DashboardState(tasks: [])

        let snapshot = ChoreProjections.todaySnapshot(for: state, clock: clock)

        #expect(snapshot.totalTasks == 0)
        #expect(snapshot.completedTasks == 0)
        #expect(snapshot.clearanceRate == 1.0)
        #expect(snapshot.baselineMinutesRemaining == 0)
    }

    // MARK: - Available Tags Tests

    @Test("availableTags aggregates unique non-empty tags across models and provides fallbacks")
    func testAvailableTagsDiscovery() {
        let task = TaskItem(title: "T", tag: "TAG_B")
        let history = HistoryRecord(title: "H", tag: "TAG_C")
        let state = DashboardState(
            tasks: [task],
            historyRecords: [history],
            customTags: ["TAG_A", "  "]
        )

        let tags = ChoreProjections.availableTags(for: state)
        #expect(tags == ["TAG_A", "TAG_B", "TAG_C"])

        let emptyState = DashboardState(tasks: [], historyRecords: [], customTags: [])
        let defaultTags = ChoreProjections.availableTags(for: emptyState)
        #expect(defaultTags == ["BATHROOM", "GENERAL", "KITCHEN", "SELF"])
    }
}