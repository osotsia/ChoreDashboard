import Foundation

/// Ground-truth application state persisted to disk.
public struct DashboardState: Codable, Sendable {
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

    // MARK: - Legacy Migration Decoder
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case tasks
        case historyRecords
        case customTags
        case focusOverline, zoneLabel
        case focusTitle, heroTitle
        case focusSubtitle, heroSubtitle
        case heroTools
        case baselineTitle, baselineRule
        
        // V1 Schema Migration Keys
        case focusJobs
        case baselineTasks
        case upcomingEvents
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        
        // Decode header copy
        self.focusOverline = try container.decodeIfPresent(String.self, forKey: .focusOverline)
            ?? (try container.decodeIfPresent(String.self, forKey: .zoneLabel))
            ?? "SCHEDULED OPERATIONS"
        self.focusTitle = try container.decodeIfPresent(String.self, forKey: .focusTitle)
            ?? (try container.decodeIfPresent(String.self, forKey: .heroTitle))
            ?? "Main Tasks"
        self.focusSubtitle = try container.decodeIfPresent(String.self, forKey: .focusSubtitle)
            ?? (try container.decodeIfPresent(String.self, forKey: .heroSubtitle))
            ?? "Targeted deep maintenance · Non-routine upkeep"
        self.heroTools = try container.decodeIfPresent(String.self, forKey: .heroTools)
            ?? "TOOLS: Microfiber cloths, food-safe sanitizer, brush kit."
        self.baselineTitle = try container.decodeIfPresent(String.self, forKey: .baselineTitle) ?? "Daily Baseline"
        self.baselineRule = try container.decodeIfPresent(String.self, forKey: .baselineRule) ?? "RULE: Complete before noon."
        
        self.historyRecords = try container.decodeIfPresent([HistoryRecord].self, forKey: .historyRecords) ?? []
        self.customTags = try container.decodeIfPresent([String].self, forKey: .customTags) ?? []

        // If Schema Version 2, decode unified tasks directly
        if let decodedTasks = try container.decodeIfPresent([TaskItem].self, forKey: .tasks) {
            self.tasks = decodedTasks
        } else {
            // Auto-migrate from V1 Schema
            var migratedTasks: [TaskItem] = []
            let calendar = Calendar.current
            let today = Date()

            // 1. Migrate Legacy Baseline Tasks
            if let legacyBaseline = try container.decodeIfPresent([LegacyChoreItem].self, forKey: .baselineTasks) {
                for item in legacyBaseline {
                    migratedTasks.append(
                        TaskItem(
                            id: item.id,
                            title: item.title,
                            tag: item.tag,
                            durationMinutes: item.durationMinutes,
                            isCompleted: item.isCompleted,
                            dueDate: today,
                            lastCompletedAt: item.isCompleted ? today : nil,
                            recurrence: RecurrenceRule(count: 1, unit: .day)
                        )
                    )
                }
            }

            // 2. Migrate Legacy Focus Jobs
            if let legacyFocus = try container.decodeIfPresent([LegacyFocusJob].self, forKey: .focusJobs) {
                for job in legacyFocus {
                    let jobDueDate = job.isOverdue ? calendar.date(byAdding: .day, value: -1, to: today) ?? today : today
                    migratedTasks.append(
                        TaskItem(
                            id: job.id,
                            title: job.title,
                            tag: job.tag,
                            durationMinutes: 15,
                            isCompleted: job.isCompleted,
                            dueDate: jobDueDate,
                            lastCompletedAt: job.isCompleted ? today : nil,
                            recurrence: RecurrenceRule(count: 1, unit: .week)
                        )
                    )
                }
            }

            // 3. Migrate Legacy Upcoming Events
            if let legacyUpcoming = try container.decodeIfPresent([LegacyHorizonEvent].self, forKey: .upcomingEvents) {
                for event in legacyUpcoming {
                    let intervalDays = event.repeatUnit.days(count: event.repeatCount)
                    let offsetDays = (event.healthState == .good) ? max(1, intervalDays) : max(1, intervalDays / 2)
                    let eventDueDate = calendar.date(byAdding: .day, value: offsetDays, to: today) ?? today

                    migratedTasks.append(
                        TaskItem(
                            id: event.id,
                            title: event.title,
                            tag: event.tag,
                            durationMinutes: 15,
                            isCompleted: false,
                            dueDate: eventDueDate,
                            lastCompletedAt: nil,
                            recurrence: RecurrenceRule(count: event.repeatCount, unit: event.repeatUnit)
                        )
                    )
                }
            }

            self.tasks = migratedTasks
            self.schemaVersion = 2
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(tasks, forKey: .tasks)
        try container.encode(historyRecords, forKey: .historyRecords)
        try container.encode(customTags, forKey: .customTags)
        try container.encode(focusOverline, forKey: .focusOverline)
        try container.encode(focusTitle, forKey: .focusTitle)
        try container.encode(focusSubtitle, forKey: .focusSubtitle)
        try container.encode(heroTools, forKey: .heroTools)
        try container.encode(baselineTitle, forKey: .baselineTitle)
        try container.encode(baselineRule, forKey: .baselineRule)
    }
}

// MARK: - Private V1 Deserialization Structs
private struct LegacyChoreItem: Codable {
    let id: UUID
    let title: String
    let durationMinutes: Int
    let tag: String
    let isCompleted: Bool
}

private struct LegacyFocusJob: Codable {
    let id: UUID
    let tag: String
    let title: String
    let isCompleted: Bool
    let isOverdue: Bool
}

private struct LegacyHorizonEvent: Codable {
    let id: UUID
    let tag: String
    let title: String
    let repeatCount: Int
    let repeatUnit: CadenceUnit
    let healthState: TaskHealthState
}