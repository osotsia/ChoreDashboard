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
    public var isOverdue: Bool
    public var runwayRatio: Double

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
        createdAt: Date? = nil,
        isOverdue: Bool = false,
        runwayRatio: Double = 0.0
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
        self.isOverdue = isOverdue
        self.runwayRatio = runwayRatio
    }

    /// Converts an existing TaskItem into an editable draft using the injected Clock.
    public static func from(task: TaskItem, clock: Clock = SystemClock()) -> TaskDraft {
        let (repeatCount, repeatUnit, isOverdue, runwayRatio) = ChoreEngine.inferCadence(for: task, clock: clock)

        return TaskDraft(
            id: task.id,
            isNew: false,
            title: task.title,
            tag: task.tag,
            durationMinutes: task.durationMinutes,
            isOneTime: task.isOneTime,
            repeatCount: repeatCount,
            repeatUnit: repeatUnit,
            targetDueDate: task.dueDate,
            initialHealthState: task.healthState(using: clock),
            isCompleted: task.isCompleted,
            lastCompletedAt: task.lastCompletedAt,
            createdAt: task.createdAt,
            isOverdue: isOverdue,
            runwayRatio: runwayRatio
        )
    }

    // MARK: - Fine-Grained Runway Mutators

    /// Updates the fine-grained runway ratio and synchronizes targetDueDate and initialHealthState.
    public mutating func setRunway(ratio: Double, clock: Clock) {
        self.isOverdue = false
        let resolved = ChoreEngine.resolveRunway(
            ratio: ratio,
            isOverdue: false,
            isOneTime: isOneTime,
            repeatCount: repeatCount,
            repeatUnit: repeatUnit,
            clock: clock
        )
        self.runwayRatio = resolved.ratio
        self.targetDueDate = resolved.dueDate
        self.initialHealthState = resolved.health
    }

    /// Toggles or sets the overdue decay hazard state.
    public mutating func setOverdue(_ overdue: Bool, clock: Clock) {
        self.isOverdue = overdue
        let resolved = ChoreEngine.resolveRunway(
            ratio: overdue ? 0.0 : runwayRatio,
            isOverdue: overdue,
            isOneTime: isOneTime,
            repeatCount: repeatCount,
            repeatUnit: repeatUnit,
            clock: clock
        )
        self.runwayRatio = resolved.ratio
        self.targetDueDate = resolved.dueDate
        self.initialHealthState = resolved.health
    }

    // MARK: - Presentation Telemetry Projections
    public var intervalDays: Int {
        max(1, repeatUnit.days(count: repeatCount))
    }

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
                let timeStr = repeatUnit.displayString(count: repeatCount).lowercased()
                return TaskRoutingInfo(icon: "calendar", text: "Scheduled execution: Due in \(repeatCount) \(timeStr) (\(intervalDays)d) in Upcoming Horizon.", isImmediate: false)
            }
        }

        switch initialHealthState {
        case .overdue:
            return TaskRoutingInfo(icon: "exclamationmark.triangle.fill", text: "Overdue hazard: Assigned high priority on Active Focus.", isImmediate: true)
        case .due:
            if repeatUnit == .day && repeatCount == 1 {
                return TaskRoutingInfo(icon: "checklist", text: "Daily routine: Assigned to Daily Baseline (\(durationMinutes) min).", isImmediate: true)
            }
            return TaskRoutingInfo(icon: "bolt.fill", text: "Due today: Active on Today's Focus Queue.", isImmediate: true)
        case .halfway:
            let daysLeft = ChoreEngine.estimatedDaysRemaining(health: .halfway, intervalDays: intervalDays)
            return TaskRoutingInfo(icon: "clock", text: "Halfway runway: Estimated due in ~\(daysLeft) days (Upcoming Horizon).", isImmediate: false)
        case .notYet:
            let daysLeft = ChoreEngine.estimatedDaysRemaining(health: .notYet, intervalDays: intervalDays)
            return TaskRoutingInfo(icon: "clock", text: "In progress: Estimated due in ~\(daysLeft) days (Upcoming Horizon).", isImmediate: false)
        case .good:
            let daysLeft = ChoreEngine.estimatedDaysRemaining(health: .good, intervalDays: intervalDays)
            return TaskRoutingInfo(icon: "checkmark.circle", text: "Cycle fresh: Next due in \(daysLeft) days (Upcoming Horizon).", isImmediate: false)
        }
    }

    // MARK: - Task Model Materialization

    /// Materializes the draft into a persistent TaskItem, resolving due dates and timestamps via domain rules.
    public func toTaskItem(existing: TaskItem?, clock: Clock) -> TaskItem? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanTitle.isEmpty, !cleanTag.isEmpty else { return nil }

        let recurrence: RecurrenceRule? = isOneTime
            ? nil
            : RecurrenceRule(count: repeatCount, unit: repeatUnit)

        let resolvedDueDate: Date
        if !isNew,
           let existing = existing,
           existing.dueDate == targetDueDate && existing.recurrence == recurrence && existing.healthState(using: clock) == initialHealthState {
            resolvedDueDate = existing.dueDate
        } else if !isNew,
                  let existing = existing,
                  existing.healthState(using: clock) != initialHealthState && targetDueDate == existing.dueDate {
            resolvedDueDate = ChoreEngine.calculateDueDate(
                health: initialHealthState,
                recurrence: recurrence,
                isOneTime: isOneTime,
                repeatCount: repeatCount,
                repeatUnit: repeatUnit,
                clock: clock
            )
        } else {
            resolvedDueDate = targetDueDate
        }

        let resolvedCreatedAt: Date
        if isNew {
            resolvedCreatedAt = clock.now
        } else if let existing = existing {
            resolvedCreatedAt = existing.createdAt
        } else {
            resolvedCreatedAt = createdAt ?? clock.now
        }

        return TaskItem(
            id: id,
            title: cleanTitle,
            tag: cleanTag,
            durationMinutes: durationMinutes,
            isCompleted: isCompleted,
            dueDate: resolvedDueDate,
            lastCompletedAt: lastCompletedAt,
            recurrence: recurrence,
            createdAt: resolvedCreatedAt
        )
    }
}