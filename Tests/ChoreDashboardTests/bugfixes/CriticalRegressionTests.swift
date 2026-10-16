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
        // If a one-time task is finished, it must either be purged on rollover (as completeHorizonTask does)
        // or remain accessible in an active queue.
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

    // MARK: - Bug 3: Monthly Velocity Quota vs Completions Mismatch

    @Test("Monthly pacing quota matches the scope of completions being tracked")
    func testMonthlyPacingQuotaMatchesCompletionsScope() {
        let cal = makeCalendar()
        let clockDay3 = makeClock(year: 2026, month: 5, day: 3, hour: 12) // Day 3 of 31-day month

        // Quota basis: 1 weekly focus task (31 / 7 ≈ 4.4 -> quota = 4)
        let focusTask = TaskItem(
            id: UUID(),
            title: "HVAC Filter Check",
            tag: "GENERAL",
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )

        // 3 Daily baseline tasks (3 * 31 days = 93 expected runs/month)
        let b1 = TaskItem(title: "Morning Stretch", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let b2 = TaskItem(title: "Meditation", tag: "SELF", recurrence: RecurrenceRule(count: 1, unit: .day))
        let b3 = TaskItem(title: "Wipe Counters", tag: "KITCHEN", recurrence: RecurrenceRule(count: 1, unit: .day))

        // History: User completed all 3 baseline tasks for Days 1, 2, and 3 (9 completions total).
        // Zero focus tasks were completed.
        var history: [HistoryRecord] = []
        for day in 1...3 {
            var comps = DateComponents()
            comps.year = 2026
            comps.month = 5
            comps.day = day
            comps.hour = 9
            let date = cal.date(from: comps)!

            history.append(HistoryRecord(taskId: b1.id, title: b1.title, tag: b1.tag, completedAt: date))
            history.append(HistoryRecord(taskId: b2.id, title: b2.title, tag: b2.tag, completedAt: date))
            history.append(HistoryRecord(taskId: b3.id, title: b3.title, tag: b3.tag, completedAt: date))
        }

        let state = DashboardState(
            tasks: [focusTask, b1, b2, b3],
            historyRecords: history
        )

        let pacing = ChoreProjections.monthlyPacing(for: state, clock: clockDay3)

        // System Invariant:
        // Case A: If totalMonthlyQuota measures focus tasks only (where !task.isDailyBaseline),
        //         actualCompleted must ONLY count focus completions (expected: 0).
        // Case B: If actualCompleted counts all history records including daily habits (actual: 9),
        //         totalMonthlyQuota must include daily baselines in the denominator (expected: >= 97).
        let isFocusScoped = (pacing.actualCompleted == 0)
        let isQuotaInclusiveOfBaselines = (pacing.totalMonthlyQuota >= 90)

        // Fails because totalMonthlyQuota is 4 while actualCompleted is 9,
        // causing actualProgressRatio to clamp to 1.0 (100%) and register a false lead on Day 3.
        #expect(isFocusScoped || isQuotaInclusiveOfBaselines,
                """
                Scope mismatch: totalMonthlyQuota (\(pacing.totalMonthlyQuota)) excludes baseline habits, \
                but actualCompleted (\(pacing.actualCompleted)) includes them. \
                Actual progress ratio is falsely saturated at \(pacing.actualProgressRatio * 100)% on Day 3.
                """)
    }
}