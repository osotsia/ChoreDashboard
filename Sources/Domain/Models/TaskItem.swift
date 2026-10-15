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

    private enum CodingKeys: String, CodingKey {
        case count
        case unit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawCount = try container.decode(Int.self, forKey: .count)
        self.count = max(1, rawCount)
        self.unit = try container.decode(CadenceUnit.self, forKey: .unit)
    }
}

// MARK: - Unified Task Item
public struct TaskItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var tag: String
    public var durationMinutes: Int
    public var isCompleted: Bool
    public var dueDate: Date
    public var lastCompletedAt: Date?
    public var recurrence: RecurrenceRule?

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

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case tag
        case durationMinutes
        case isCompleted
        case dueDate
        case lastCompletedAt
        case recurrence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        let rawTag = try container.decode(String.self, forKey: .tag)
        self.tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let rawDuration = try container.decode(Int.self, forKey: .durationMinutes)
        self.durationMinutes = max(1, rawDuration)
        self.isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        self.dueDate = try container.decode(Date.self, forKey: .dueDate)
        self.lastCompletedAt = try container.decodeIfPresent(Date.self, forKey: .lastCompletedAt)
        self.recurrence = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrence)
    }

    public var isDailyBaseline: Bool {
        guard let recurrence = recurrence else { return false }
        return recurrence.unit == .day && recurrence.count == 1
    }

    public var isOneTime: Bool {
        recurrence == nil
    }

    public func healthState(relativeTo now: Date = Date(), calendar: Calendar = Calendar.current) -> TaskHealthState {
        if isCompleted {
            return .good
        }

        let startOfNow = calendar.startOfDay(for: now)
        let startOfDue = calendar.startOfDay(for: dueDate)

        if startOfDue < startOfNow {
            return .overdue
        } else if startOfDue == startOfNow {
            return .due
        } else {
            let daysUntilDue = calendar.dateComponents([.day], from: startOfNow, to: startOfDue).day ?? 0
            let intervalDays = recurrence?.intervalDays ?? 7
            let ratio = Double(daysUntilDue) / Double(max(1, intervalDays))

            if ratio >= 0.85 {
                return .good
            } else if ratio >= 0.60 {
                return .notYet
            } else if ratio >= 0.35 {
                return .halfway
            } else {
                return .due
            }
        }
    }

    public func healthState(using clock: Clock) -> TaskHealthState {
        healthState(relativeTo: clock.now, calendar: clock.calendar)
    }

    public func estimatedDaysRemaining(relativeTo now: Date = Date(), calendar: Calendar = Calendar.current) -> Int {
        let startOfNow = calendar.startOfDay(for: now)
        let startOfDue = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: startOfNow, to: startOfDue).day ?? 0
        return max(0, days)
    }

    public func timeAnchor(relativeTo now: Date = Date(), calendar: Calendar = Calendar.current) -> String {
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