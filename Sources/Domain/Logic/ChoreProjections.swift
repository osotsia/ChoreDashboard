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
        let timeElapsedRatio = min(1.0, Double(currentDay) / Double(totalDays))

        var maintenanceQuota: Double = 0
        for task in state.tasks where !task.isDailyBaseline {
            if let recurrence = task.recurrence {
                let intervalDays = max(1, recurrence.intervalDays)
                let runsPerMonth = Double(totalDays) / Double(intervalDays)
                maintenanceQuota += runsPerMonth
            } else {
                maintenanceQuota += 1
            }
        }

        if maintenanceQuota == 0 {
            maintenanceQuota = Double(max(1, baselineTasks(for: state).count * totalDays))
        }

        let totalMonthlyQuota = max(1, Int(round(maintenanceQuota)))

        let completionsThisMonth = state.historyRecords.filter { record in
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .month) &&
            calendar.isDate(record.completedAt, equalTo: now, toGranularity: .year)
        }.count

        let expected = Double(totalMonthlyQuota) * timeElapsedRatio
        let delta = completionsThisMonth - Int(round(expected))
        let actualRatio = min(1.0, Double(completionsThisMonth) / Double(totalMonthlyQuota))

        return MonthlyPacingSnapshot(
            monthTitle: monthTitle,
            currentDay: currentDay,
            totalDaysInMonth: totalDays,
            actualCompleted: completionsThisMonth,
            totalMonthlyQuota: totalMonthlyQuota,
            deltaLead: delta,
            actualProgressRatio: actualRatio,
            expectedProgressRatio: timeElapsedRatio,
            isLeading: delta >= 0
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