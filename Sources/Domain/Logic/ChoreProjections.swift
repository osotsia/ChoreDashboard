import Foundation

// MARK: - Operational Telemetry Snapshots

public struct TodayOperationalSnapshot: Sendable, Equatable {
    public let focusTotal: Int
    public let focusCompleted: Int
    public let focusOverdue: Int
    public let focusRemaining: Int

    public let baselineTotal: Int
    public let baselineCompleted: Int
    public let baselineRemaining: Int
    public let baselineMinutesRemaining: Int

    public let totalTasks: Int
    public let completedTasks: Int
    public let clearanceRate: Double
}

public struct MonthlyPacingSnapshot: Sendable, Equatable {
    public let monthTitle: String
    public let currentDay: Int
    public let totalDaysInMonth: Int
    public let actualCompleted: Int
    public let totalMonthlyQuota: Int
    public let deltaLead: Int
    public let actualProgressRatio: Double
    public let expectedProgressRatio: Double
    public let isLeading: Bool
    public let isOnPace: Bool

    public init(
        monthTitle: String,
        currentDay: Int,
        totalDaysInMonth: Int,
        actualCompleted: Int,
        totalMonthlyQuota: Int,
        deltaLead: Int,
        actualProgressRatio: Double,
        expectedProgressRatio: Double,
        isLeading: Bool,
        isOnPace: Bool = false
    ) {
        self.monthTitle = monthTitle
        self.currentDay = currentDay
        self.totalDaysInMonth = totalDaysInMonth
        self.actualCompleted = actualCompleted
        self.totalMonthlyQuota = totalMonthlyQuota
        self.deltaLead = deltaLead
        self.actualProgressRatio = actualProgressRatio
        self.expectedProgressRatio = expectedProgressRatio
        self.isLeading = isLeading
        self.isOnPace = isOnPace
    }
}

public struct BaselineComplianceSnapshot: Sendable, Equatable {
    public let completedCount: Int
    public let expectedCount: Int
    public let complianceRatio: Double
    public let compliancePercentage: Int
    public let activeDaysTracked: Int
    public let totalBaselineTasks: Int
    public let isNominal: Bool
    public let statusBadgeText: String

    public init(
        completedCount: Int,
        expectedCount: Int,
        complianceRatio: Double,
        compliancePercentage: Int,
        activeDaysTracked: Int,
        totalBaselineTasks: Int,
        isNominal: Bool,
        statusBadgeText: String = "NOMINAL"
    ) {
        self.completedCount = completedCount
        self.expectedCount = expectedCount
        self.complianceRatio = complianceRatio
        self.compliancePercentage = compliancePercentage
        self.activeDaysTracked = activeDaysTracked
        self.totalBaselineTasks = totalBaselineTasks
        self.isNominal = isNominal
        self.statusBadgeText = statusBadgeText
    }
}

// MARK: - Temporal Boundaries & Indexing Primitives

/// Encapsulates monthly calendar boundaries, active tracking windows, and elapsed ratios.
public struct ActiveMonthWindow: Sendable, Equatable {
    public let referenceDate: Date
    public let monthTitle: String
    public let currentDay: Int
    public let totalDaysInMonth: Int
    public let startDay: Int
    public let activeDaysElapsed: Int
    public let totalActiveDays: Int
    public let completedDays: Int
    public let timeElapsedRatio: Double

    public init(
        now: Date,
        trackingStartDate: Date?,
        fallbackStartDay: Int = 1,
        calendar: Calendar
    ) {
        self.referenceDate = now
        self.currentDay = calendar.component(.day, from: now)
        self.totalDaysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30

        self.monthTitle = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
            .month(.wide)
            .format(now)
            .uppercased()

        if let explicit = trackingStartDate,
           calendar.isDate(explicit, equalTo: now, toGranularity: .month),
           calendar.isDate(explicit, equalTo: now, toGranularity: .year) {
            self.startDay = min(currentDay, max(1, calendar.component(.day, from: explicit)))
        } else {
            self.startDay = min(currentDay, max(1, fallbackStartDay))
        }

        self.activeDaysElapsed = max(1, currentDay - startDay + 1)
        self.totalActiveDays = max(1, totalDaysInMonth - startDay + 1)
        self.completedDays = max(0, activeDaysElapsed - 1)
        self.timeElapsedRatio = min(1.0, Double(activeDaysElapsed) / Double(totalActiveDays))
    }
}

/// Provides O(1) set-based disambiguation between daily baseline routines and maintenance tasks.
public struct TaskClassificationIndex: Sendable {
    public let allTaskIds: Set<UUID>
    public let baselineTaskIds: Set<UUID>
    public let baselineTitles: Set<String>

