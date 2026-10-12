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
        focusTitle: String = "Targeted Deep Maintenance",
        focusSubtitle: String = "Non-routine interventions · Mechanical upkeep & hygiene restoration",
        heroTools: String,
        focusJobs: [FocusJob],
        baselineTitle: String = "Zero-State Daily Reset",
        baselineSubtitle: String = "Est: 15 min · Maintain apartment entropy floor",
        baselineRule: String = "RULE: Zero soiled dishes or wet trash past 22:00.",
        baselineTasks: [ChoreItem],
        upcomingEvents: [HorizonEvent],
        telemetryMetrics: [TelemetryMetric]
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

        // Overline resolution
        if let decodedOverline = try container.decodeIfPresent(String.self, forKey: .focusOverline) {
            self.focusOverline = decodedOverline
        } else if let legacyZone = try container.decodeIfPresent(String.self, forKey: .zoneLabel) {
            self.focusOverline = (legacyZone.hasPrefix("ZONE") || legacyZone == "MAIN TASKS") ? "SCHEDULED OPERATIONS" : legacyZone
        } else {
            self.focusOverline = "SCHEDULED OPERATIONS"
        }

        // Primary Title resolution
        if let decodedTitle = try container.decodeIfPresent(String.self, forKey: .focusTitle), !decodedTitle.isEmpty {
            self.focusTitle = decodedTitle
        } else if let legacyHeroTitle = try container.decodeIfPresent(String.self, forKey: .heroTitle), !legacyHeroTitle.isEmpty {
            self.focusTitle = legacyHeroTitle
        } else {
            self.focusTitle = "Targeted Deep Maintenance"
        }

        // Subtitle resolution
        if let decodedSub = try container.decodeIfPresent(String.self, forKey: .focusSubtitle), !decodedSub.isEmpty {
            self.focusSubtitle = decodedSub
        } else if let legacyHeroSub = try container.decodeIfPresent(String.self, forKey: .heroSubtitle), !legacyHeroSub.isEmpty {
            self.focusSubtitle = legacyHeroSub
        } else {
            self.focusSubtitle = "Non-routine interventions · Mechanical upkeep & hygiene restoration"
        }

        self.heroTools = try container.decode(String.self, forKey: .heroTools)

        if let rawJobs = try container.decodeIfPresent([FocusJob].self, forKey: .focusJobs), !rawJobs.isEmpty {
            self.focusJobs = rawJobs.map { job in
                var cleaned = job
                if cleaned.tag == "TASK" || cleaned.tag.hasSuffix("m") {
                    cleaned.tag = Self.inferOperationalTag(for: cleaned.title)
                }
                if cleaned.notes.lowercased().hasPrefix("target:") || cleaned.notes.contains("10m") {
                    cleaned.notes = ""
                }
                return cleaned
            }
        } else if let legacyHeroTasks = try container.decodeIfPresent([ChoreItem].self, forKey: .heroTasks) {
            self.focusJobs = legacyHeroTasks.map {
                FocusJob(
                    id: $0.id,
                    tag: Self.inferOperationalTag(for: $0.title),
                    title: $0.title,
                    notes: ""
                )
            }
        } else {
            self.focusJobs = []
        }

        self.baselineTitle = try container.decodeIfPresent(String.self, forKey: .baselineTitle) ?? "Zero-State Daily Reset"
        self.baselineSubtitle = try container.decodeIfPresent(String.self, forKey: .baselineSubtitle) ?? "Est: 15 min · Maintain apartment entropy floor"
        self.baselineRule = try container.decodeIfPresent(String.self, forKey: .baselineRule) ?? "RULE: Zero soiled dishes or wet trash past 22:00."
        self.baselineTasks = try container.decode([ChoreItem].self, forKey: .baselineTasks)
        self.upcomingEvents = try container.decode([HorizonEvent].self, forKey: .upcomingEvents)
        self.telemetryMetrics = try container.decode([TelemetryMetric].self, forKey: .telemetryMetrics)
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

    private static func inferOperationalTag(for title: String) -> String {
        let text = title.lowercased()
        if text.contains("shower") || text.contains("descale") { return "PLUMBING · FIXTURES" }
        if text.contains("toilet") || text.contains("bowl") { return "SANITATION · PORCELAIN" }
        if text.contains("drain") || text.contains("trap") { return "DRAINAGE · ENZYMES" }
        if text.contains("mop") || text.contains("floor") { return "SURFACES · MECHANICAL" }
        if text.contains("fan") || text.contains("blower") { return "VENTILATION · AIRWAY" }
        if text.contains("filter") || text.contains("hood") { return "MECHANICAL · FILTRATION" }
        return "MAIN OPERATIONS"
    }
}