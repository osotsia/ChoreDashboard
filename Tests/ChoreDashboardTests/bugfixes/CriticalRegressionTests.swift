import Testing
import Foundation
@testable import ChoreDashboard

@Suite("High-Criticality Operational Regressions")
struct CriticalRegressionTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeClock(year: Int = 2026, month: Int = 5, day: Int = 1, hour: Int = 12) -> TestClock {
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

    // MARK: - Bug 1: One-Time Task Rollover Ghosting

    @Test("Completed one-time focus tasks do not become ghost inventory after midnight rollover")
    func testCompletedOneTimeFocusTaskDoesNotGhostAfterRollover() {
        let clockDay1 = makeClock(year: 2026, month: 5, day: 1, hour: 10)
        let oneTimeTaskId = UUID()
        let oneTimeTask = TaskItem(
            id: oneTimeTaskId,
            title: "Repair sink seal",
            tag: "BATHROOM",
            dueDate: clockDay1.now,
            recurrence: nil // One-time execution
        )
        var state = DashboardState(tasks: [oneTimeTask])

        // User completes the one-time task on the Focus board today
        ChoreEngine.toggleTask(state: &state, id: oneTimeTaskId, clock: clockDay1)
        #expect(state.tasks[0].isCompleted == true)

        // Midnight rollover occurs transitioning to Day 2
        let clockDay2 = makeClock(year: 2026, month: 5, day: 2, hour: 8)
        ChoreEngine.rollover(state: &state, clock: clockDay2)

        // System Invariant: Tasks retained in inventory must belong to at least one operational queue.
        // Completed one-time tasks must be purged on rollover (matching completeHorizonTask behavior).
        let inFocus = ChoreProjections.focusQueue(for: state, clock: clockDay2).contains(where: { $0.id == oneTimeTaskId })
        let inHorizon = ChoreProjections.upcomingEvents(for: state, clock: clockDay2).contains(where: { $0.id == oneTimeTaskId })
        let inBaseline = ChoreProjections.baselineTasks(for: state).contains(where: { $0.id == oneTimeTaskId })
        let isPresentInAnyQueue = inFocus || inHorizon || inBaseline

        // Assertion 1: Task must not be orphaned in storage while invisible across all UI lists
        #expect(state.tasks.isEmpty || isPresentInAnyQueue,
                "One-time task is permanently retained in state.tasks but excluded from focus, upcoming, and baseline projections.")

        // Assertion 2: Total inventory counter must equal the sum of distinct operational queues
        let totalPartitionedCount = ChoreProjections.focusQueue(for: state, clock: clockDay2).count
            + ChoreProjections.upcomingEvents(for: state, clock: clockDay2).count
            + ChoreProjections.baselineTasks(for: state).count

        #expect(state.tasks.count == totalPartitionedCount,
                "Inventory count mismatch: state.tasks has \(state.tasks.count) items, but the sum of all queue projections is \(totalPartitionedCount).")
    }

    // MARK: - Bug 2: Task Modification Resets Completion

    @Test("Editing an already completed task preserves its completion status and lastCompletedAt timestamp")
    @MainActor
    func testEditingTaskPreservesCompletionState() {
        let clock = makeClock(year: 2026, month: 5, day: 1, hour: 12)
        let taskId = UUID()
        let completionTimestamp = clock.now

        let completedTask = TaskItem(
            id: taskId,
            title: "Clean Oven",
            tag: "KITCHEN",
            durationMinutes: 45,
            isCompleted: true,
            dueDate: completionTimestamp,
            lastCompletedAt: completionTimestamp,
            recurrence: RecurrenceRule(count: 1, unit: .month)
        )

        let mockPersistence = InMemoryPersistenceClient(initialState: DashboardState(tasks: [completedTask]))
        let store = DashboardStore(
            initialState: DashboardState(tasks: [completedTask]),
            persistenceClient: mockPersistence,
            clock: clock,
            enableSystemIntegration: false
        )

        // User edits the task title to fix a typo
        store.startEditing(task: completedTask)
        store.taskDraft?.title = "Deep Clean Oven & Range"
        store.commitDraft()

        let updatedTask = store.state.tasks.first(where: { $0.id == taskId })

        // Both assertions fail because commitDraft() hardcodes isCompleted = false and lastCompletedAt = nil
        #expect(updatedTask?.isCompleted == true,
                "commitDraft() unconditionally set isCompleted to false on an already completed task.")
        #expect(updatedTask?.lastCompletedAt == completionTimestamp,
                "commitDraft() wiped lastCompletedAt timestamp to nil upon saving edits.")
    }

    // MARK: - Velocity Telemetry Verification

    @Test("Monthly pacing reflects positive velocity lead when maintenance completions outpace quota")
    func testMonthlyPacingLeadingWhenCompletionsOutpaceQuota() {
        let cal = makeCalendar()
        let clockDay15 = makeClock(year: 2026, month: 10, day: 15, hour: 12) // Day 15 of 31-day month

        // Focus maintenance tasks (31 / 7 ≈ 4.4, 31 / 14 ≈ 2.2, 31 / 30 ≈ 1.0 -> Quota = 8)
        let tasks: [TaskItem] = [
            TaskItem(title: "Weekly Air Filter", tag: "GENERAL", recurrence: RecurrenceRule(count: 1, unit: .week)),
            TaskItem(title: "Biweekly Scrub", tag: "BATHROOM", recurrence: RecurrenceRule(count: 2, unit: .week)),
            TaskItem(title: "Monthly Deep Fridge", tag: "KITCHEN", recurrence: RecurrenceRule(count: 1, unit: .month)),
            // Daily baselines must not pollute the monthly maintenance quota denominator
            TaskItem(title: "Morning Stretch", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day)),
            TaskItem(title: "Wipe Counters", tag: "KITCHEN", recurrence: RecurrenceRule(count: 1, unit: .day))
        ]

        // 12 completions logged since Day 10
        var history: [HistoryRecord] = []
        for day in 10...15 {
            var comps = DateComponents()
            comps.year = 2026
            comps.month = 10
            comps.day = day
            comps.hour = 11
            let date = cal.date(from: comps)!

            history.append(HistoryRecord(title: "Weekly Air Filter", tag: "GENERAL", completedAt: date))
            history.append(HistoryRecord(title: "Wipe Counters", tag: "KITCHEN", completedAt: date))
        }

        let state = DashboardState(tasks: tasks, historyRecords: history)
        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clockDay15)

        // Quota is based on maintenance tasks (8), Day 15 target pace is ~4.
        // With 12 actual completions, the velocity gauge correctly reflects a positive lead.
        #expect(pacing.totalMonthlyQuota == 8)
        #expect(pacing.actualCompleted == 12)
        #expect(pacing.deltaLead > 0)
        #expect(pacing.isLeading == true)
    }
}