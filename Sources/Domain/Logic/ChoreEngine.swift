import Foundation

/// Pure functional domain engine containing state transitions and boundary invariants.
public enum ChoreEngine {

    /// Evaluates midnight rollovers. Returns true if state was mutated.
    @discardableResult
    public static func rollover(state: inout DashboardState, clock: Clock) -> Bool {
        let calendar = clock.calendar
        let now = clock.now
        var didMutate = false
        var indicesToRemove: [Int] = []

        for i in state.tasks.indices {
            guard state.tasks[i].isCompleted, let completedAt = state.tasks[i].lastCompletedAt else { continue }

            if !calendar.isDate(completedAt, inSameDayAs: now) {
                if state.tasks[i].isOneTime {
                    // Purge completed one-time tasks once their completion date has passed
                    indicesToRemove.append(i)
                    didMutate = true
                } else if let recurrence = state.tasks[i].recurrence {
                    state.tasks[i].isCompleted = false
                    if !state.tasks[i].isDailyBaseline {
                        let isCustomFutureDue = calendar.startOfDay(for: state.tasks[i].dueDate) > calendar.startOfDay(for: completedAt)
                        if !isCustomFutureDue {
                            let intervalDays = recurrence.intervalDays
                            state.tasks[i].dueDate = calendar.date(byAdding: .day, value: intervalDays, to: completedAt) ?? state.tasks[i].dueDate
                        }
                    }
                    didMutate = true
                }
            }
        }

        for idx in indicesToRemove.reversed() {
            state.tasks.remove(at: idx)
        }

        return didMutate
    }

    /// Toggles a task on the active focus queue or baseline.
    public static func toggleTask(state: inout DashboardState, id: UUID, clock: Clock) {
        guard let idx = state.tasks.firstIndex(where: { $0.id == id }) else { return }
        state.tasks[idx].isCompleted.toggle()
        let task = state.tasks[idx]

        if task.isCompleted {
            state.tasks[idx].lastCompletedAt = clock.now
            let record = HistoryRecord(
                taskId: task.id,
                title: task.title,
                tag: task.tag,
                completedAt: clock.now,
                isDailyBaseline: task.isDailyBaseline
            )
            state.historyRecords.insert(record, at: 0)
        } else {
            if let recordIdx = state.historyRecords.firstIndex(where: {
                $0.taskId == task.id && clock.calendar.isDate($0.completedAt, inSameDayAs: clock.now)
            }) {
                state.historyRecords.remove(at: recordIdx)
            }
        }
    }

    /// Executes completion of an upcoming horizon task.
    public static func completeHorizonTask(state: inout DashboardState, id: UUID, clock: Clock) {
        guard let idx = state.tasks.firstIndex(where: { $0.id == id }) else { return }
        let task = state.tasks[idx]

        let record = HistoryRecord(
            taskId: task.id,
            title: task.title,
            tag: task.tag,
            completedAt: clock.now,
            isDailyBaseline: task.isDailyBaseline
        )
        state.historyRecords.insert(record, at: 0)

        if task.isOneTime {
            state.tasks.remove(at: idx)
        } else {
            let intervalDays = task.recurrence?.intervalDays ?? 7
            let nextDue = clock.calendar.date(byAdding: .day, value: intervalDays, to: clock.now) ?? clock.now
            state.tasks[idx].dueDate = nextDue
            state.tasks[idx].lastCompletedAt = clock.now
            state.tasks[idx].isCompleted = false
        }
    }

    /// Resets daily baseline chores and purges today's baseline records from history.
    public static func resetDailyBaseline(state: inout DashboardState, clock: Clock) {
        let calendar = clock.calendar
        let baselineTaskIds = Set(state.tasks.filter { $0.isDailyBaseline }.map { $0.id })

        for idx in state.tasks.indices where state.tasks[idx].isDailyBaseline {
            state.tasks[idx].isCompleted = false
            if let last = state.tasks[idx].lastCompletedAt, calendar.isDate(last, inSameDayAs: clock.now) {
                state.tasks[idx].lastCompletedAt = nil
            }
        }

        state.historyRecords.removeAll { record in
            let isBaseline = record.isDailyBaseline || (record.taskId.map { baselineTaskIds.contains($0) } ?? false)
            guard isBaseline else { return false }
            return calendar.isDate(record.completedAt, inSameDayAs: clock.now)
        }
    }

    /// Inserts or updates a task.
    public static func upsertTask(state: inout DashboardState, task: TaskItem) {
        addCustomTag(state: &state, tag: task.tag)
        if let idx = state.tasks.firstIndex(where: { $0.id == task.id }) {
            state.tasks[idx] = task
        } else {
            state.tasks.append(task)
        }
    }

