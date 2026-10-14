// Sources/Models/FocusJob.swift
import Foundation

public struct FocusJob: Identifiable, Codable {
    public let id: UUID
    public var tag: String
    public var title: String
    public var notes: String
    public var isCompleted: Bool

    public init(
        id: UUID = UUID(),
        tag: String,
        title: String,
        notes: String = "",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.tag = tag
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
    }
}