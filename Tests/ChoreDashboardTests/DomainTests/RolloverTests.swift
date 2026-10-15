import Testing
import Foundation
@testable import ChoreDashboard

@Suite("Midnight Rollover State Mutations")
struct RolloverTests {

    private func makeCalendar(timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    private func makeClock(
        year: Int = 2026,
        month: Int = 5,
        day: Int = 1,
        hour: Int = 12,
        minute: Int = 0,
        second: Int = 0,
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!
    ) -> TestClock {
        let cal = makeCalendar(timeZone: timeZone)
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return TestClock(now: cal.date(from: comps)!, calendar: cal)
    }

    @Test("Rollover uncompletes past tasks and advances recurring due dates from last completed date")
    func testRolloverAdvancesPastTasks() {
        let cal = makeCalendar()
        let clockDay1 = makeClock(year: 2026, month: 5, day: 1)

        let taskId = UUID()
        let task = TaskItem(
            id: taskId,
            title: "Scrub Sink",
            tag: "KITCHEN",
            isCompleted: true,
            dueDate: clockDay1.now,
            lastCompletedAt: clockDay1.now,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )
        var state = DashboardState(tasks: [task])

        let clockDay2 = makeClock(year: 2026, month: 5, day: 2)

        let mutated = ChoreEngine.rollover(state: &state, clock: clockDay2)
        #expect(mutated == true)
        #expect(state.tasks[0].isCompleted == false)
        let expectedDue = cal.date(byAdding: .day, value: 7, to: clockDay1.now)!
        #expect(state.tasks[0].dueDate == expectedDue)
    }

    @Test("Rollover evaluates across exact midnight second boundary (23:59:59 to 00:00:01)")
    func testRolloverExactMidnightSecondTransition() {
        let clockPreMidnight = makeClock(year: 2026, month: 5, day: 1, hour: 23, minute: 59, second: 59)
        let task = TaskItem(
            title: "Night Routine",
            tag: "SELF",
            isCompleted: true,
            dueDate: clockPreMidnight.now,
            lastCompletedAt: clockPreMidnight.now,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )
        var state = DashboardState(tasks: [task])

        let clockPostMidnight = makeClock(year: 2026, month: 5, day: 2, hour: 0, minute: 0, second: 1)
        let mutated = ChoreEngine.rollover(state: &state, clock: clockPostMidnight)

        #expect(mutated == true)
        #expect(state.tasks[0].isCompleted == false)

        let clockSameDayLater = makeClock(year: 2026, month: 5, day: 2, hour: 0, minute: 0, second: 2)
        let mutatedAgain = ChoreEngine.rollover(state: &state, clock: clockSameDayLater)
        #expect(mutatedAgain == false)
    }

    @Test("Rollover functions accurately in extreme timezones (+14 Kiritimati and -10 Hawaii)")
    func testRolloverExtremeTimezones() {
        let tzPlus14 = TimeZone(secondsFromGMT: 14 * 3600)!
        let clockPlus14Day1 = makeClock(year: 2026, month: 5, day: 1, hour: 23, minute: 30, timeZone: tzPlus14)
        let task1 = TaskItem(
            title: "Pacific Task",
            tag: "GENERAL",
            isCompleted: true,
            lastCompletedAt: clockPlus14Day1.now,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )
        var state1 = DashboardState(tasks: [task1])

        let clockPlus14Day2 = makeClock(year: 2026, month: 5, day: 2, hour: 1, minute: 0, timeZone: tzPlus14)
        #expect(ChoreEngine.rollover(state: &state1, clock: clockPlus14Day2) == true)
        #expect(state1.tasks[0].isCompleted == false)

        let tzMinus10 = TimeZone(secondsFromGMT: -10 * 3600)!
        let clockMinus10Day1 = makeClock(year: 2026, month: 5, day: 1, hour: 23, minute: 45, timeZone: tzMinus10)
        let task2 = TaskItem(
            title: "Hawaii Task",
            tag: "GENERAL",
            isCompleted: true,
            lastCompletedAt: clockMinus10Day1.now,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )
        var state2 = DashboardState(tasks: [task2])

        let clockMinus10Day2 = makeClock(year: 2026, month: 5, day: 2, hour: 0, minute: 15, timeZone: tzMinus10)
        #expect(ChoreEngine.rollover(state: &state2, clock: clockMinus10Day2) == true)
        #expect(state2.tasks[0].isCompleted == false)
    }

    @Test("Rollover skips tasks completed on the current calendar day")
    func testRolloverSkipsCurrentDayCompletions() {
        let clock = makeClock(year: 2026, month: 5, day: 1)
        let task = TaskItem(
            title: "Task",
            tag: "TEST",
            isCompleted: true,
            lastCompletedAt: clock.now,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )
        var state = DashboardState(tasks: [task])

        let mutated = ChoreEngine.rollover(state: &state, clock: clock)
        #expect(mutated == false)
        #expect(state.tasks[0].isCompleted == true)
    }

    @Test("Rollover resets daily baseline isCompleted flag without altering due date")
    func testRolloverBaselineDueDatePreservation() {
        let clockDay1 = makeClock(year: 2026, month: 5, day: 1)
        let baseline = TaskItem(
            title: "Morning Habit",
            tag: "SELF",
            isCompleted: true,
            dueDate: clockDay1.now,
            lastCompletedAt: clockDay1.now,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )
        var state = DashboardState(tasks: [baseline])

        let clockDay2 = makeClock(year: 2026, month: 5, day: 2)
        let mutated = ChoreEngine.rollover(state: &state, clock: clockDay2)

        #expect(mutated == true)
        #expect(state.tasks[0].isCompleted == false)
        #expect(state.tasks[0].dueDate == clockDay1.now)
    }

    @Test("Rollover ignores uncompleted tasks and one-time tasks")
    func testRolloverIgnoresUncompletedAndOneTime() {
        let clockDay1 = makeClock(year: 2026, month: 5, day: 1)
        let uncompleted = TaskItem(title: "Undone", tag: "TEST", isCompleted: false, recurrence: RecurrenceRule(count: 1, unit: .week))
        let oneTimeDone = TaskItem(title: "OneTime", tag: "TEST", isCompleted: true, lastCompletedAt: clockDay1.now, recurrence: nil)
        var state = DashboardState(tasks: [uncompleted, oneTimeDone])

        let clockDay2 = makeClock(year: 2026, month: 5, day: 2)
        let mutated = ChoreEngine.rollover(state: &state, clock: clockDay2)

        #expect(mutated == false)
        #expect(state.tasks[0].isCompleted == false)
        #expect(state.tasks[1].isCompleted == true)
    }

    @Test("Rollover handles multi-day calendar gap and uncompletes dormant tasks")
    func testRolloverMultiDayJump() {
        let cal = makeCalendar()
        let clockPast = makeClock(year: 2026, month: 5, day: 1)
        let completedDate = clockPast.now

        let task = TaskItem(
            title: "Weekly Air Filter Check",
            tag: "GENERAL",
            isCompleted: true,
            dueDate: completedDate,
            lastCompletedAt: completedDate,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )
        var state = DashboardState(tasks: [task])

        let clockFuture = makeClock(year: 2026, month: 5, day: 22)
        let mutated = ChoreEngine.rollover(state: &state, clock: clockFuture)

        #expect(mutated == true)
        #expect(state.tasks[0].isCompleted == false)
        let expectedDue = cal.date(byAdding: .day, value: 7, to: completedDate)!
        #expect(state.tasks[0].dueDate == expectedDue)
    }

    @Test("Rollover transitions across leap year day boundaries without date distortion")
    func testRolloverLeapYearCrossing() {
        let cal = makeCalendar()
        let clockFeb28 = makeClock(year: 2028, month: 2, day: 28)
        let task = TaskItem(
            title: "Leap Day Task",
            tag: "GENERAL",
            isCompleted: true,
            dueDate: clockFeb28.now,
            lastCompletedAt: clockFeb28.now,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )
        var state = DashboardState(tasks: [task])

        let clockFeb29 = makeClock(year: 2028, month: 2, day: 29)
        let mutated = ChoreEngine.rollover(state: &state, clock: clockFeb29)

        #expect(mutated == true)
        #expect(state.tasks[0].isCompleted == false)
        let expectedDue = cal.date(byAdding: .day, value: 7, to: clockFeb28.now)!
        #expect(state.tasks[0].dueDate == expectedDue)
    }

    @Test("Rollover transitions cleanly across month-end calendar boundaries")
    func testRolloverMonthEndCrossing() {
        let cal = makeCalendar()
        let clockMay31 = makeClock(year: 2026, month: 5, day: 31)
        let task = TaskItem(
            title: "Month End Chore",
            tag: "GENERAL",
            isCompleted: true,
            dueDate: clockMay31.now,
            lastCompletedAt: clockMay31.now,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )
        var state = DashboardState(tasks: [task])

        let clockJune1 = makeClock(year: 2026, month: 6, day: 1)
        let mutated = ChoreEngine.rollover(state: &state, clock: clockJune1)

        #expect(mutated == true)
        #expect(state.tasks[0].isCompleted == false)
        let expectedDue = cal.date(byAdding: .day, value: 7, to: clockMay31.now)!
        #expect(state.tasks[0].dueDate == expectedDue)
    }

    // MARK: - DST Transitions & Multi-Month Drift

    @Test("Rollover uncompletes tasks across DST Spring Forward (23-hour day)")
    func testRolloverAcrossDaylightSavingTimeSpringForward() {
        let tz = TimeZone(identifier: "America/New_York")!
        let cal = makeCalendar(timeZone: tz)

        let clockPre = makeClock(year: 2026, month: 3, day: 7, hour: 23, minute: 45, timeZone: tz)
        let task = TaskItem(
            title: "Night Routine",
            tag: "SELF",
            isCompleted: true,
            dueDate: clockPre.now,
            lastCompletedAt: clockPre.now,
            recurrence: RecurrenceRule(count: 1, unit: .day)
        )
        var state = DashboardState(tasks: [task])

        let clockPost = makeClock(year: 2026, month: 3, day: 8, hour: 10, minute: 0, timeZone: tz)
        let mutated = ChoreEngine.rollover(state: &state, clock: clockPost)

        #expect(mutated == true)
        #expect(state.tasks[0].isCompleted == false)
        #expect(cal.isDate(state.tasks[0].dueDate, inSameDayAs: clockPre.now))
    }

    @Test("Rollover uncompletes tasks across DST Fall Back (25-hour day)")
    func testRolloverAcrossDaylightSavingTimeFallBack() {
        let tz = TimeZone(identifier: "America/New_York")!
        let cal = makeCalendar(timeZone: tz)

        let clockPre = makeClock(year: 2026, month: 10, day: 31, hour: 23, minute: 50, timeZone: tz)
        let task = TaskItem(
            title: "Check Windows",
            tag: "GENERAL",
            isCompleted: true,
            dueDate: clockPre.now,
            lastCompletedAt: clockPre.now,
            recurrence: RecurrenceRule(count: 2, unit: .day)
        )
        var state = DashboardState(tasks: [task])

        let clockPost = makeClock(year: 2026, month: 11, day: 1, hour: 9, minute: 0, timeZone: tz)
        let mutated = ChoreEngine.rollover(state: &state, clock: clockPost)

        #expect(mutated == true)
        #expect(state.tasks[0].isCompleted == false)
        let expectedDue = cal.date(byAdding: .day, value: 2, to: clockPre.now)!
        #expect(state.tasks[0].dueDate == expectedDue)
    }

    @Test("Recurring monthly tasks maintain deterministic 30-day cadence across irregular month lengths")
    func testRecurringCadenceAcrossVaryingMonthLengths() {
        let cal = makeCalendar()
        let clockJan31 = makeClock(year: 2026, month: 1, day: 31)

        let task = TaskItem(
            title: "Monthly Filter Change",
            tag: "GENERAL",
            isCompleted: true,
            dueDate: clockJan31.now,
            lastCompletedAt: clockJan31.now,
            recurrence: RecurrenceRule(count: 1, unit: .month)
        )
        var state = DashboardState(tasks: [task])

        let clockFeb1 = makeClock(year: 2026, month: 2, day: 1)
        ChoreEngine.rollover(state: &state, clock: clockFeb1)

        #expect(state.tasks[0].isCompleted == false)
        let expectedDue = cal.date(byAdding: .day, value: 30, to: clockJan31.now)!
        #expect(state.tasks[0].dueDate == expectedDue)

        let march2Comps = cal.dateComponents([.month, .day], from: state.tasks[0].dueDate)
        #expect(march2Comps.month == 3)
        #expect(march2Comps.day == 2)
    }

    @Test("Rollover calculates forward from lastCompletedAt even if task was severely overdue")
    func testRolloverSeverelyOverdueRecurringTask() {
        let cal = makeCalendar()
        let clockNow = makeClock(year: 2026, month: 5, day: 20)
        let completedDate = cal.date(byAdding: .day, value: -1, to: clockNow.now)!
        let oldDueDate = cal.date(byAdding: .day, value: -40, to: clockNow.now)!

        let task = TaskItem(
            title: "Clean Oven",
            tag: "KITCHEN",
            isCompleted: true,
            dueDate: oldDueDate,
            lastCompletedAt: completedDate,
            recurrence: RecurrenceRule(count: 2, unit: .week)
        )
        var state = DashboardState(tasks: [task])

        let mutated = ChoreEngine.rollover(state: &state, clock: clockNow)
        #expect(mutated == true)
        #expect(state.tasks[0].isCompleted == false)
        let expectedDue = cal.date(byAdding: .day, value: 14, to: completedDate)!
        #expect(state.tasks[0].dueDate == expectedDue)
    }

    @Test("Rollover on a task completed multiple intervals ago sets due date strictly relative to lastCompletedAt")
    func testRolloverStaleTaskIntervalCalculation() {
        let cal = makeCalendar()
        let clockNow = makeClock(year: 2026, month: 5, day: 25)
        let completedThreeWeeksAgo = cal.date(byAdding: .day, value: -21, to: clockNow.now)!

        let task = TaskItem(
            title: "Weekly Compost Bin Wash",
            tag: "KITCHEN",
            isCompleted: true,
            dueDate: completedThreeWeeksAgo,
            lastCompletedAt: completedThreeWeeksAgo,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )
        var state = DashboardState(tasks: [task])

        let mutated = ChoreEngine.rollover(state: &state, clock: clockNow)
        #expect(mutated == true)
        #expect(state.tasks[0].isCompleted == false)

        let expectedDueDate = cal.date(byAdding: .day, value: 7, to: completedThreeWeeksAgo)!
        #expect(state.tasks[0].dueDate == expectedDueDate)
        #expect(state.tasks[0].healthState(using: clockNow) == .overdue)
    }

    @Test("Rollover preserves non-temporal task properties intact")
    func testRolloverPreservesNonTemporalTaskProperties() {
        let clockDay1 = makeClock(year: 2026, month: 5, day: 1)
        let taskId = UUID()
        let originalTask = TaskItem(
            id: taskId,
            title: "Clean Dryer Vent",
            tag: "LAUNDRY",
            durationMinutes: 30,
            isCompleted: true,
            dueDate: clockDay1.now,
            lastCompletedAt: clockDay1.now,
            recurrence: RecurrenceRule(count: 2, unit: .week)
        )
        var state = DashboardState(tasks: [originalTask])

        let clockDay2 = makeClock(year: 2026, month: 5, day: 2)
        ChoreEngine.rollover(state: &state, clock: clockDay2)

        let mutatedTask = state.tasks[0]
        #expect(mutatedTask.id == taskId)
        #expect(mutatedTask.title == "Clean Dryer Vent")
        #expect(mutatedTask.tag == "LAUNDRY")
        #expect(mutatedTask.durationMinutes == 30)
        #expect(mutatedTask.recurrence == RecurrenceRule(count: 2, unit: .week))
    }
}