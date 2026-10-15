import Foundation

/// Ground-truth application state persisted to disk.
public struct DashboardState: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    
    // Core operational data
    public var tasks: [TaskItem]
    public var historyRecords: [HistoryRecord]
    public var customTags: [String]
    
    // UI Metadata & Rules
    public var focusOverline: String
    public var focusTitle: String
    public var focusSubtitle: String
    public var heroTools: String
    public var baselineTitle: String
    public var baselineRule: String

    public init(
        schemaVersion: Int = 2,
        tasks: [TaskItem] = [],
        historyRecords: [HistoryRecord] = [],
        customTags: [String] = [],
        focusOverline: String = "SCHEDULED OPERATIONS",
        focusTitle: String = "Main Tasks",
        focusSubtitle: String = "Targeted deep maintenance · Non-routine upkeep",
        heroTools: String = "TOOLS: Microfiber cloths, food-safe sanitizer, brush kit.",
        baselineTitle: String = "Daily Baseline",
        baselineRule: String = "RULE: Complete before noon."
    ) {
        self.schemaVersion = schemaVersion
        self.tasks = tasks
        self.historyRecords = historyRecords
        self.customTags = customTags
        self.focusOverline = focusOverline
        self.focusTitle = focusTitle
        self.focusSubtitle = focusSubtitle
        self.heroTools = heroTools
        self.baselineTitle = baselineTitle
        self.baselineRule = baselineRule
    }
}