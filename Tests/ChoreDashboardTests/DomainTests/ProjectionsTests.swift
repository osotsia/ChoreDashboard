import Testing
import Foundation
@testable import ChoreDashboard

@Suite("ChoreProjections Pure Transform Tests")
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

    // MARK: - Monthly Pacing Boundaries

    @Test("monthlyPacing evaluates lagging deficit and leading pace correctly")
    func testMonthlyPacingCalculations() {
        let clock = makeClock(year: 2026, month: 5, day: 10)

        let t1 = TaskItem(title: "T1", tag: "T", recurrence: RecurrenceRule(count: 10, unit: .day))
        let t2 = TaskItem(title: "T2", tag: "T", recurrence: RecurrenceRule(count: 10, unit: .day))
        let t3 = TaskItem(title: "T3", tag: "T", recurrence: RecurrenceRule(count: 10, unit: .day))

        let deficitHistory = [HistoryRecord(title: "T1", tag: "T", completedAt: clock.now)]
        let deficitState = DashboardState(tasks: [t1, t2, t3], historyRecords: deficitHistory)
        let deficitPacing = ChoreProjections.monthlyPacing(for: deficitState, clock: clock)

        #expect(deficitPacing.actualCompleted == 1)
        #expect(deficitPacing.deltaLead < 0)
        #expect(deficitPacing.isLeading == false)

        var leadHistory: [HistoryRecord] = []
        for _ in 0..<6 {
            leadHistory.append(HistoryRecord(title: "T", tag: "T", completedAt: clock.now))
        }
        let leadState = DashboardState(tasks: [t1, t2, t3], historyRecords: leadHistory)
        let leadPacing = ChoreProjections.monthlyPacing(for: leadState, clock: clock)

        #expect(leadPacing.actualCompleted == 6)
        #expect(leadPacing.deltaLead > 0)
        #expect(leadPacing.isLeading == true)
    }

    @Test("monthlyPacing calculates non-zero quota and zero completions cleanly when task inventory is empty")
    func testMonthlyPacingEmptyState() {
        let clock = makeClock(year: 2026, month: 5, day: 10)
        let emptyState = DashboardState(tasks: [], historyRecords: [])

        let pacing = ChoreProjections.monthlyPacing(for: emptyState, clock: clock)

        #expect(pacing.totalMonthlyQuota == 1)
        #expect(pacing.actualCompleted == 0)
        #expect(pacing.actualProgressRatio == 0.0)
        #expect(pacing.deltaLead <= 0)
    }

    @Test("monthlyPacing strictly isolates completions within the active calendar year")
    func testMonthlyPacingYearIsolation() {
        let cal = makeCalendar()
        let clock2026 = makeClock(year: 2026, month: 5, day: 15)

        var pastComps = DateComponents()
        pastComps.year = 2025
        pastComps.month = 5
        pastComps.day = 15
        let may2025Date = cal.date(from: pastComps)!

        let pastRecord = HistoryRecord(title: "Past", tag: "GENERAL", completedAt: may2025Date)
        let currentRecord = HistoryRecord(title: "Current", tag: "GENERAL", completedAt: clock2026.now)

        let state = DashboardState(
            tasks: [TaskItem(title: "T", tag: "GENERAL", recurrence: RecurrenceRule(count: 1, unit: .week))],
            historyRecords: [pastRecord, currentRecord]
        )

        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clock2026)
        #expect(pacing.actualCompleted == 1)
    }

    @Test("monthlyPacing handles February leap-year pacing calculations accurately")
    func testMonthlyPacingLeapYearFebruary() {
        let clockFeb2028 = makeClock(year: 2028, month: 2, day: 14)
        let task = TaskItem(title: "Weekly Task", tag: "GENERAL", recurrence: RecurrenceRule(count: 1, unit: .week))
        let state = DashboardState(tasks: [task])

        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clockFeb2028)
        #expect(pacing.totalDaysInMonth == 29)
        #expect(pacing.currentDay == 14)
        #expect(pacing.expectedProgressRatio == Double(14) / Double(29))
    }

    @Test("monthlyPacing calculates expected ratios at Day 1 and month-end boundaries")
    func testMonthlyPacingMonthBoundaries() {
        let clockStart = makeClock(year: 2026, month: 5, day: 1)
        let stateStart = DashboardState(tasks: [TaskItem(title: "Task", tag: "T", recurrence: RecurrenceRule(count: 1, unit: .week))])
        let pacingStart = ChoreProjections.monthlyPacing(for: stateStart, clock: clockStart)

        #expect(pacingStart.currentDay == 1)
        #expect(pacingStart.totalDaysInMonth == 31)
        #expect(pacingStart.expectedProgressRatio == Double(1) / Double(31))

        let clockEnd = makeClock(year: 2026, month: 5, day: 31)
        let pacingEnd = ChoreProjections.monthlyPacing(for: stateStart, clock: clockEnd)

        #expect(pacingEnd.currentDay == 31)
        #expect(pacingEnd.expectedProgressRatio == 1.0)
    }

    @Test("monthlyPacing clamps actual progress ratio to 1.0 when actual completions exceed monthly quota")
    func testMonthlyPacingQuotaExceeded() {
        let clock = makeClock(year: 2026, month: 5, day: 15)
        let task = TaskItem(title: "Task", tag: "T", recurrence: RecurrenceRule(count: 31, unit: .day))
        var history: [HistoryRecord] = []
        for _ in 0..<10 {
            history.append(HistoryRecord(title: "Task", tag: "T", completedAt: clock.now))
        }

        let state = DashboardState(tasks: [task], historyRecords: history)
        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clock)

        #expect(pacing.actualCompleted == 10)
        #expect(pacing.actualProgressRatio == 1.0)
        #expect(pacing.deltaLead > 0)
        #expect(pacing.isLeading == true)
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