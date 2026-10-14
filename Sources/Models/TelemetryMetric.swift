// --- File: Sources/Models/TelemetryMetric.swift ---
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

    private enum CodingKeys: String, CodingKey {
        case id, label, status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(status, forKey: .status)
    }
}