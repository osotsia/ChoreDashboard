// Sources/Store/PreviewData.swift
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
                    notes: "Clear surfaces and wipe with food-safe sanitizer."
                ),
                FocusJob(
                    id: floorsId,
                    tag: "FLOORS",
                    title: "Scrub floors & crevices",
                    notes: ""
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
            baselineSubtitle: "Est: 25 min · Daily maintenance",
            baselineRule: "RULE: Complete before noon.",
            baselineTasks: [
                ChoreItem(title: "Stretch", durationMinutes: 10, tag: "Body"),
                ChoreItem(title: "13-minute meditation", durationMinutes: 13, tag: "Mind"),
                ChoreItem(title: "Wash dishes", durationMinutes: 8, tag: "Kitchen")
            ],
            upcomingEvents: [
                HorizonEvent(
                    tag: "Plants · Thu, Oct 15",
                    title: "Water flowers",
                    notes: "Check soil and water indoor pots.",
                    timeAnchor: "In 2 Days"
                ),
                HorizonEvent(
                    tag: "Waste · Fri, Oct 16",
                    title: "Kitchen trash",
                    notes: "Empty can and replace liner.",
                    timeAnchor: "In 3 Days"
                ),
                HorizonEvent(
                    tag: "Floors · Wed, Oct 25",
                    title: "Basic vacuuming",
                    notes: "Vacuum living room and main walkways.",
                    timeAnchor: "In 12 Days"
                ),
                HorizonEvent(
                    tag: "Storage · Sun, Nov 10",
                    title: "Tidy up boxes",
                    notes: "Break down cardboard and recycle.",
                    timeAnchor: "In 28 Days"
                ),
                HorizonEvent(
                    tag: "Bath · Sun, Nov 10",
                    title: "Clean bathtub",
                    notes: "Scrub tub basin and wipe fixtures.",
                    timeAnchor: "In 28 Days"
                )
            ],
            telemetryMetrics: [],
            // History audit entries (Spread over 7 days):
            // "Deep clean countertops" -> 3 entries
            // "Sanitize sink & drain" -> 2 entries
            // "Scrub floors & crevices" -> 1 entry
            // "Wash kombucha bottles" -> 1 entry
            // "Deep clean refrigerator" -> 0 entries (no data)
            // "Prep kombucha batch" -> 0 entries (no data)
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
            ]
        )
    }()
}