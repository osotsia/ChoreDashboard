import Foundation

public enum PreviewData {
    private static func relativeDate(daysAgo: Int, hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) - daysAgo
        comps.hour = hour
        comps.minute = minute
        return cal.date(from: comps) ?? Date()
    }

    public static let defaultState: DashboardState = {
        let kitchenId   = UUID()
        let floorsId    = UUID()
        let fridgeId    = UUID()
        let bottlesId   = UUID()
        let brewingId   = UUID()
        let sinkId      = UUID()
        let stretchId   = UUID()
        let meditateId  = UUID()
        let dishesId    = UUID()

        return DashboardState(
            focusOverline: "SCHEDULED OPERATIONS",
            focusTitle: "Main Tasks",
            focusSubtitle: "Targeted deep maintenance · Non-routine upkeep",
            heroTools: "TOOLS: Microfiber cloths, food-safe sanitizer, brush kit.",
            focusJobs: [
                FocusJob(id: kitchenId, tag: "KITCHEN", title: "Deep clean countertops", isOverdue: false),
                FocusJob(id: floorsId, tag: "FLOORS", title: "Scrub floors & crevices", isOverdue: true),
                FocusJob(id: fridgeId, tag: "APPLIANCE", title: "Deep clean refrigerator"),
                FocusJob(id: bottlesId, tag: "PANTRY", title: "Wash kombucha bottles"),
                FocusJob(id: brewingId, tag: "BREWING", title: "Prep kombucha batch"),
                FocusJob(id: sinkId, tag: "PLUMBING", title: "Sanitize sink & drain")
            ],
            baselineTitle: "Daily Baseline",
            baselineSubtitle: "Est: 31 min · Daily maintenance",
            baselineRule: "RULE: Complete before noon.",
            baselineTasks: [
                ChoreItem(id: stretchId, title: "Stretch", durationMinutes: 10, tag: "BODY"),
                ChoreItem(id: meditateId, title: "13-minute meditation", durationMinutes: 13, tag: "MIND"),
                ChoreItem(id: dishesId, title: "Wash dishes", durationMinutes: 8, tag: "KITCHEN")
            ],
            upcomingEvents: [
                HorizonEvent(tag: "PLANTS", title: "Water flowers", timeAnchor: "In 2 Days", repeatCount: 4, repeatUnit: .day, healthState: .notYet),
                HorizonEvent(tag: "WASTE", title: "Kitchen trash", timeAnchor: "In 3 Days", repeatCount: 1, repeatUnit: .week, healthState: .notYet),
                HorizonEvent(tag: "FLOORS", title: "Basic vacuuming", timeAnchor: "In 12 Days", repeatCount: 2, repeatUnit: .week, healthState: .good),
                HorizonEvent(tag: "STORAGE", title: "Tidy up boxes", timeAnchor: "In 28 Days", repeatCount: 1, repeatUnit: .month, healthState: .good),
                HorizonEvent(tag: "BATH", title: "Clean bathtub", timeAnchor: "In 28 Days", repeatCount: 1, repeatUnit: .month, healthState: .good)
            ],
            telemetryMetrics: [],
            historyRecords: [
                HistoryRecord(jobId: kitchenId, title: "Deep clean countertops", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 0, hour: 9, minute: 15)),
                HistoryRecord(jobId: sinkId, title: "Sanitize sink & drain", tag: "PLUMBING", completedAt: relativeDate(daysAgo: 1, hour: 19, minute: 40)),
                HistoryRecord(jobId: dishesId, title: "Wash dishes", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 1, hour: 12, minute: 30)),
                HistoryRecord(jobId: floorsId, title: "Scrub floors & crevices", tag: "FLOORS", completedAt: relativeDate(daysAgo: 2, hour: 11, minute: 10)),
                HistoryRecord(jobId: kitchenId, title: "Deep clean countertops", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 3, hour: 16, minute: 20)),
                HistoryRecord(jobId: bottlesId, title: "Wash kombucha bottles", tag: "PANTRY", completedAt: relativeDate(daysAgo: 4, hour: 14, minute: 0)),
                HistoryRecord(jobId: sinkId, title: "Sanitize sink & drain", tag: "PLUMBING", completedAt: relativeDate(daysAgo: 5, hour: 20, minute: 15)),
                HistoryRecord(jobId: kitchenId, title: "Deep clean countertops", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 6, hour: 8, minute: 45))
            ],
            customTags: ["KITCHEN", "FLOORS", "APPLIANCE", "PLUMBING", "PANTRY", "BREWING", "BODY", "MIND", "PLANTS", "WASTE", "STORAGE", "BATH"]
        )
    }()
}