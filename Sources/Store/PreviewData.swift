import Foundation

public enum PreviewData {
    public static let defaultState = DashboardState(
        focusOverline: "KITCHEN & BREWING",
        focusTitle: "Kitchen Deep Clean & Kombucha",
        focusSubtitle: "Sanitation · Bottle prep · Fermentation",
        heroTools: "TOOLS: Food-safe sanitizer, microfiber cloths, bottle brush.",
        focusJobs: [
            FocusJob(
                tag: "COUNTERS",
                title: "Deep clean countertops",
                notes: "Clear surfaces and wipe with sanitizer."
            ),
            FocusJob(
                tag: "FLOORS",
                title: "Scrub floors & crevices",
                notes: ""
            ),
            FocusJob(
                tag: "FRIDGE",
                title: "Deep clean refrigerator",
                notes: "Purge expired items; wipe shelves and door seals."
            ),
            FocusJob(
                tag: "BOTTLES",
                title: "Wash kombucha bottles",
                notes: ""
            ),
            FocusJob(
                tag: "KOMBUCHA",
                title: "Prep kombucha batch",
                notes: "Brew sweet tea base and pitch starter culture."
            ),
            FocusJob(
                tag: "SINK",
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
        telemetryMetrics: [
            TelemetryMetric(label: "Kombucha", status: "Day 6 / 10"),
            TelemetryMetric(label: "Flowers", status: "Moist"),
            TelemetryMetric(label: "Dishes", status: "Clear"),
            TelemetryMetric(label: "Trash bags", status: "6 left")
        ]
    )
}