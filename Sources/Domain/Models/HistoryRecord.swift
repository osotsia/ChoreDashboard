import Foundation

/// Immutable historical record representing an executed chore completion.
public struct HistoryRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var taskId: UUID?
    public var title: String
    public var tag: String
    public var completedAt: Date

    public init(
        id: UUID = UUID(),
        taskId: UUID? = nil,
        title: String,
        tag: String,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.title = title
        self.tag = tag.uppercased()
        self.completedAt = completedAt
    }
}