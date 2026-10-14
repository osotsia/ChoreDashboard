// --- File: Sources/Models/ChoreItem.swift ---
import Foundation

public struct ChoreItem: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var durationMinutes: Int
    public var tag: String
    public var isCompleted: Bool

    public init(id: UUID = UUID(), title: String, durationMinutes: Int = 15, tag: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.durationMinutes = max(1, durationMinutes)
        self.tag = tag
        self.isCompleted = isCompleted
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, durationMinutes, tag, isCompleted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.durationMinutes = max(1, try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 15)
        self.tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? "GENERAL"
        self.isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(tag, forKey: .tag)
        try container.encode(isCompleted, forKey: .isCompleted)
    }
}