    public init(tasks: [TaskItem], historyRecords: [HistoryRecord] = []) {
        var allIds = Set<UUID>()
        var baseIds = Set<UUID>()
        var titles = Set<String>()

        for task in tasks {
            allIds.insert(task.id)
            if task.isDailyBaseline {
                baseIds.insert(task.id)
                titles.insert(task.title.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
            }
        }

        // Index historical records explicitly flagged as daily baseline so that
        // deleting an active task never causes historical completions to drift into maintenance
        for record in historyRecords where record.isDailyBaseline {
            if let taskId = record.taskId {
                baseIds.insert(taskId)
            }
            titles.insert(record.title.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
        }

        self.allTaskIds = allIds
        self.baselineTaskIds = baseIds
        self.baselineTitles = titles
    }

    public func isBaselineRecord(_ record: HistoryRecord) -> Bool {
        if record.isDailyBaseline { return true }
        if let taskId = record.taskId {
            if baselineTaskIds.contains(taskId) { return true }
            if allTaskIds.contains(taskId) { return false }
        }
        let cleanTitle = record.title.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return baselineTitles.contains(cleanTitle)
    }
}

// MARK: - Dual-Threshold Pacing Engine

public struct PacingResult: Sendable, Equatable {
    public let deltaLead: Int
    public let isOnPace: Bool
    public let isLeading: Bool
}

public struct MaintenancePacingTargets: Sendable, Equatable {
    public let totalMonthlyQuota: Int
    public let expectedPrior: Double
    public let expectedToday: Double
}

public enum PacingMath {
    /// Evaluates operational pacing against yesterday's closed-day quota and today's active ceiling.
    public static func evaluate(
        actualCompletions: Int,
        targets: MaintenancePacingTargets
    ) -> PacingResult {
        guard targets.totalMonthlyQuota > 0 else {
            return PacingResult(deltaLead: 0, isOnPace: true, isLeading: true)
        }

        let targetPriorInt = Int(floor(targets.expectedPrior))
        let targetTodayInt = Int(ceil(targets.expectedToday))

        if actualCompletions >= targetTodayInt {
            let lead = actualCompletions - Int(round(targets.expectedToday))
            if lead > 0 {
                return PacingResult(deltaLead: lead, isOnPace: false, isLeading: true)
            } else {
                return PacingResult(deltaLead: 0, isOnPace: true, isLeading: true)
            }
        } else if actualCompletions >= targetPriorInt {
            return PacingResult(deltaLead: 0, isOnPace: true, isLeading: true)
        } else {
            let deficit = actualCompletions - Int(round(targets.expectedPrior))
            return PacingResult(deltaLead: deficit, isOnPace: false, isLeading: false)
        }
    }

    /// Convenience evaluator for direct scalar testing against a uniform active window.
    public static func evaluate(
        actualCompletions: Int,
        quota: Int,
        window: ActiveMonthWindow
    ) -> PacingResult {
        let expectedPrior = Double(quota) * (Double(window.completedDays) / Double(window.totalActiveDays))
        let expectedToday = Double(quota) * (Double(window.activeDaysElapsed) / Double(window.totalActiveDays))
        let targets = MaintenancePacingTargets(
            totalMonthlyQuota: quota,
            expectedPrior: expectedPrior,
            expectedToday: expectedToday
        )
        return evaluate(actualCompletions: actualCompletions, targets: targets)
    }
}

// MARK: - Pure Projections Engine

public enum ChoreProjections {

    public static func baselineTasks(for state: DashboardState) -> [TaskItem] {
        state.tasks.filter { $0.isDailyBaseline }
    }

    public static func baselineTotalMinutes(for state: DashboardState) -> Int {
        baselineTasks(for: state).reduce(0) { $0 + $1.durationMinutes }
    }

    public static func focusQueue(for state: DashboardState, clock: Clock) -> [TaskItem] {
        let calendar = clock.calendar
        let today = calendar.startOfDay(for: clock.now)

        return state.tasks.filter { task in
            guard !task.isDailyBaseline else { return false }

            let taskDue = calendar.startOfDay(for: task.dueDate)
            let isOverdueOrDueToday = taskDue <= today

            if task.isCompleted {
                if let completedAt = task.lastCompletedAt {
                    return calendar.isDate(completedAt, inSameDayAs: clock.now)
                }
                return isOverdueOrDueToday
            }
            return isOverdueOrDueToday
        }
    }

    public static func upcomingEvents(for state: DashboardState, clock: Clock) -> [TaskItem] {
        let calendar = clock.calendar
        let today = calendar.startOfDay(for: clock.now)

        return state.tasks.filter { task in
            guard !task.isDailyBaseline else { return false }
            let taskDue = calendar.startOfDay(for: task.dueDate)
            return taskDue > today && !task.isCompleted
        }
    }

    public static func sortedUpcomingEvents(for state: DashboardState, clock: Clock) -> [TaskItem] {
        upcomingEvents(for: state, clock: clock).sorted {
            let days0 = $0.estimatedDaysRemaining(relativeTo: clock.now, calendar: clock.calendar)
            let days1 = $1.estimatedDaysRemaining(relativeTo: clock.now, calendar: clock.calendar)
            if days0 != days1 { return days0 < days1 }
            return $0.title < $1.title
        }
    }

    public static func todaySnapshot(for state: DashboardState, clock: Clock) -> TodayOperationalSnapshot {
        let fQueue = focusQueue(for: state, clock: clock)
        let fTotal = fQueue.count
        let fDone = fQueue.filter { $0.isCompleted }.count
        let fOverdue = fQueue.filter { $0.healthState(using: clock) == .overdue && !$0.isCompleted }.count
        let fRemaining = fTotal - fDone

        let bTasks = baselineTasks(for: state)
        let bTotal = bTasks.count
        let bDone = bTasks.filter { $0.isCompleted }.count
        let bRemaining = bTotal - bDone
        let bMinsLeft = bTasks.filter { !$0.isCompleted }.reduce(0) { $0 + $1.durationMinutes }

        let total = fTotal + bTotal
        let completed = fDone + bDone
        let rate = total > 0 ? Double(completed) / Double(total) : 1.0

        return TodayOperationalSnapshot(
            focusTotal: fTotal,
            focusCompleted: fDone,
            focusOverdue: fOverdue,
            focusRemaining: fRemaining,
            baselineTotal: bTotal,
            baselineCompleted: bDone,
            baselineRemaining: bRemaining,
            baselineMinutesRemaining: bMinsLeft,
            totalTasks: total,
            completedTasks: completed,
            clearanceRate: rate
        )
    }

    /// Evaluates whether a history record corresponds to a daily baseline task.
    public static func isBaselineRecord(_ record: HistoryRecord, in state: DashboardState) -> Bool {
        TaskClassificationIndex(tasks: state.tasks, historyRecords: state.historyRecords).isBaselineRecord(record)
    }

    /// Calculates target pace and lead/deficit metrics for non-routine maintenance operations.
    public static func monthlyPacing(for state: DashboardState, clock: Clock) -> MonthlyPacingSnapshot {
        let calendar = clock.calendar
        let now = clock.now
        let window = ActiveMonthWindow(
            now: now,
            trackingStartDate: state.trackingStartDate,
            fallbackStartDay: 1,
            calendar: calendar
        )
        let index = TaskClassificationIndex(tasks: state.tasks, historyRecords: state.historyRecords)

        let completionsThisMonth = state.historyRecords.filter { record in
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .month) &&
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .year) &&
            !index.isBaselineRecord(record)
        }.count

        let targets = calculateMaintenanceTargets(
            tasks: state.tasks,
            window: window,
            calendar: calendar,
            completionsThisMonth: completionsThisMonth
        )

        let pacing = PacingMath.evaluate(
            actualCompletions: completionsThisMonth,
            targets: targets
        )

        let actualRatio = targets.totalMonthlyQuota > 0
            ? min(1.0, Double(completionsThisMonth) / Double(targets.totalMonthlyQuota))
            : 0.0

        return MonthlyPacingSnapshot(
            monthTitle: window.monthTitle,
            currentDay: window.currentDay,
            totalDaysInMonth: window.totalDaysInMonth,
            actualCompleted: completionsThisMonth,
            totalMonthlyQuota: targets.totalMonthlyQuota,
            deltaLead: pacing.deltaLead,
            actualProgressRatio: actualRatio,
            expectedProgressRatio: window.timeElapsedRatio,
            isLeading: pacing.isLeading,
            isOnPace: pacing.isOnPace
        )
    }

