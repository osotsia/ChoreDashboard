// --- File: Sources/Models/HorizonEvent.swift ---
import Foundation

public struct HorizonEvent: Identifiable, Codable {
    public let id: UUID
    public var tag: String
    public var title: String
    public var notes: String
    public var timeAnchor: String
    public var repeatCount: Int
    public var repeatUnit: CadenceUnit
    public var healthState: TaskHealthState

    public init(
        id: UUID = UUID(),
        tag: String,
        title: String,
        notes: String = "",
        timeAnchor: String = "Upcoming",
        repeatCount: Int = 1,
        repeatUnit: CadenceUnit = .month,
        healthState: TaskHealthState = .good
    ) {
        self.id = id
        self.tag = tag
        self.title = title
        self.notes = notes
        self.timeAnchor = timeAnchor
        self.repeatCount = max(1, repeatCount)
        self.repeatUnit = repeatUnit
        self.healthState = healthState
    }

    private enum CodingKeys: String, CodingKey {
        case id, tag, title, notes, timeAnchor, repeatCount, repeatUnit, healthState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? "SCHEDULED"
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        let loadedAnchor = try container.decodeIfPresent(String.self, forKey: .timeAnchor) ?? "Upcoming"
        self.timeAnchor = loadedAnchor

        if let rc = try container.decodeIfPresent(Int.self, forKey: .repeatCount),
           let ru = try container.decodeIfPresent(CadenceUnit.self, forKey: .repeatUnit),
           let hs = try container.decodeIfPresent(TaskHealthState.self, forKey: .healthState) {
            self.repeatCount = max(1, rc)
            self.repeatUnit = ru
            self.healthState = hs
        } else {
            let (inferredCount, inferredUnit, inferredState) = Self.inferCadence(from: loadedAnchor)
            self.repeatCount = inferredCount
            self.repeatUnit = inferredUnit
            self.healthState = inferredState
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tag, forKey: .tag)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(timeAnchor, forKey: .timeAnchor)
        try container.encode(repeatCount, forKey: .repeatCount)
        try container.encode(repeatUnit, forKey: .repeatUnit)
        try container.encode(healthState, forKey: .healthState)
    }

    /// Derives a mathematically consistent cadence when reading legacy or hand-written JSON
    private static func inferCadence(from anchor: String) -> (Int, CadenceUnit, TaskHealthState) {
        let lower = anchor.lowercased()
        let numbers = anchor.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
        let parsedNumber = numbers.compactMap { Int($0) }.first

        if lower.contains("month") {
            let count = max(1, parsedNumber ?? 1)
            return (count, .month, .good)
        } else if lower.contains("week") {
            let count = max(1, parsedNumber ?? 2)
            return (count, .week, .good)
        } else if lower.contains("day") {
            let days = parsedNumber ?? 3
            if days >= 25 {
                let months = max(1, Int(round(Double(days) / 30.0)))
                return (months, .month, .good)
            } else if days >= 7 {
                let weeks = max(1, Int(round(Double(days) / 7.0)))
                return (weeks, .week, .good)
            } else {
                return (max(1, days), .day, days <= 1 ? .due : .notYet)
            }
        }
        return (1, .month, .good)
    }
}