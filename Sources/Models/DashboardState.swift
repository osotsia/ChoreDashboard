import Foundation

public struct DashboardState: Codable {
    public var focusOverline: String
    public var focusTitle: String
    public var focusSubtitle: String
    public var heroTools: String
    public var focusJobs: [FocusJob]
    public var baselineTitle: String
    public var baselineSubtitle: String
    public var baselineRule: String
    public var baselineTasks: [ChoreItem]
    public var upcomingEvents: [HorizonEvent]
    public var telemetryMetrics: [TelemetryMetric]

    public init(
        focusOverline: String = "SCHEDULED OPERATIONS",
        focusTitle: String = "Main Tasks",
        focusSubtitle: String = "Targeted deep maintenance · Non-routine upkeep",
        heroTools: String = "TOOLS: Microfiber cloths, food-safe sanitizer, brush kit.",
        focusJobs: [FocusJob],
        baselineTitle: String = "Daily Baseline",
        baselineSubtitle: String = "Est: 25 min · Daily maintenance",
        baselineRule: String = "RULE: Complete before noon.",
        baselineTasks: [ChoreItem],
        upcomingEvents: [HorizonEvent],
        telemetryMetrics: [TelemetryMetric] = []
    ) {
        self.focusOverline = focusOverline
        self.focusTitle = focusTitle
        self.focusSubtitle = focusSubtitle
        self.heroTools = heroTools
        self.focusJobs = focusJobs
        self.baselineTitle = baselineTitle
        self.baselineSubtitle = baselineSubtitle
        self.baselineRule = baselineRule
        self.baselineTasks = baselineTasks
        self.upcomingEvents = upcomingEvents
        self.telemetryMetrics = telemetryMetrics
    }

    private enum CodingKeys: String, CodingKey {
        case focusOverline, zoneLabel
        case focusTitle, heroTitle
        case focusSubtitle, heroSubtitle
        case heroTools
        case focusJobs, heroTasks
        case baselineTitle, baselineSubtitle, baselineRule
        case baselineTasks
        case upcomingEvents, telemetryMetrics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Generalize overline
        if let decodedOverline = try container.decodeIfPresent(String.self, forKey: .focusOverline) {
            self.focusOverline = (decodedOverline.contains("KITCHEN") || decodedOverline.contains("ZONE")) ? "SCHEDULED OPERATIONS" : decodedOverline
        } else {
            self.focusOverline = "SCHEDULED OPERATIONS"
        }

        // Generalize primary title to "Main Tasks"
        if let decodedTitle = try container.decodeIfPresent(String.self, forKey: .focusTitle), !decodedTitle.isEmpty {
            let lower = decodedTitle.lowercased()
            if lower.contains("kitchen") || lower.contains("bathroom") || lower.contains("targeted") {
                self.focusTitle = "Main Tasks"
            } else {
                self.focusTitle = decodedTitle
            }
        } else {
            self.focusTitle = "Main Tasks"
        }

        // Generalize subtitle
        if let decodedSub = try container.decodeIfPresent(String.self, forKey: .focusSubtitle), !decodedSub.isEmpty {
            let lower = decodedSub.lowercased()
            if lower.contains("bottle") || lower.contains("descaling") {
                self.focusSubtitle = "Targeted deep maintenance · Non-routine upkeep"
            } else {
                self.focusSubtitle = decodedSub
            }
        } else {
            self.focusSubtitle = "Targeted deep maintenance · Non-routine upkeep"
        }

        self.heroTools = try container.decodeIfPresent(String.self, forKey: .heroTools) ?? "TOOLS: Microfiber cloths, food-safe sanitizer, brush kit."

        if let rawJobs = try container.decodeIfPresent([FocusJob].self, forKey: .focusJobs), !rawJobs.isEmpty {
            self.focusJobs = rawJobs
        } else if let legacyHeroTasks = try container.decodeIfPresent([ChoreItem].self, forKey: .heroTasks) {
            self.focusJobs = legacyHeroTasks.map {
                FocusJob(
                    id: $0.id,
                    tag: "TASK",
                    title: $0.title,
                    notes: ""
                )
            }
        } else {
            self.focusJobs = []
        }

        self.baselineTitle = try container.decodeIfPresent(String.self, forKey: .baselineTitle) ?? "Daily Baseline"
        self.baselineSubtitle = try container.decodeIfPresent(String.self, forKey: .baselineSubtitle) ?? "Est: 25 min · Daily maintenance"
        self.baselineRule = try container.decodeIfPresent(String.self, forKey: .baselineRule) ?? "RULE: Complete before noon."
        self.baselineTasks = try container.decode([ChoreItem].self, forKey: .baselineTasks)
        self.upcomingEvents = try container.decode([HorizonEvent].self, forKey: .upcomingEvents)
        self.telemetryMetrics = try container.decodeIfPresent([TelemetryMetric].self, forKey: .telemetryMetrics) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(focusOverline, forKey: .focusOverline)
        try container.encode(focusTitle, forKey: .focusTitle)
        try container.encode(focusSubtitle, forKey: .focusSubtitle)
        try container.encode(heroTools, forKey: .heroTools)
        try container.encode(focusJobs, forKey: .focusJobs)
        try container.encode(baselineTitle, forKey: .baselineTitle)
        try container.encode(baselineSubtitle, forKey: .baselineSubtitle)
        try container.encode(baselineRule, forKey: .baselineRule)
        try container.encode(baselineTasks, forKey: .baselineTasks)
        try container.encode(upcomingEvents, forKey: .upcomingEvents)
        try container.encode(telemetryMetrics, forKey: .telemetryMetrics)
    }
}