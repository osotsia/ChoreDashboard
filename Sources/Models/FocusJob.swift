import Foundation

public struct FocusJob: Identifiable, Codable, Equatable {
    public let id: UUID
    public var tag: String
    public var title: String
    public var isCompleted: Bool
    public var isOverdue: Bool

    public init(
        id: UUID = UUID(),
        tag: String,
        title: String,
        isCompleted: Bool = false,
        isOverdue: Bool = false
    ) {
        self.id = id
        self.tag = tag
        self.title = title
        self.isCompleted = isCompleted
        self.isOverdue = isOverdue
    }

    private enum CodingKeys: String, CodingKey {
        case id, tag, title, notes, isCompleted, isOverdue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? "OPERATION"
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        let explicitOverdue = try container.decodeIfPresent(Bool.self, forKey: .isOverdue) ?? false
        let legacyNotes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""

        // Preserve overdue status if loaded from legacy JSON containing [OVERDUE] in notes
        self.isOverdue = legacyNotes.contains("[OVERDUE]") ? true : explicitOverdue
        self.isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tag, forKey: .tag)
        try container.encode(title, forKey: .title)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(isOverdue, forKey: .isOverdue)
    }
}