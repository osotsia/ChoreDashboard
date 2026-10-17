import Foundation

public struct TaskRoutingInfo: Equatable, Sendable {
    public let icon: String
    public let text: String
    public let isImmediate: Bool

    public init(icon: String, text: String, isImmediate: Bool) {
        self.icon = icon
        self.text = text
        self.isImmediate = isImmediate
    }
}

/// Centralized ephemeral form model for creating and modifying tasks.
public struct TaskDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var isNew: Bool
    public var title: String
    public var tag: String
    public var durationMinutes: Int
    public var isOneTime: Bool
    public var repeatCount: Int
    public var repeatUnit: CadenceUnit
    public var targetDueDate: Date
    public var initialHealthState: TaskHealthState
    public var isCompleted: Bool
    public var lastCompletedAt: Date?
    public var createdAt: Date?

    public init(
        id: UUID = UUID(),
        isNew: Bool = true,
        title: String = "",
        tag: String = "",
        durationMinutes: Int = 15,
        isOneTime: Bool = false,
        repeatCount: Int = 1,
        repeatUnit: CadenceUnit = .week,
        targetDueDate: Date = Date(),
        initialHealthState: TaskHealthState = .due,
        isCompleted: Bool = false,
        lastCompletedAt: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.isNew = isNew
        self.title = title
        self.tag = tag
        self.durationMinutes = durationMinutes
        self.isOneTime = isOneTime
        self.repeatCount = repeatCount
        self.repeatUnit = repeatUnit
        self.targetDueDate = targetDueDate
        self.initialHealthState = initialHealthState
        self.isCompleted = isCompleted
        self.lastCompletedAt = lastCompletedAt
        self.createdAt = createdAt
    }

    /// Converts an existing TaskItem into an editable draft using the injected Clock.
    public static func from(task: TaskItem, clock: Clock = SystemClock()) -> TaskDraft {
        let calendar = clock.calendar
        let today = calendar.startOfDay(for: clock.now)
        let taskDue = calendar.startOfDay(for: task.dueDate)

        let isOneTime = task.isOneTime
        let repeatCount: Int
        let repeatUnit: CadenceUnit

        if isOneTime {
            let diffDays = calendar.dateComponents([.day], from: today, to: taskDue).day ?? 0
            if diffDays > 0 {
                if diffDays % 30 == 0 {
                    repeatCount = max(1, diffDays / 30)
                    repeatUnit = .month
                } else if diffDays % 7 == 0 {
                    repeatCount = max(1, diffDays / 7)
                    repeatUnit = .week
                } else {
                    repeatCount = max(1, diffDays)
                    repeatUnit = .day
                }
            } else {
                repeatCount = 1
                repeatUnit = .day
            }
        } else {
            repeatCount = task.recurrence?.count ?? 1
            repeatUnit = task.recurrence?.unit ?? .week
        }

        return TaskDraft(
            id: task.id,
            isNew: false,
            title: task.title,
            tag: task.tag,
            durationMinutes: task.durationMinutes,
            isOneTime: isOneTime,
            repeatCount: repeatCount,
            repeatUnit: repeatUnit,
            targetDueDate: task.dueDate,
            initialHealthState: task.healthState(using: clock),
            isCompleted: task.isCompleted,
            lastCompletedAt: task.lastCompletedAt,
            createdAt: task.createdAt
        )
    }

    // MARK: - Presentation Telemetry Projections
    public var isOneTimeInFuture: Bool {
        isOneTime && initialHealthState != .due && initialHealthState != .overdue
    }

    public var routingInfo: TaskRoutingInfo {
        if isOneTime {
            if initialHealthState == .overdue {
                return TaskRoutingInfo(icon: "exclamationmark.triangle.fill", text: "Overdue hazard: Assigned high priority on Active Focus.", isImmediate: true)
            } else if initialHealthState == .due {
                return TaskRoutingInfo(icon: "bolt.fill", text: "Immediate action: Placed on Today's Active Focus Queue.", isImmediate: true)
            } else {
                let intervalDays = repeatUnit.days(count: repeatCount)
                let timeStr = repeatUnit.displayString(count: repeatCount).lowercased()
                return TaskRoutingInfo(icon: "calendar", text: "Scheduled execution: Due in \(repeatCount) \(timeStr) (\(intervalDays)d) in Upcoming Horizon.", isImmediate: false)
            }
        }

        let intervalDays = repeatUnit.days(count: repeatCount)
        switch initialHealthState {
        case .overdue:
            return TaskRoutingInfo(icon: "exclamationmark.triangle.fill", text: "Overdue hazard: Assigned high priority on Active Focus.", isImmediate: true)
        case .due:
            if repeatUnit == .day && repeatCount == 1 {
                return TaskRoutingInfo(icon: "checklist", text: "Daily routine: Assigned to Daily Baseline (\(durationMinutes) min).", isImmediate: true)
            }
            return TaskRoutingInfo(icon: "bolt.fill", text: "Due today: Active on Today's Focus Queue.", isImmediate: true)
        case .halfway:
            let daysLeft = max(1, intervalDays / 2)
            return TaskRoutingInfo(icon: "clock", text: "Halfway runway: Estimated due in ~\(daysLeft) days (Upcoming Horizon).", isImmediate: false)
        case .notYet:
            let daysLeft = max(1, Int(round(Double(intervalDays) * 0.75)))
            return TaskRoutingInfo(icon: "clock", text: "In progress: Estimated due in ~\(daysLeft) days (Upcoming Horizon).", isImmediate: false)
        case .good:
            return TaskRoutingInfo(icon: "checkmark.circle", text: "Cycle fresh: Next due in \(intervalDays) days (Upcoming Horizon).", isImmediate: false)
        }
    }
}