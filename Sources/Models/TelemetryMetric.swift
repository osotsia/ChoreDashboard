import Foundation

public struct TelemetryMetric: Identifiable, Codable {
    public let id: UUID
    public var label: String
    public var status: String

    public init(id: UUID = UUID(), label: String, status: String) {
        self.id = id
        self.label = label
        self.status = status
    }
}