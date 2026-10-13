import Foundation

public enum PreviewData {
    public static let defaultState = DashboardState(
        focusOverline: "SCHEDULED OPERATIONS",
        focusTitle: "Main Tasks",
        focusSubtitle: "Targeted deep maintenance · Non-routine upkeep",
        heroTools: "TOOLS: Microfiber cloths, food-safe sanitizer, brush kit.",
        focusJobs: [
            FocusJob(
                tag: "KITCHEN",
                title: "Deep clean countertops",
                notes: "Clear surfaces and wipe with food-safe sanitizer."
            ),
            FocusJob(
                tag: "FLOORS",
                title: "Scrub floors & crevices",
                notes: ""
            ),
            FocusJob(
                tag: "APPLIANCE",
                title: "Deep clean refrigerator",
                notes: "Purge expired items; wipe shelves and door seals."
            ),
            FocusJob(
                tag: "PANTRY",
                title: "Wash kombucha bottles",
                notes: ""
            ),
            FocusJob(
                tag: "BREWING",
                title: "Prep kombucha batch",
                notes: "Brew sweet tea base and pitch starter culture."
            ),
            FocusJob(
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
        telemetryMetrics: []
    )
}