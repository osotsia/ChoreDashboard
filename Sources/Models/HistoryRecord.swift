import Foundation

public struct HistoryRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public var jobId: UUID?
    public var title: String
    public var tag: String
    public var completedAt: Date

    public init(
        id: UUID = UUID(),
        jobId: UUID? = nil,
        title: String,
        tag: String,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.jobId = jobId
        self.title = title
        self.tag = tag
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, jobId, title, tag, completedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.jobId = try container.decodeIfPresent(UUID.self, forKey: .jobId)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? "GENERAL"
        self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(jobId, forKey: .jobId)
        try container.encode(title, forKey: .title)
        try container.encode(tag, forKey: .tag)
        try container.encode(completedAt, forKey: .completedAt)
    }
}