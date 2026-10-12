import Foundation

public struct ChoreItem: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var durationMinutes: Int
    public var tag: String
    public var isCompleted: Bool

    public init(id: UUID = UUID(), title: String, durationMinutes: Int, tag: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.durationMinutes = durationMinutes
        self.tag = tag
        self.isCompleted = isCompleted
    }
}