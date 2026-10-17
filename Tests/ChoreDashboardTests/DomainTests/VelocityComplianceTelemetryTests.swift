import Testing
import Foundation
@testable import ChoreDashboard

// MARK: - Fine-Grained Temporal Boundary Suite

@Suite("ActiveMonthWindow Temporal Boundary Tests")
struct ActiveMonthWindowTests {
    private let cal = Calendar(identifier: .gregorian)

    @Test("Future tracking start dates in current month clamp startDay to currentDay")
    func testFutureTrackingStartDateClamping() {
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 10))!
        let futureStart = cal.date(from: DateComponents(year: 2026, month: 5, day: 25))!

        let window = ActiveMonthWindow(now: now, trackingStartDate: futureStart, calendar: cal)
        #expect(window.startDay == 10)
        #expect(window.activeDaysElapsed == 1)
        #expect(window.completedDays == 0)
    }

    @Test("Tracking start dates from prior months or years fall back to fallbackStartDay")
    func testPastMonthTrackingStartDateFallback() {
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 10))!
        let pastMonthStart = cal.date(from: DateComponents(year: 2026, month: 4, day: 15))!

        let window = ActiveMonthWindow(now: now, trackingStartDate: pastMonthStart, fallbackStartDay: 1, calendar: cal)
        #expect(window.startDay == 1)
        #expect(window.activeDaysElapsed == 10)
        #expect(window.completedDays == 9)
    }

    @Test("Month title format outputs uppercase wide month localized to calendar")
    func testMonthTitleFormatting() {
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let window = ActiveMonthWindow(now: now, trackingStartDate: nil, calendar: cal)
        #expect(window.monthTitle == "OCTOBER")
    }

    @Test("Leap-year February calculates exact 29-day month range")
    func testLeapYearMonthDaysCount() {
        let now = cal.date(from: DateComponents(year: 2028, month: 2, day: 14))!
        let window = ActiveMonthWindow(now: now, trackingStartDate: nil, calendar: cal)
        #expect(window.totalDaysInMonth == 29)
    }
}

// MARK: - Fine-Grained Pure Calculus Suite

struct PacingMathTestCase: Sendable, CustomTestStringConvertible {
    let actual: Int
    let quota: Int
    let day: Int
    let expectedLead: Int
    let expectedOnPace: Bool
    let expectedLeading: Bool

    var testDescription: String {
        "Actual: \(actual), Quota: \(quota), Day: \(day) -> Lead: \(expectedLead), OnPace: \(expectedOnPace), Leading: \(expectedLeading)"
    }
}

@Suite("PacingMath Pure Calculus Tests")
struct PacingMathTests {
    private let cal = Calendar(identifier: .gregorian)

    @Test(
        "Dual-threshold pacing accurately resolves all mathematical boundaries",
        arguments: [
            // 1. Zero Quota: Always on pace, 0 lead
            PacingMathTestCase(actual: 0, quota: 0, day: 10, expectedLead: 0, expectedOnPace: true, expectedLeading: true),
            // 2. Below Closed-Day Floor (Deficit): Quota 10, Day 10 (9 closed). expectedPrior = 2.90 (floor 2) -> actual 1 < 2. deficit = 1 - 3 = -2
            PacingMathTestCase(actual: 1, quota: 10, day: 10, expectedLead: -2, expectedOnPace: false, expectedLeading: false),
            // 3. Exactly at Closed-Day Floor (On Pace): expectedPrior = 2.90 (floor 2) -> actual 2 == 2
            PacingMathTestCase(actual: 2, quota: 10, day: 10, expectedLead: 0, expectedOnPace: true, expectedLeading: true),
            // 4. In Active Operational Window (On Pace): expectedToday = 3.22 (ceil 4) -> actual 3 < 4 but >= 2
            PacingMathTestCase(actual: 3, quota: 10, day: 10, expectedLead: 0, expectedOnPace: true, expectedLeading: true),
            // 5. Exceeding Today's Ceiling (Leading): expectedToday = 3.22 (ceil 4) -> actual 5 >= 4. lead = 5 - round(3.22) = +2
            PacingMathTestCase(actual: 5, quota: 10, day: 10, expectedLead: 2, expectedOnPace: false, expectedLeading: true)
        ]
    )
    func testPacingMathEvaluation(tc: PacingMathTestCase) {
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: tc.day))!
        let window = ActiveMonthWindow(
            now: now,
            trackingStartDate: cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!,
            fallbackStartDay: 1,
            calendar: cal
        )

        let result = PacingMath.evaluate(actualCompletions: tc.actual, quota: tc.quota, window: window)
        #expect(result.deltaLead == tc.expectedLead)
        #expect(result.isOnPace == tc.expectedOnPace)
        #expect(result.isLeading == tc.expectedLeading)
    }
}

