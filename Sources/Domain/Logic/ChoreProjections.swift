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
        if record.isDailyBaseline { return true }
        if let taskId = record.taskId, let task = state.tasks.first(where: { $0.id == taskId }) {
            return task.isDailyBaseline
        }
        if state.tasks.contains(where: { $0.isDailyBaseline && $0.title == record.title }) {
            return true
        }
        return false
    }

    public static func monthlyPacing(for state: DashboardState, clock: Clock) -> MonthlyPacingSnapshot {
        let calendar = clock.calendar
        let now = clock.now

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "LLLL"
        monthFormatter.calendar = calendar
        monthFormatter.timeZone = calendar.timeZone
        let monthTitle = monthFormatter.string(from: now).uppercased()

        let totalDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = calendar.component(.day, from: now)

        // Mid-month installation adjustment
        let startDay: Int
        if let explicit = state.trackingStartDate,
           calendar.isDate(explicit, equalTo: now, toGranularity: .month),
           calendar.isDate(explicit, equalTo: now, toGranularity: .year) {
            startDay = min(currentDay, max(1, calendar.component(.day, from: explicit)))
        } else {
            startDay = 1
        }

        let activeDaysElapsed = max(1, currentDay - startDay + 1)
        let totalActiveDaysInMonth = max(1, totalDays - startDay + 1)
        let completedDays = max(0, activeDaysElapsed - 1)

        // Maintenance quota calculates target pace for non-routine maintenance operations
        var fullMonthMaintenanceQuota: Double = 0
        for task in state.tasks where !task.isDailyBaseline {
            if let recurrence = task.recurrence {
                let intervalDays = max(1, recurrence.intervalDays)
                let runsPerMonth = Double(totalDays) / Double(intervalDays)
                fullMonthMaintenanceQuota += runsPerMonth
            } else {
                fullMonthMaintenanceQuota += 1
            }
        }

        if fullMonthMaintenanceQuota == 0 {
            fullMonthMaintenanceQuota = Double(max(1, baselineTasks(for: state).count * totalDays))
        }

        let activeRatio = Double(totalActiveDaysInMonth) / Double(totalDays)
        let totalMonthlyQuota = max(1, Int(round(fullMonthMaintenanceQuota * activeRatio)))

        // Numerator strictly isolates non-routine maintenance records
        let completionsThisMonth = state.historyRecords.filter { record in
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .month) &&
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .year) &&
            !isBaselineRecord(record, in: state)
        }.count

        // Dual-Threshold Window:
        // 1. Quota required through end of yesterday (closed days):
        let expectedPrior = Double(totalMonthlyQuota) * (Double(completedDays) / Double(totalActiveDaysInMonth))
        // 2. Quota required through end of today:
        let expectedToday = Double(totalMonthlyQuota) * (Double(activeDaysElapsed) / Double(totalActiveDaysInMonth))

        let targetPriorInt = Int(floor(expectedPrior))
        let targetTodayInt = Int(ceil(expectedToday))

        let deltaLead: Int
        let isOnPace: Bool
        let isLeading: Bool

        if completionsThisMonth >= targetTodayInt {
            let computedLead = completionsThisMonth - Int(round(expectedToday))
            if computedLead > 0 {
                deltaLead = computedLead
                isOnPace = false
                isLeading = true
            } else {
                // Reached today's ceiling target at the rounding boundary without positive excess
                deltaLead = 0
                isOnPace = true
                isLeading = true
            }
        } else if completionsThisMonth >= targetPriorInt {
            // Closed-day requirements met; currently active within today's operational window
            deltaLead = 0
            isOnPace = true
            isLeading = true
        } else {
            // Deficit behind closed days
            deltaLead = completionsThisMonth - Int(round(expectedPrior))
            isOnPace = false
            isLeading = false
        }

        let actualRatio = min(1.0, Double(completionsThisMonth) / Double(totalMonthlyQuota))
        let timeElapsedRatio = min(1.0, Double(activeDaysElapsed) / Double(totalActiveDaysInMonth))

        return MonthlyPacingSnapshot(
            monthTitle: monthTitle,
            currentDay: currentDay,
            totalDaysInMonth: totalDays,
            actualCompleted: completionsThisMonth,
            totalMonthlyQuota: totalMonthlyQuota,
            deltaLead: deltaLead,
            actualProgressRatio: actualRatio,
            expectedProgressRatio: timeElapsedRatio,
            isLeading: isLeading,
            isOnPace: isOnPace
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

        let currentDay = calendar.component(.day, from: now)

        let startDay: Int
        if let explicit = state.trackingStartDate,
           calendar.isDate(explicit, equalTo: now, toGranularity: .month),
           calendar.isDate(explicit, equalTo: now, toGranularity: .year) {
            startDay = min(currentDay, max(1, calendar.component(.day, from: explicit)))
        } else {
            let monthRecords = state.historyRecords.filter { record in
                calendar.isDate(record.completedAt, equalTo: now, toGranularity: .month) &&
                calendar.isDate(record.completedAt, equalTo: now, toGranularity: .year)
            }
            if let earliest = monthRecords.map(\.completedAt).min() {
                startDay = min(currentDay, max(1, calendar.component(.day, from: earliest)))
            } else {
                startDay = currentDay
            }
        }

        let activeDays = max(1, currentDay - startDay + 1)
        let completedDays = max(0, activeDays - 1)

        let monthBaselineRecords = state.historyRecords.filter { record in
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .month) &&
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .year) &&
            isBaselineRecord(record, in: state)
        }

        let completedToday = monthBaselineRecords.filter {
            calendar.isDate($0.completedAt, inSameDayAs: now)
        }.count

        let totalCompleted = monthBaselineRecords.count

        // Closed days require full baseline quota; in-progress today adds only what has been completed
        let expectedCount: Int
        if completedDays == 0 {
            expectedCount = bTotal
        } else {
            let closedExpected = bTotal * completedDays
            expectedCount = closedExpected + max(0, min(bTotal, completedToday))
        }

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
            activeDaysTracked: activeDays,
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
}