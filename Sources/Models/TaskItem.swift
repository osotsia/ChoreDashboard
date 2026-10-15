import Foundation

// MARK: - Cadence Units
public enum CadenceUnit: String, CaseIterable, Codable, Sendable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"

    public func days(count: Int) -> Int {
        switch self {
        case .day:   return count
        case .week:  return count * 7
        case .month: return count * 30
        case .year:  return count * 365
        }
    }

    public func displayString(count: Int) -> String {
        count == 1 ? rawValue : "\(rawValue)s"
    }

    public func next() -> CadenceUnit {
        let all = Self.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }

    public func previous() -> CadenceUnit {
        let all = Self.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx - 1 + all.count) % all.count]
    }
}

// MARK: - Recurrence Rule
public struct RecurrenceRule: Codable, Equatable, Sendable {
    public var count: Int
    public var unit: CadenceUnit

    public init(count: Int = 1, unit: CadenceUnit = .week) {
        self.count = max(1, count)
        self.unit = unit
    }

    public var intervalDays: Int {
        unit.days(count: count)
    }
}

// MARK: - Task Health State
public enum TaskHealthState: String, CaseIterable, Codable, Sendable {
    case good = "GOOD"
    case notYet = "NOT YET"
    case due = "DUE"
    case overdue = "OVERDUE"

    public var subtitle: String {
        switch self {
        case .good:    return "FRESH"
        case .notYet:  return "RUNNING"
        case .due:     return "TODAY"
        case .overdue: return "URGENT"
        }
    }
}

// MARK: - Unified Task Item
/// Unified ground-truth model representing any chore, focus job, or scheduled horizon item.
public struct TaskItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var tag: String
    public var durationMinutes: Int
    public var isCompleted: Bool
    public var dueDate: Date
    public var lastCompletedAt: Date?
    public var recurrence: RecurrenceRule? // nil indicates a one-time execution

    public init(
        id: UUID = UUID(),
        title: String,
        tag: String,
        durationMinutes: Int = 15,
        isCompleted: Bool = false,
        dueDate: Date = Date(),
        lastCompletedAt: Date? = nil,
        recurrence: RecurrenceRule? = RecurrenceRule(count: 1, unit: .week)
    ) {
        self.id = id
        self.title = title
        self.tag = tag.uppercased()
        self.durationMinutes = max(1, durationMinutes)
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.lastCompletedAt = lastCompletedAt
        self.recurrence = recurrence
    }

    // MARK: - Derived Classifications
    
    /// Daily baseline chores are recurring every 24 hours.
    public var isDailyBaseline: Bool {
        guard let recurrence = recurrence else { return false }
        return recurrence.unit == .day && recurrence.count == 1
    }

    public var isOneTime: Bool {
        recurrence == nil
    }

    /// Dynamic evaluation of health state relative to a given point in time.
    public func healthState(relativeTo now: Date = Date()) -> TaskHealthState {
        if isCompleted {
            return .good
        }

        let calendar = Calendar.current
        let startOfNow = calendar.startOfDay(for: now)
        let startOfDue = calendar.startOfDay(for: dueDate)

        if startOfDue < startOfNow {
            return .overdue
        } else if startOfDue == startOfNow {
            return .due
        } else {
            let daysUntilDue = calendar.dateComponents([.day], from: startOfNow, to: startOfDue).day ?? 0
            let intervalDays = recurrence?.intervalDays ?? 7
            return daysUntilDue <= max(1, intervalDays / 2) ? .notYet : .good
        }
    }

    /// Number of calendar days remaining until task is due.
    public func estimatedDaysRemaining(relativeTo now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let startOfNow = calendar.startOfDay(for: now)
        let startOfDue = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: startOfNow, to: startOfDue).day ?? 0
        return max(0, days)
    }

    /// Human-readable time anchor string dynamically derived from due date.
    public func timeAnchor(relativeTo now: Date = Date()) -> String {
        let calendar = Calendar.current
        let startOfNow = calendar.startOfDay(for: now)
        let startOfDue = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: startOfNow, to: startOfDue).day ?? 0

        if days < 0 {
            return "Overdue (\(abs(days))d)"
        } else if days == 0 {
            return "Today"
        } else if days == 1 {
            return "In 1 Day"
        } else if days < 14 {
            return "In \(days) Days"
        } else if days < 60 {
            let weeks = max(1, days / 7)
            return "In \(weeks) Weeks (\(days)d)"
        } else {
            let months = max(1, days / 30)
            return "In \(months) Months (\(days)d)"
        }
    }
}