    /// Removes a task by ID, stamping historical records to preserve daily baseline categorization.
    public static func deleteTask(state: inout DashboardState, id: UUID, clock: Clock? = nil) {
        if let task = state.tasks.first(where: { $0.id == id }), task.isDailyBaseline {
            for i in state.historyRecords.indices where state.historyRecords[i].taskId == id {
                state.historyRecords[i].isDailyBaseline = true
            }

            // Account for unfulfilled baseline obligations if deleted mid-tracking window
            let calendar = clock?.calendar ?? Calendar(identifier: .gregorian)
            let now = clock?.now ?? state.historyRecords.map(\.completedAt).max() ?? state.trackingStartDate ?? calendar.startOfDay(for: Date())
            let window = ActiveMonthWindow(
                now: now,
                trackingStartDate: state.trackingStartDate,
                fallbackStartDay: 1,
                calendar: calendar
            )
            let taskStartDay: Int
            if calendar.isDate(task.createdAt, equalTo: window.referenceDate, toGranularity: .month),
               calendar.isDate(task.createdAt, equalTo: window.referenceDate, toGranularity: .year) {
                let createdDay = calendar.component(.day, from: task.createdAt)
                taskStartDay = min(window.currentDay, max(window.startDay, createdDay))
            } else {
                taskStartDay = window.startDay
            }
            let closedDays = max(0, window.currentDay - taskStartDay)
            let completedCount = state.historyRecords.filter { record in
                record.taskId == id &&
                calendar.isDate(record.completedAt, equalTo: window.referenceDate, toGranularity: .month) &&
                calendar.isDate(record.completedAt, equalTo: window.referenceDate, toGranularity: .year)
            }.count

            let deficit = max(0, closedDays - completedCount)
            if deficit > 0 {
                state.baselineHistoricalDeficit = (state.baselineHistoricalDeficit ?? 0) + deficit
            }
        }
        state.tasks.removeAll(where: { $0.id == id })
    }

    /// Deletes an individual history record by ID, synchronizing active task state if necessary.
    public static func deleteHistoryRecord(state: inout DashboardState, id: UUID, clock: Clock) {
        guard let recordIdx = state.historyRecords.firstIndex(where: { $0.id == id }) else { return }
        let record = state.historyRecords.remove(at: recordIdx)

        if let taskId = record.taskId,
           let taskIdx = state.tasks.firstIndex(where: { $0.id == taskId }),
           clock.calendar.isDate(record.completedAt, inSameDayAs: clock.now) {
            state.tasks[taskIdx].isCompleted = false
            state.tasks[taskIdx].lastCompletedAt = nil
        }
    }

    /// Clears all tasks, history records, and custom tags, resetting the operational baseline.
    public static func clearAllData(state: inout DashboardState, clock: Clock) {
        state.tasks.removeAll()
        state.historyRecords.removeAll()
        state.customTags.removeAll()
        state.trackingStartDate = clock.now
    }

    /// Validates whether a tag string contains valid formatting and characters.
    public static func isValidTag(_ tag: String) -> Bool {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        return clean.rangeOfCharacter(from: CharacterSet(charactersIn: "·,")) == nil
    }

    /// Registers a new custom system tag.
    public static func addCustomTag(state: inout DashboardState, tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard isValidTag(clean) else { return }
        if !state.customTags.contains(clean) {
            state.customTags.append(clean)
        }
    }

    /// Deletes a tag and migrates all references to a fallback tag.
    public static func deleteTag(state: inout DashboardState, tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return }

        state.customTags.removeAll(where: { $0.uppercased() == clean })
        let fallbackTag = clean == "GENERAL" ? "OPERATIONS" : "GENERAL"
        if !state.customTags.contains(fallbackTag) {
            state.customTags.append(fallbackTag)
        }

