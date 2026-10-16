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
                        let intervalDays = recurrence.intervalDays
                        state.tasks[i].dueDate = calendar.date(byAdding: .day, value: intervalDays, to: completedAt) ?? state.tasks[i].dueDate
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
            if let recordIdx = state.historyRecords.firstIndex(where: { $0.taskId == task.id }) {
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
            guard let taskId = record.taskId, baselineTaskIds.contains(taskId) else { return false }
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

    /// Removes a task by ID.
    public static func deleteTask(state: inout DashboardState, id: UUID) {
        state.tasks.removeAll(where: { $0.id == id })
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
        case .halfway:
            return calendar.date(byAdding: .day, value: max(1, interval / 2), to: today) ?? today
        case .notYet:
            return calendar.date(byAdding: .day, value: max(1, Int(round(Double(interval) * 0.75))), to: today) ?? today
        case .good:
            return calendar.date(byAdding: .day, value: max(1, interval), to: today) ?? today
        }
    }
}