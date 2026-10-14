// --- File: Sources/Models/HorizonEvent.swift ---
import Foundation

public struct HorizonEvent: Identifiable, Codable {
    public let id: UUID
    public var tag: String
    public var title: String
    public var notes: String
    public var timeAnchor: String

    public init(id: UUID = UUID(), tag: String, title: String, notes: String = "", timeAnchor: String = "Upcoming") {
        self.id = id
        self.tag = tag
        self.title = title
        self.notes = notes
        self.timeAnchor = timeAnchor
    }

    private enum CodingKeys: String, CodingKey {
        case id, tag, title, notes, timeAnchor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? "SCHEDULED"
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.timeAnchor = try container.decodeIfPresent(String.self, forKey: .timeAnchor) ?? "Upcoming"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tag, forKey: .tag)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(timeAnchor, forKey: .timeAnchor)
    }
}