    /// Evaluates daily baseline routine compliance over active tracking days without pre-billing in-progress hours.
    public static func baselineCompliance(for state: DashboardState, clock: Clock) -> BaselineComplianceSnapshot {
        let calendar = clock.calendar
        let now = clock.now

        let baselineList = baselineTasks(for: state)
        let bTotal = baselineList.count

        guard bTotal > 0 else {
            return BaselineComplianceSnapshot(
                completedCount: 0,
                expectedCount: 0,
                complianceRatio: 1.0,
                compliancePercentage: 100,
                activeDaysTracked: 0,
                totalBaselineTasks: 0,
                isNominal: true,
                statusBadgeText: "NOMINAL"
            )
        }

        let index = TaskClassificationIndex(tasks: state.tasks, historyRecords: state.historyRecords)

        let monthBaselineRecords = state.historyRecords.filter { record in
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .month) &&
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .year) &&
            index.isBaselineRecord(record)
        }

        let fallbackDay: Int
        if let earliest = monthBaselineRecords.map(\.completedAt).min() {
            fallbackDay = calendar.component(.day, from: earliest)
        } else {
            fallbackDay = calendar.component(.day, from: now)
        }

        let window = ActiveMonthWindow(
            now: now,
            trackingStartDate: state.trackingStartDate,
            fallbackStartDay: fallbackDay,
            calendar: calendar
        )

        let completedToday = monthBaselineRecords.filter {
            calendar.isDate($0.completedAt, inSameDayAs: now)
        }.count

        let totalCompleted = monthBaselineRecords.count

        // Closed days require full baseline quota; in-progress today adds only what has been completed
        let rawExpected: Int
        if window.completedDays == 0 {
            rawExpected = max(0, min(bTotal, completedToday))
        } else {
            let closedExpected = bTotal * window.completedDays
            rawExpected = closedExpected + max(0, min(bTotal, completedToday))
        }

        // Invariant: Expected quota must never drop below recorded executions when tasks are deleted mid-window
        let expectedCount = max(rawExpected, totalCompleted)

        let ratio = expectedCount > 0 ? Double(totalCompleted) / Double(expectedCount) : 1.0
        let percentage = Int(round(min(1.0, ratio) * 100))

        let statusText: String
        let isNominal: Bool
        if ratio >= 0.80 {
            statusText = "NOMINAL"
            isNominal = true
        } else if ratio >= 0.70 {
            statusText = "ON TRACK"
            isNominal = true
        } else {
            statusText = "ATTENTION"
            isNominal = false
        }

        return BaselineComplianceSnapshot(
            completedCount: totalCompleted,
            expectedCount: expectedCount,
            complianceRatio: ratio,
            compliancePercentage: percentage,
            activeDaysTracked: window.activeDaysElapsed,
            totalBaselineTasks: bTotal,
            isNominal: isNominal,
            statusBadgeText: statusText
        )
    }

    public static func availableTags(for state: DashboardState) -> [String] {
        var tags = Set<String>()
        for tag in state.customTags { tags.insert(tag) }
        for task in state.tasks { tags.insert(task.tag) }
        for record in state.historyRecords { tags.insert(record.tag) }

        let clean = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
            .sorted()

        let defaultFallback = ["BATHROOM", "GENERAL", "KITCHEN", "SELF"]
        return clean.isEmpty ? defaultFallback : clean
    }

    // MARK: - Internal Helpers

    internal static func calculateMaintenanceTargets(
        tasks: [TaskItem],
        window: ActiveMonthWindow,
        calendar: Calendar,
        completionsThisMonth: Int
    ) -> MaintenancePacingTargets {
        var totalQuotaAccumulator: Double = 0
        var expectedPriorAccumulator: Double = 0
        var expectedTodayAccumulator: Double = 0

        for task in tasks where !task.isDailyBaseline {
            let taskStartDay: Int
            if calendar.isDate(task.createdAt, equalTo: window.referenceDate, toGranularity: .month),
               calendar.isDate(task.createdAt, equalTo: window.referenceDate, toGranularity: .year) {
                let createdDay = calendar.component(.day, from: task.createdAt)
                taskStartDay = min(window.currentDay, max(window.startDay, createdDay))
            } else {
                taskStartDay = window.startDay
            }

            let taskActiveDays = max(1, window.totalDaysInMonth - taskStartDay + 1)
            let taskClosedDays = max(0, window.currentDay - taskStartDay)
            let taskDaysElapsed = max(1, window.currentDay - taskStartDay + 1)

            if let recurrence = task.recurrence {
                let intervalDays = max(1, recurrence.intervalDays)
                let runsThisMonth = Double(taskActiveDays) / Double(intervalDays)
                totalQuotaAccumulator += runsThisMonth
                expectedPriorAccumulator += Double(taskClosedDays) / Double(intervalDays)
                expectedTodayAccumulator += Double(taskDaysElapsed) / Double(intervalDays)
            } else {
                totalQuotaAccumulator += 1.0
                if taskStartDay < window.currentDay {
                    expectedPriorAccumulator += 1.0
                }
                expectedTodayAccumulator += 1.0
            }
        }

        let plannedQuota = Int(round(totalQuotaAccumulator))
        let totalMonthlyQuota = plannedQuota > 0 ? plannedQuota : completionsThisMonth

        return MaintenancePacingTargets(
            totalMonthlyQuota: totalMonthlyQuota,
            expectedPrior: expectedPriorAccumulator,
            expectedToday: expectedTodayAccumulator
        )
    }
}