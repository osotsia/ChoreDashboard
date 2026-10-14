// --- File: Sources/Store/PreviewData.swift ---
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
                FocusJob(
                    id: kitchenId,
                    tag: "KITCHEN",
                    title: "Deep clean countertops",
                    notes: "Clear surfaces and wipe with food-safe sanitizer.",
                    isOverdue: false
                ),
                FocusJob(
                    id: floorsId,
                    tag: "FLOORS",
                    title: "Scrub floors & crevices",
                    notes: "",
                    isOverdue: true
                ),
                FocusJob(
                    id: fridgeId,
                    tag: "APPLIANCE",
                    title: "Deep clean refrigerator",
                    notes: "Purge expired items; wipe shelves and door seals."
                ),
                FocusJob(
                    id: bottlesId,
                    tag: "PANTRY",
                    title: "Wash kombucha bottles",
                    notes: ""
                ),
                FocusJob(
                    id: brewingId,
                    tag: "BREWING",
                    title: "Prep kombucha batch",
                    notes: "Brew sweet tea base and pitch starter culture."
                ),
                FocusJob(
                    id: sinkId,
                    tag: "PLUMBING",
                    title: "Sanitize sink & drain",
                    notes: ""
                )
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
                HorizonEvent(
                    tag: "PLANTS",
                    title: "Water flowers",
                    notes: "Check soil and water indoor pots.",
                    timeAnchor: "In 2 Days"
                ),
                HorizonEvent(
                    tag: "WASTE",
                    title: "Kitchen trash",
                    notes: "Empty can and replace liner.",
                    timeAnchor: "In 3 Days"
                ),
                HorizonEvent(
                    tag: "FLOORS",
                    title: "Basic vacuuming",
                    notes: "Vacuum living room and main walkways.",
                    timeAnchor: "In 12 Days"
                ),
                HorizonEvent(
                    tag: "STORAGE",
                    title: "Tidy up boxes",
                    notes: "Break down cardboard and recycle.",
                    timeAnchor: "In 28 Days"
                ),
                HorizonEvent(
                    tag: "BATH",
                    title: "Clean bathtub",
                    notes: "Scrub tub basin and wipe fixtures.",
                    timeAnchor: "In 28 Days"
                )
            ],
            telemetryMetrics: [
                TelemetryMetric(label: "CYCLE HEALTH", status: "NOMINAL"),
                TelemetryMetric(label: "QUEUE LATENCY", status: "< 24H")
            ],
            historyRecords: [
                HistoryRecord(
                    jobId: kitchenId,
                    title: "Deep clean countertops",
                    tag: "KITCHEN",
                    completedAt: relativeDate(daysAgo: 0, hour: 9, minute: 15),
                    note: "Wiped prep zones and disinfected cutting boards."
                ),
                HistoryRecord(
                    jobId: sinkId,
                    title: "Sanitize sink & drain",
                    tag: "PLUMBING",
                    completedAt: relativeDate(daysAgo: 1, hour: 19, minute: 40),
                    note: "Enzyme treatment down main drain."
                ),
                HistoryRecord(
                    jobId: dishesId,
                    title: "Wash dishes",
                    tag: "KITCHEN",
                    completedAt: relativeDate(daysAgo: 1, hour: 12, minute: 30),
                    note: "Cleared afternoon basin load."
                ),
                HistoryRecord(
                    jobId: floorsId,
                    title: "Scrub floors & crevices",
                    tag: "FLOORS",
                    completedAt: relativeDate(daysAgo: 2, hour: 11, minute: 10),
                    note: "Corner scrub along oven line."
                ),
                HistoryRecord(
                    jobId: kitchenId,
                    title: "Deep clean countertops",
                    tag: "KITCHEN",
                    completedAt: relativeDate(daysAgo: 3, hour: 16, minute: 20),
                    note: "Polished stone surfaces."
                ),
                HistoryRecord(
                    jobId: bottlesId,
                    title: "Wash kombucha bottles",
                    tag: "PANTRY",
                    completedAt: relativeDate(daysAgo: 4, hour: 14, minute: 0),
                    note: "12 flip-top bottles boiled and dried."
                ),
                HistoryRecord(
                    jobId: sinkId,
                    title: "Sanitize sink & drain",
                    tag: "PLUMBING",
                    completedAt: relativeDate(daysAgo: 5, hour: 20, minute: 15),
                    note: "Hot water rinse and bleach sanitization."
                ),
                HistoryRecord(
                    jobId: kitchenId,
                    title: "Deep clean countertops",
                    tag: "KITCHEN",
                    completedAt: relativeDate(daysAgo: 6, hour: 8, minute: 45),
                    note: "Weekly deep surface scrub."
                )
            ],
            customTags: ["KITCHEN", "FLOORS", "APPLIANCE", "PLUMBING", "PANTRY", "BREWING", "BODY", "MIND", "PLANTS", "WASTE", "STORAGE", "BATH"]
        )
    }()
}