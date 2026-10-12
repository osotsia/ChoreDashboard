import Foundation

public struct DashboardState: Codable {
    public var heroTitle: String
    public var heroSubtitle: String
    public var heroTools: String
    public var heroTasks: [ChoreItem]
    public var baselineTasks: [ChoreItem]
    public var upcomingEvents: [HorizonEvent]
    public var telemetryMetrics: [TelemetryMetric]
}