        for i in state.tasks.indices where state.tasks[i].tag.uppercased() == clean {
            state.tasks[i].tag = fallbackTag
        }
        for i in state.historyRecords.indices where state.historyRecords[i].tag.uppercased() == clean {
            state.historyRecords[i].tag = fallbackTag
        }
    }

    /// Evaluates the estimated remaining days for a given health tier and cadence interval.
    public static func estimatedDaysRemaining(health: TaskHealthState, intervalDays: Int) -> Int {
        let interval = max(1, intervalDays)
        switch health {
        case .overdue: return -1
        case .due:     return 0
        case .halfway: return max(1, interval / 2)
        case .notYet:  return max(1, Int(round(Double(interval) * 0.75)))
        case .good:    return interval
        }
    }

    /// Calculates a target due date from a health runway state and recurrence specification.
    public static func calculateDueDate(
        health: TaskHealthState,
        recurrence: RecurrenceRule?,
        isOneTime: Bool,
        repeatCount: Int,
        repeatUnit: CadenceUnit,
        clock: Clock
    ) -> Date {
        let calendar = clock.calendar
        let today = clock.now

        if isOneTime {
            switch health {
            case .overdue:
                return calendar.date(byAdding: .day, value: -1, to: today) ?? today
            case .due:
                return today
            default:
                let intervalDays = repeatUnit.days(count: repeatCount)
                return calendar.date(byAdding: .day, value: max(1, intervalDays), to: today) ?? today
            }
        }

        let interval = recurrence?.intervalDays ?? 7
        switch health {
        case .overdue:
            return calendar.date(byAdding: .day, value: -1, to: today) ?? today
        case .due:
            return today
        case .halfway, .notYet, .good:
            let days = estimatedDaysRemaining(health: health, intervalDays: interval)
            return calendar.date(byAdding: .day, value: days, to: today) ?? today
        }
    }

    /// Calculates a target due date from fine-grained runway ratio and overdue status.
    public static func calculateDueDate(
        runwayRatio: Double,
        isOverdue: Bool,
        recurrence: RecurrenceRule?,
        isOneTime: Bool,
        repeatCount: Int,
        repeatUnit: CadenceUnit,
        clock: Clock
    ) -> Date {
        let calendar = clock.calendar
        let today = clock.now

        if isOverdue {
            return calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }

        let interval = isOneTime ? repeatUnit.days(count: repeatCount) : (recurrence?.intervalDays ?? 7)
        let clampedRatio = max(0.0, min(1.0, runwayRatio))
        let daysToAdd = Int(round(Double(interval) * clampedRatio))
        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }

    /// Evaluates the 5-tier health state from runway ratio and overdue status.
    public static func healthState(for runwayRatio: Double, isOverdue: Bool) -> TaskHealthState {
        if isOverdue { return .overdue }
        let clamped = max(0.0, min(1.0, runwayRatio))
        if clamped >= 0.85 {
            return .good
        } else if clamped >= 0.60 {
            return .notYet
        } else if clamped >= 0.35 {
            return .halfway
        } else {
            return .due
        }
    }

    /// Infers recurrence cadence components and runway telemetry for a task.
    public static func inferCadence(
        for task: TaskItem,
        clock: Clock
    ) -> (repeatCount: Int, repeatUnit: CadenceUnit, isOverdue: Bool, runwayRatio: Double) {
        let calendar = clock.calendar
        let today = calendar.startOfDay(for: clock.now)
        let taskDue = calendar.startOfDay(for: task.dueDate)
        let diffDays = calendar.dateComponents([.day], from: today, to: taskDue).day ?? 0

        let repeatCount: Int
        let repeatUnit: CadenceUnit

        if task.isOneTime {
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

        let intervalDays = max(1, task.isOneTime ? repeatUnit.days(count: repeatCount) : (task.recurrence?.intervalDays ?? 7))
        let isOverdue = !task.isCompleted && diffDays < 0
        let clampedRatio = task.isCompleted ? 1.0 : max(0.0, min(1.0, Double(diffDays) / Double(intervalDays)))

        return (repeatCount, repeatUnit, isOverdue, clampedRatio)
    }

    /// Resolves runway state (dueDate, healthState, clampedRatio) from a runway adjustment.
    public static func resolveRunway(
        ratio: Double,
        isOverdue: Bool,
        isOneTime: Bool,
        repeatCount: Int,
        repeatUnit: CadenceUnit,
        clock: Clock
    ) -> (dueDate: Date, health: TaskHealthState, ratio: Double) {
        let recurrence: RecurrenceRule? = isOneTime ? nil : RecurrenceRule(count: repeatCount, unit: repeatUnit)
        let effectiveRatio = isOverdue ? 0.0 : max(0.0, min(1.0, ratio))
        let dueDate = calculateDueDate(
            runwayRatio: effectiveRatio,
            isOverdue: isOverdue,
            recurrence: recurrence,
            isOneTime: isOneTime,
            repeatCount: repeatCount,
            repeatUnit: repeatUnit,
            clock: clock
        )
        let health = healthState(for: effectiveRatio, isOverdue: isOverdue)
        return (dueDate, health, effectiveRatio)
    }
}