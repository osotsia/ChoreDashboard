import Foundation

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
        lastCompletedAt: Date? = nil
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
            lastCompletedAt: task.lastCompletedAt
        )
    }
}