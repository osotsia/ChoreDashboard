import Foundation

/// Immutable historical record representing an executed chore completion.
public struct HistoryRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var taskId: UUID?
    public var title: String
    public var tag: String
    public var completedAt: Date
    public var isDailyBaseline: Bool

    public init(
        id: UUID = UUID(),
        taskId: UUID? = nil,
        title: String,
        tag: String,
        completedAt: Date = Date(),
        isDailyBaseline: Bool = false
    ) {
        self.id = id
        self.taskId = taskId
        self.title = title
        self.tag = tag.uppercased()
        self.completedAt = completedAt
        self.isDailyBaseline = isDailyBaseline
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case taskId
        case title
        case tag
        case completedAt
        case isDailyBaseline
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.taskId = try container.decodeIfPresent(UUID.self, forKey: .taskId)
        self.title = try container.decode(String.self, forKey: .title)
        let rawTag = try container.decode(String.self, forKey: .tag)
        self.tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.completedAt = try container.decode(Date.self, forKey: .completedAt)
        self.isDailyBaseline = try container.decodeIfPresent(Bool.self, forKey: .isDailyBaseline) ?? false
    }
}