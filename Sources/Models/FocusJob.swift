import Foundation

public struct FocusJob: Identifiable, Codable {
    public let id: UUID
    public var tag: String
    public var title: String
    public var notes: String

    public init(
        id: UUID = UUID(),
        tag: String,
        title: String,
        notes: String = ""
    ) {
        self.id = id
        self.tag = tag
        self.title = title
        self.notes = notes
    }
}