// Sources/Models/HistoryRecord.swift
import Foundation

public struct HistoryRecord: Identifiable, Codable {
    public let id: UUID
    public var jobId: UUID?
    public var title: String
    public var tag: String
    public var completedAt: Date
    public var note: String

    public init(
        id: UUID = UUID(),
        jobId: UUID? = nil,
        title: String,
        tag: String,
        completedAt: Date,
        note: String = ""
    ) {
        self.id = id
        self.jobId = jobId
        self.title = title
        self.tag = tag
        self.completedAt = completedAt
        self.note = note
    }
}