// MARK: - State & Telemetry Integration Suite

@Suite("Velocity & Baseline Compliance Telemetry Engine Tests")
struct VelocityComplianceTelemetryTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeClock(
        year: Int = 2026,
        month: Int = 5,
        day: Int = 1,
        hour: Int = 12
    ) -> TestClock {
        let cal = makeCalendar()
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = 0
        comps.second = 0
        return TestClock(now: cal.date(from: comps)!, calendar: cal)
    }

    // MARK: - Zero / Empty State Invariants

    @Test("Completely empty state evaluates to nominal zero-quota pacing and 100% baseline compliance")
    func testCompletelyEmptyStateTelemetry() {
        let clock = makeClock(year: 2026, month: 5, day: 10)
        let emptyState = DashboardState(tasks: [], historyRecords: [])

        let pacing = ChoreProjections.monthlyPacing(for: emptyState, clock: clock)
        #expect(pacing.totalMonthlyQuota == 0)
        #expect(pacing.actualCompleted == 0)
        #expect(pacing.actualProgressRatio == 0.0)
        #expect(pacing.deltaLead == 0)
        #expect(pacing.isOnPace == true)
        #expect(pacing.isLeading == true)

        let compliance = ChoreProjections.baselineCompliance(for: emptyState, clock: clock)
        #expect(compliance.totalBaselineTasks == 0)
        #expect(compliance.expectedCount == 0)
        #expect(compliance.completedCount == 0)
        #expect(compliance.complianceRatio == 1.0)
        #expect(compliance.compliancePercentage == 100)
        #expect(compliance.isNominal == true)
        #expect(compliance.statusBadgeText == "NOMINAL")
    }

    @Test("Baseline-only inventory decouples from monthly maintenance quota without generating spurious deficits")
    func testBaselineOnlyInventoryExcludesBaselinesFromMaintenanceQuota() {
        let clock = makeClock(year: 2026, month: 5, day: 15) // Day 15 of 31

        let b1 = TaskItem(title: "Stretch", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let b2 = TaskItem(title: "Meditate", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let b3 = TaskItem(title: "Vitamins", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))

        var history: [HistoryRecord] = []
        for d in 1...15 {
            let recordDate = clock.calendar.date(byAdding: .day, value: -(15 - d), to: clock.now)!
            history.append(HistoryRecord(taskId: b1.id, title: "Stretch", tag: "SELF", completedAt: recordDate, isDailyBaseline: true))
            history.append(HistoryRecord(taskId: b2.id, title: "Meditate", tag: "SELF", completedAt: recordDate, isDailyBaseline: true))
            history.append(HistoryRecord(taskId: b3.id, title: "Vitamins", tag: "SELF", completedAt: recordDate, isDailyBaseline: true))
        }

        let state = DashboardState(tasks: [b1, b2, b3], historyRecords: history)

        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clock)
        #expect(pacing.totalMonthlyQuota == 0)
        #expect(pacing.actualCompleted == 0)
        #expect(pacing.deltaLead == 0)
        #expect(pacing.isOnPace == true)
        #expect(pacing.isLeading == true)

        let compliance = ChoreProjections.baselineCompliance(for: state, clock: clock)
        #expect(compliance.totalBaselineTasks == 3)
        #expect(compliance.activeDaysTracked == 15)
        #expect(compliance.completedCount == 45)
        #expect(compliance.isNominal == true)
    }

    @Test("Zero history records with active maintenance tasks reports on pace on Day 1 and deficit later in month")
    func testZeroHistoryWithActiveMaintenanceTasks() {
        let task = TaskItem(title: "Weekly Maintenance", tag: "GENERAL", recurrence: RecurrenceRule(count: 1, unit: .week))
        let state = DashboardState(tasks: [task], historyRecords: [])

        // Day 1: Target prior closed requirement is 0 tasks -> user is on pace
        let clockDay1 = makeClock(year: 2026, month: 5, day: 1)
        let pacingDay1 = ChoreProjections.monthlyPacing(for: state, clock: clockDay1)
        #expect(pacingDay1.totalMonthlyQuota == 4)
        #expect(pacingDay1.actualCompleted == 0)
        #expect(pacingDay1.isOnPace == true)
        #expect(pacingDay1.isLeading == true)

        // Day 20: 0 completions with 19 closed days on a weekly task -> lagging behind schedule
        let clockDay20 = makeClock(year: 2026, month: 5, day: 20)
        let pacingDay20 = ChoreProjections.monthlyPacing(for: state, clock: clockDay20)
        #expect(pacingDay20.totalMonthlyQuota == 4)
        #expect(pacingDay20.actualCompleted == 0)
        #expect(pacingDay20.deltaLead < 0)
        #expect(pacingDay20.isOnPace == false)
        #expect(pacingDay20.isLeading == false)
    }

    // MARK: - Dual-Threshold Pacing Window & Velocity Dynamics

    @Test("monthlyPacing evaluates leading, on pace, and deficit states across dual-threshold boundaries")
    func testMonthlyPacingDualThresholdWindow() {
        let clock = makeClock(year: 2026, month: 5, day: 10) // Day 10 of 31

        let t1 = TaskItem(title: "T1", tag: "T", recurrence: RecurrenceRule(count: 10, unit: .day))
        let t2 = TaskItem(title: "T2", tag: "T", recurrence: RecurrenceRule(count: 10, unit: .day))
        let t3 = TaskItem(title: "T3", tag: "T", recurrence: RecurrenceRule(count: 10, unit: .day))
        let tasks = [t1, t2, t3] // Produces quota = 9

        // 1. Deficit State (1 completion vs expectedPrior of ~2.6 -> floor = 2)
        let deficitHistory = [HistoryRecord(title: "T1", tag: "T", completedAt: clock.now)]
        let deficitState = DashboardState(tasks: tasks, historyRecords: deficitHistory)
        let deficitPacing = ChoreProjections.monthlyPacing(for: deficitState, clock: clock)
        #expect(deficitPacing.actualCompleted == 1)
        #expect(deficitPacing.deltaLead < 0)
        #expect(deficitPacing.isLeading == false)
        #expect(deficitPacing.isOnPace == false)

        // 2. On Pace State (2 completions meets targetPrior floor)
        let onPaceHistory = [
            HistoryRecord(title: "T1", tag: "T", completedAt: clock.now),
            HistoryRecord(title: "T2", tag: "T", completedAt: clock.now)
        ]
        let onPaceState = DashboardState(tasks: tasks, historyRecords: onPaceHistory)
        let onPacePacing = ChoreProjections.monthlyPacing(for: onPaceState, clock: clock)
        #expect(onPacePacing.actualCompleted == 2)
        #expect(onPacePacing.deltaLead == 0)
        #expect(onPacePacing.isOnPace == true)
        #expect(onPacePacing.isLeading == true)

        // 3. Leading State (6 completions exceeds expectedToday ceiling of ~3.0)
        var leadHistory: [HistoryRecord] = []
        for _ in 0..<6 {
            leadHistory.append(HistoryRecord(title: "T", tag: "T", completedAt: clock.now))
        }
        let leadState = DashboardState(tasks: tasks, historyRecords: leadHistory)
        let leadPacing = ChoreProjections.monthlyPacing(for: leadState, clock: clock)
        #expect(leadPacing.actualCompleted == 6)
        #expect(leadPacing.deltaLead > 0)
        #expect(leadPacing.isLeading == true)
        #expect(leadPacing.isOnPace == false)
    }

    @Test("monthlyPacing clamps actualProgressRatio to 1.0 while retaining true deltaLead excess")
    func testMonthlyPacingQuotaExceededClamping() {
        let clock = makeClock(year: 2026, month: 5, day: 15)
        let task = TaskItem(title: "Task", tag: "T", recurrence: RecurrenceRule(count: 31, unit: .day)) // Quota = 1
        var history: [HistoryRecord] = []
        for _ in 0..<10 {
            history.append(HistoryRecord(title: "Task", tag: "T", completedAt: clock.now))
        }

        let state = DashboardState(tasks: [task], historyRecords: history)
        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clock)

        #expect(pacing.actualCompleted == 10)
        #expect(pacing.totalMonthlyQuota == 1)
        #expect(pacing.actualProgressRatio == 1.0)
        #expect(pacing.deltaLead >= 9)
        #expect(pacing.isLeading == true)
        #expect(pacing.isOnPace == false)
    }

    @Test("Creating a new recurring task mid-month does not retroactively penalize closed days or flip pacing to lagging")
    func testMidMonthTaskCreationDoesNotCauseLaggingDeficit() {
        let cal = makeCalendar()
        let clock = makeClock(year: 2026, month: 5, day: 20) // Day 20 of 31

        // Pre-existing weekly task (quota ~4), completed 3 times through Day 20 -> ON PACE
        let existingTask = TaskItem(
            title: "Existing Weekly Cleaning",
            tag: "GENERAL",
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )

        var history: [HistoryRecord] = []
        for day in [5, 12, 19] {
            let date = cal.date(from: DateComponents(year: 2026, month: 5, day: day, hour: 10))!
            history.append(HistoryRecord(taskId: existingTask.id, title: "Existing Weekly Cleaning", tag: "GENERAL", completedAt: date, isDailyBaseline: false))
        }

        var state = DashboardState(tasks: [existingTask], historyRecords: history)

        let pacingBefore = ChoreProjections.monthlyPacing(for: state, clock: clock)
        #expect(pacingBefore.isOnPace == true)
        #expect(pacingBefore.isLeading == true)
        #expect(pacingBefore.deltaLead == 0)

        // User adds a new 4-day recurring task today on Day 20
        let newFourDayTask = TaskItem(
            title: "Water Outdoor Planters",
            tag: "GENERAL",
            recurrence: RecurrenceRule(count: 4, unit: .day),
            createdAt: clock.now // Explicitly created today
        )
        ChoreEngine.upsertTask(state: &state, task: newFourDayTask)

        // After adding the task on Day 20:
        // Closed days (1..19) must NOT demand runs for a task created on Day 20.
        // User must remain ON PACE, not flip to DEFICIT (LAGGING).
        let pacingAfter = ChoreProjections.monthlyPacing(for: state, clock: clock)
        #expect(pacingAfter.isOnPace == true)
        #expect(pacingAfter.isLeading == true)
        #expect(pacingAfter.deltaLead == 0)
    }

    // MARK: - Calendar, Timeframe & History Isolation

    @Test("monthlyPacing strictly isolates maintenance records within active calendar month and year")
    func testMonthlyPacingTemporalIsolation() {
        let cal = makeCalendar()
        let clock2026 = makeClock(year: 2026, month: 5, day: 15)

        var comp2025 = DateComponents(); comp2025.year = 2025; comp2025.month = 5; comp2025.day = 15
        let may2025Date = cal.date(from: comp2025)!

        var compApril = DateComponents(); compApril.year = 2026; compApril.month = 4; compApril.day = 30
        let april2026Date = cal.date(from: compApril)!

        let pastYearRecord = HistoryRecord(title: "Past Year", tag: "GENERAL", completedAt: may2025Date)
        let pastMonthRecord = HistoryRecord(title: "Past Month", tag: "GENERAL", completedAt: april2026Date)
        let currentRecord = HistoryRecord(title: "Current", tag: "GENERAL", completedAt: clock2026.now)

        let state = DashboardState(
            tasks: [TaskItem(title: "T", tag: "GENERAL", recurrence: RecurrenceRule(count: 1, unit: .week))],
            historyRecords: [pastYearRecord, pastMonthRecord, currentRecord]
        )

        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clock2026)
        #expect(pacing.actualCompleted == 1)
    }

    @Test("monthlyPacing calculates expected ratios across leap-year February and month boundaries")
    func testMonthlyPacingMonthBoundariesAndLeapYear() {
        // February in Leap Year (2028: 29 days)
        let clockFeb2028 = makeClock(year: 2028, month: 2, day: 14)
        let task = TaskItem(title: "Weekly Task", tag: "GENERAL", recurrence: RecurrenceRule(count: 1, unit: .week))
        let state = DashboardState(tasks: [task])

        let pacingFeb = ChoreProjections.monthlyPacing(for: state, clock: clockFeb2028)
        #expect(pacingFeb.totalDaysInMonth == 29)
        #expect(pacingFeb.currentDay == 14)
        #expect(pacingFeb.expectedProgressRatio == Double(14) / Double(29))

        // Month Start Boundary (Day 1 of 31)
        let clockStart = makeClock(year: 2026, month: 5, day: 1)
        let pacingStart = ChoreProjections.monthlyPacing(for: state, clock: clockStart)
        #expect(pacingStart.currentDay == 1)
        #expect(pacingStart.expectedProgressRatio == Double(1) / Double(31))

        // Month End Boundary (Day 31 of 31)
        let clockEnd = makeClock(year: 2026, month: 5, day: 31)
        let pacingEnd = ChoreProjections.monthlyPacing(for: state, clock: clockEnd)
        #expect(pacingEnd.currentDay == 31)
        #expect(pacingEnd.expectedProgressRatio == 1.0)
    }

    // MARK: - Mid-Month Installation & Dynamic Tracking Start

    @Test("Mid-month installation proportions quota and baseline expected count to active tracked window")
    func testMidMonthInstallPacingAndCompliance() {
        let cal = makeCalendar()
        let clock = makeClock(year: 2026, month: 5, day: 15) // Day 15 of 31

        let b1 = TaskItem(title: "B1", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let b2 = TaskItem(title: "B2", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let maintenance = TaskItem(title: "Weekly Scrub", tag: "KITCHEN", recurrence: RecurrenceRule(count: 1, unit: .week))

        var startComps = DateComponents()
        startComps.year = 2026; startComps.month = 5; startComps.day = 13
        let installDate = cal.date(from: startComps)!

        var history: [HistoryRecord] = []
        for day in 13...15 {
            var c = DateComponents(); c.year = 2026; c.month = 5; c.day = day; c.hour = 9
            let date = cal.date(from: c)!
            history.append(HistoryRecord(taskId: b1.id, title: "B1", tag: "SELF", completedAt: date, isDailyBaseline: true))
            history.append(HistoryRecord(taskId: b2.id, title: "B2", tag: "SELF", completedAt: date, isDailyBaseline: true))
        }

        let state = DashboardState(
            tasks: [b1, b2, maintenance],
            historyRecords: history,
            trackingStartDate: installDate
        )

        let compliance = ChoreProjections.baselineCompliance(for: state, clock: clock)
        #expect(compliance.activeDaysTracked == 3)
        #expect(compliance.totalBaselineTasks == 2)
        #expect(compliance.expectedCount == 6)
        #expect(compliance.completedCount == 6)
        #expect(compliance.compliancePercentage == 100)
        #expect(compliance.isNominal == true)

        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clock)
        let activeRatio = Double(19) / Double(31)
        let expectedFullQuota = Double(31) / 7.0
        #expect(pacing.totalMonthlyQuota == Int(round(expectedFullQuota * activeRatio)))
    }

    @Test("Day 1 of tracking does not pre-bill incomplete baseline tasks before day closes")
    func testDayOneBaselineComplianceNonPrebilling() {
        let clock = makeClock(year: 2026, month: 5, day: 1, hour: 9) // Morning of Day 1
        let b1 = TaskItem(title: "Stretch", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let b2 = TaskItem(title: "Meditate", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))

        let state = DashboardState(tasks: [b1, b2], historyRecords: [], trackingStartDate: clock.now)

        let compliance = ChoreProjections.baselineCompliance(for: state, clock: clock)
        #expect(compliance.activeDaysTracked == 1)
        #expect(compliance.completedCount == 0)
        #expect(compliance.expectedCount == 0)
        #expect(compliance.complianceRatio == 1.0)
        #expect(compliance.compliancePercentage == 100)
        #expect(compliance.isNominal == true)
        #expect(compliance.statusBadgeText == "NOMINAL")
    }

    // MARK: - Workload Composition & Purged Task Preservation

    @Test("Completed one-time maintenance chores purged from inventory remain accounted for in monthly quota")
    func testCompletedOneTimeMaintenanceTasksPreservedInMonthlyQuota() {
        let clock = makeClock(year: 2026, month: 5, day: 10)
        let oneTimeId = UUID()

        let historicalPurgedRecord = HistoryRecord(
            taskId: oneTimeId,
            title: "Replace Smoke Alarm Battery",
            tag: "GENERAL",
            completedAt: clock.calendar.date(byAdding: .day, value: -5, to: clock.now)!,
            isDailyBaseline: false
        )

        let state = DashboardState(
            tasks: [],
            historyRecords: [historicalPurgedRecord]
        )

        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clock)
        #expect(pacing.actualCompleted == 1)
        #expect(pacing.totalMonthlyQuota == 1)
        #expect(pacing.actualProgressRatio == 1.0)
        #expect(pacing.isLeading == true)
    }

    @Test("Deleted baseline task records retain baseline classification via flag or title fallback")
    func testDeletedBaselineTaskRecordIdentification() {
        let clock = makeClock(year: 2026, month: 5, day: 10)

        let recordFlagged = HistoryRecord(
            taskId: UUID(),
            title: "Old Stretch Routine",
            tag: "SELF",
            completedAt: clock.now,
            isDailyBaseline: true
        )

        let activeBaseline = TaskItem(title: "Drink Water", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let recordTitleMatch = HistoryRecord(
            taskId: UUID(),
            title: "Drink Water",
            tag: "SELF",
            completedAt: clock.now,
            isDailyBaseline: false
        )

        let state = DashboardState(
            tasks: [activeBaseline],
            historyRecords: [recordFlagged, recordTitleMatch]
        )

        #expect(ChoreProjections.isBaselineRecord(recordFlagged, in: state) == true)
        #expect(ChoreProjections.isBaselineRecord(recordTitleMatch, in: state) == true)

        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clock)
        #expect(pacing.actualCompleted == 0)
    }

    // MARK: - Task Deletion & Semantic Immutability Regressions

    @Test("Deleting a daily baseline task preserves historical records as baseline and does not inflate maintenance velocity")
    func testDeletedBaselineTaskCompletionsDoNotDriftIntoMaintenanceVelocity() {
        let clock = makeClock(year: 2026, month: 10, day: 16)

        let baseline1 = TaskItem(title: "Wipe counters", tag: "KITCHEN", recurrence: RecurrenceRule(count: 1, unit: .day))
        let baseline2 = TaskItem(title: "Meditation", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let maintenance = TaskItem(title: "Deep clean oven", tag: "KITCHEN", recurrence: RecurrenceRule(count: 1, unit: .month))

        let recordBaseline1 = HistoryRecord(taskId: baseline1.id, title: "Wipe counters", tag: "KITCHEN", completedAt: clock.now, isDailyBaseline: true)
        let recordOlderBaseline1 = HistoryRecord(taskId: baseline1.id, title: "Wipe counters", tag: "KITCHEN", completedAt: clock.calendar.date(byAdding: .day, value: -2, to: clock.now)!, isDailyBaseline: false)
        let recordMaintenance = HistoryRecord(taskId: maintenance.id, title: "Deep clean oven", tag: "KITCHEN", completedAt: clock.now, isDailyBaseline: false)

        var state = DashboardState(
            tasks: [baseline1, baseline2, maintenance],
            historyRecords: [recordBaseline1, recordOlderBaseline1, recordMaintenance]
        )

        let pacingBefore = ChoreProjections.monthlyPacing(for: state, clock: clock)
        #expect(pacingBefore.actualCompleted == 1)

        ChoreEngine.deleteTask(state: &state, id: baseline1.id)

        let pacingAfter = ChoreProjections.monthlyPacing(for: state, clock: clock)
        #expect(pacingAfter.actualCompleted == 1)
        #expect(ChoreProjections.isBaselineRecord(state.historyRecords[0], in: state) == true)
        #expect(ChoreProjections.isBaselineRecord(state.historyRecords[1], in: state) == true)
    }

    @Test("Deleting a baseline task does not cause completed executions to exceed expected quota in adherence metrics")
    func testBaselineComplianceExpectedCountNeverExceededByCompletedCount() {
        let cal = makeCalendar()
        let clock = makeClock(year: 2026, month: 10, day: 16)

        let b1 = TaskItem(title: "Stretch", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let b2 = TaskItem(title: "Meditation", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let b3 = TaskItem(title: "Wipe counters", tag: "KITCHEN", recurrence: RecurrenceRule(count: 1, unit: .day))

        var history: [HistoryRecord] = []
        for day in 11...15 {
            let date = cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 9))!
            history.append(HistoryRecord(taskId: b1.id, title: "Stretch", tag: "SELF", completedAt: date, isDailyBaseline: true))
            history.append(HistoryRecord(taskId: b2.id, title: "Meditation", tag: "SELF", completedAt: date, isDailyBaseline: true))
            history.append(HistoryRecord(taskId: b3.id, title: "Wipe counters", tag: "KITCHEN", completedAt: date, isDailyBaseline: true))
        }

        var state = DashboardState(
            tasks: [b1, b2, b3],
            historyRecords: history,
            trackingStartDate: cal.date(from: DateComponents(year: 2026, month: 10, day: 11))!
        )

        ChoreEngine.deleteTask(state: &state, id: b3.id)
        #expect(state.tasks.count == 2)

        let compliance = ChoreProjections.baselineCompliance(for: state, clock: clock)
        #expect(compliance.completedCount == 15)
        #expect(compliance.expectedCount >= compliance.completedCount)
        #expect(compliance.compliancePercentage == 100)
        #expect(compliance.isNominal == true)
    }

    @Test("TaskClassificationIndex retains baseline classification for deleted tasks if records were marked baseline")
    func testClassificationIndexLearnsBaselineIdentityFromHistoryRecords() {
        let clock = makeClock(year: 2026, month: 10, day: 16)
        let deletedTaskId = UUID()

        let recordTagged = HistoryRecord(taskId: deletedTaskId, title: "Wipe counters", tag: "KITCHEN", completedAt: clock.now, isDailyBaseline: true)
        let recordUntagged = HistoryRecord(taskId: deletedTaskId, title: "Wipe counters", tag: "KITCHEN", completedAt: clock.calendar.date(byAdding: .day, value: -3, to: clock.now)!, isDailyBaseline: false)

        let state = DashboardState(
            tasks: [],
            historyRecords: [recordTagged, recordUntagged]
        )

        let index = TaskClassificationIndex(tasks: state.tasks, historyRecords: state.historyRecords)
        #expect(index.isBaselineRecord(recordTagged) == true)
        #expect(index.isBaselineRecord(recordUntagged) == true)
    }

    // MARK: - Baseline Compliance Adherence Tiers

    @Test("baselineCompliance classifies adherence tiers at nominal 80%, on-track 70%, and attention thresholds")
    func testBaselineComplianceAdherenceTiers() {
        let cal = makeCalendar()
        let clock = makeClock(year: 2026, month: 5, day: 11) // Day 11 (10 closed days)
        let baseline = TaskItem(title: "Habit", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))

        var startComps = DateComponents(); startComps.year = 2026; startComps.month = 5; startComps.day = 1
        let startDate = cal.date(from: startComps)!

        func makeState(completedDays: Int) -> DashboardState {
            var history: [HistoryRecord] = []
            for d in 1...max(1, completedDays) {
                if completedDays == 0 { break }
                var c = DateComponents(); c.year = 2026; c.month = 5; c.day = d; c.hour = 8
                history.append(HistoryRecord(taskId: baseline.id, title: "Habit", tag: "SELF", completedAt: cal.date(from: c)!, isDailyBaseline: true))
            }
            return DashboardState(tasks: [baseline], historyRecords: history, trackingStartDate: startDate)
        }

        // 1. 80% (8/10) -> NOMINAL
        let state80 = makeState(completedDays: 8)
        let comp80 = ChoreProjections.baselineCompliance(for: state80, clock: clock)
        #expect(comp80.compliancePercentage == 80)
        #expect(comp80.isNominal == true)
        #expect(comp80.statusBadgeText == "NOMINAL")

        // 2. 70% (7/10) -> ON TRACK
        let state70 = makeState(completedDays: 7)
        let comp70 = ChoreProjections.baselineCompliance(for: state70, clock: clock)
        #expect(comp70.compliancePercentage == 70)
        #expect(comp70.isNominal == true)
        #expect(comp70.statusBadgeText == "ON TRACK")

        // 3. 60% (6/10) -> ATTENTION
        let state60 = makeState(completedDays: 6)
        let comp60 = ChoreProjections.baselineCompliance(for: state60, clock: clock)
        #expect(comp60.compliancePercentage == 60)
        #expect(comp60.isNominal == false)
        #expect(comp60.statusBadgeText == "ATTENTION")
    }
}