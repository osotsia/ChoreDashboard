import Foundation

public enum PreviewData {
    // MARK: - Dynamic Relative Temporal Anchors (Relative to Date())
    private static func relativeDate(daysAgo: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) - daysAgo
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return cal.date(from: comps) ?? Date()
    }

    private static func daysFromNow(_ days: Int, hour: Int = 16, minute: Int = 0, second: Int = 0) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) + days
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return cal.date(from: comps) ?? Date()
    }

    private static func id(_ string: String) -> UUID {
        UUID(uuidString: string)!
    }

    // MARK: - Default Application Seed & SwiftUI Preview State
    public static let defaultState: DashboardState = {
        // Deterministic Task Identifiers from sample.json
        let t01 = id("A1000001-0000-4000-8000-000000000001")
        let t02 = id("A1000002-0000-4000-8000-000000000002")
        let t03 = id("A1000003-0000-4000-8000-000000000003")
        let t04 = id("A1000004-0000-4000-8000-000000000004")
        let t05 = id("A1000005-0000-4000-8000-000000000005")
        let t06 = id("A1000006-0000-4000-8000-000000000006")
        let t07 = id("A1000007-0000-4000-8000-000000000007")
        let t08 = id("A1000008-0000-4000-8000-000000000008")
        let t09 = id("A1000009-0000-4000-8000-000000000009")
        let t10 = id("A1000010-0000-4000-8000-000000000010")
        let t11 = id("A1000011-0000-4000-8000-000000000011")
        let t12 = id("A1000012-0000-4000-8000-000000000012")
        let t13 = id("A1000013-0000-4000-8000-000000000013")
        let t14 = id("A1000014-0000-4000-8000-000000000014")
        let t15 = id("A1000015-0000-4000-8000-000000000015")

        let baseCreated = relativeDate(daysAgo: 24, hour: 8, minute: 0)

        return DashboardState(
            schemaVersion: 2,
            tasks: [
                // 1. Daily Baseline Operations (1-Day Cadence)
                TaskItem(
                    id: t01,
                    title: "Wipe kitchen counters & sink",
                    tag: "KITCHEN",
                    durationMinutes: 10,
                    isCompleted: true,
                    dueDate: daysFromNow(0, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 0, hour: 9, minute: 14, second: 22),
                    recurrence: RecurrenceRule(count: 1, unit: .day),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t02,
                    title: "Run dishwasher & put away dishes",
                    tag: "KITCHEN",
                    durationMinutes: 15,
                    isCompleted: false,
                    dueDate: daysFromNow(0, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 1, hour: 21, minute: 30),
                    recurrence: RecurrenceRule(count: 1, unit: .day),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t03,
                    title: "Evening 15-minute house tidy",
                    tag: "LIVING",
                    durationMinutes: 15,
                    isCompleted: false,
                    dueDate: daysFromNow(0, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 1, hour: 20, minute: 45, second: 15),
                    recurrence: RecurrenceRule(count: 1, unit: .day),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t04,
                    title: "Make bed & air out bedroom",
                    tag: "BEDROOM",
                    durationMinutes: 5,
                    isCompleted: true,
                    dueDate: daysFromNow(0, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 0, hour: 8, minute: 45, second: 10),
                    recurrence: RecurrenceRule(count: 1, unit: .day),
                    createdAt: baseCreated
                ),

                // 2. Active Focus & Horizon Maintenance Operations
                TaskItem(
                    id: t05,
                    title: "Vacuum all rugs and carpets",
                    tag: "LIVING",
                    durationMinutes: 20,
                    isCompleted: false,
                    dueDate: daysFromNow(2, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 5, hour: 17, minute: 45),
                    recurrence: RecurrenceRule(count: 1, unit: .week),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t06,
                    title: "Mop kitchen and entryway floors",
                    tag: "KITCHEN",
                    durationMinutes: 25,
                    isCompleted: false,
                    dueDate: daysFromNow(-1, hour: 16), // 1 day overdue
                    lastCompletedAt: relativeDate(daysAgo: 8, hour: 18, minute: 15),
                    recurrence: RecurrenceRule(count: 1, unit: .week),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t07,
                    title: "Clean toilets and bathroom sinks",
                    tag: "BATHROOM",
                    durationMinutes: 20,
                    isCompleted: false,
                    dueDate: daysFromNow(4, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 3, hour: 16, minute: 30),
                    recurrence: RecurrenceRule(count: 1, unit: .week),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t08,
                    title: "Scrub bathtub and shower stall",
                    tag: "BATHROOM",
                    durationMinutes: 30,
                    isCompleted: false,
                    dueDate: daysFromNow(7, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 7, hour: 15, minute: 30),
                    recurrence: RecurrenceRule(count: 2, unit: .week),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t09,
                    title: "Wash bed linens and pillowcases",
                    tag: "BEDROOM",
                    durationMinutes: 20,
                    isCompleted: false,
                    dueDate: daysFromNow(7, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 7, hour: 16, minute: 20),
                    recurrence: RecurrenceRule(count: 2, unit: .week),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t10,
                    title: "Deep clean microwave and stovetop",
                    tag: "KITCHEN",
                    durationMinutes: 25,
                    isCompleted: false,
                    dueDate: daysFromNow(22, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 9, hour: 17, minute: 0),
                    recurrence: RecurrenceRule(count: 1, unit: .month),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t11,
                    title: "Clean refrigerator shelves & drawers",
                    tag: "KITCHEN",
                    durationMinutes: 35,
                    isCompleted: false,
                    dueDate: daysFromNow(20, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 11, hour: 16, minute: 45),
                    recurrence: RecurrenceRule(count: 1, unit: .month),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t12,
                    title: "Dust ceiling fans and blinds",
                    tag: "LIVING",
                    durationMinutes: 20,
                    isCompleted: false,
                    dueDate: daysFromNow(-2, hour: 16), // 2 days overdue
                    lastCompletedAt: nil,
                    recurrence: RecurrenceRule(count: 1, unit: .month),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t13,
                    title: "Replace HVAC air filters",
                    tag: "MAINTENANCE",
                    durationMinutes: 15,
                    isCompleted: false,
                    dueDate: daysFromNow(91, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 1, hour: 15, minute: 10, second: 12),
                    recurrence: RecurrenceRule(count: 3, unit: .month),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t14,
                    title: "Clean dryer lint trap and duct vent",
                    tag: "MAINTENANCE",
                    durationMinutes: 30,
                    isCompleted: false,
                    dueDate: daysFromNow(169, hour: 16),
                    lastCompletedAt: relativeDate(daysAgo: 13, hour: 14, minute: 10),
                    recurrence: RecurrenceRule(count: 6, unit: .month),
                    createdAt: baseCreated
                ),
                TaskItem(
                    id: t15,
                    title: "Replace guest bathroom faucet washer",
                    tag: "BATHROOM",
                    durationMinutes: 30,
                    isCompleted: false,
                    dueDate: daysFromNow(0, hour: 16),
                    lastCompletedAt: nil,
                    recurrence: nil, // One-Time execution
                    createdAt: relativeDate(daysAgo: 1, hour: 10, minute: 0)
                )
            ],
            historyRecords: [
                // Day 0 (Today: 2026-10-25)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000001"), taskId: t01, title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 0, hour: 9, minute: 14, second: 22), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000002"), taskId: t04, title: "Make bed & air out bedroom", tag: "BEDROOM", completedAt: relativeDate(daysAgo: 0, hour: 8, minute: 45, second: 10), isDailyBaseline: true),

                // Day 1 (1 day ago: 2026-10-24)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000003"), taskId: t02, title: "Run dishwasher & put away dishes", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 1, hour: 21, minute: 30), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000004"), taskId: t03, title: "Evening 15-minute house tidy", tag: "LIVING", completedAt: relativeDate(daysAgo: 1, hour: 20, minute: 45, second: 15), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000005"), taskId: t01, title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 1, hour: 18, minute: 22, second: 40), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000006"), taskId: t13, title: "Replace HVAC air filters", tag: "MAINTENANCE", completedAt: relativeDate(daysAgo: 1, hour: 15, minute: 10, second: 12), isDailyBaseline: false),

                // Day 2 (2 days ago: 2026-10-23)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000007"), taskId: t02, title: "Run dishwasher & put away dishes", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 2, hour: 22, minute: 5), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000008"), taskId: t03, title: "Evening 15-minute house tidy", tag: "LIVING", completedAt: relativeDate(daysAgo: 2, hour: 21, minute: 15, second: 30), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000009"), taskId: t01, title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 2, hour: 19, minute: 30), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000010"), taskId: t04, title: "Make bed & air out bedroom", tag: "BEDROOM", completedAt: relativeDate(daysAgo: 2, hour: 8, minute: 10), isDailyBaseline: true),

                // Day 3 (3 days ago: 2026-10-22)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000011"), taskId: t02, title: "Run dishwasher & put away dishes", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 3, hour: 21, minute: 40), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000012"), taskId: t01, title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 3, hour: 19, minute: 15), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000013"), taskId: t07, title: "Clean toilets and bathroom sinks", tag: "BATHROOM", completedAt: relativeDate(daysAgo: 3, hour: 16, minute: 30), isDailyBaseline: false),

                // Day 4 (4 days ago: 2026-10-21)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000014"), taskId: t03, title: "Evening 15-minute house tidy", tag: "LIVING", completedAt: relativeDate(daysAgo: 4, hour: 21, minute: 10), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000015"), taskId: t01, title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 4, hour: 19, minute: 50), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000016"), taskId: t04, title: "Make bed & air out bedroom", tag: "BEDROOM", completedAt: relativeDate(daysAgo: 4, hour: 8, minute: 20), isDailyBaseline: true),

                // Day 5 (5 days ago: 2026-10-20)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000017"), taskId: t05, title: "Vacuum all rugs and carpets", tag: "LIVING", completedAt: relativeDate(daysAgo: 5, hour: 17, minute: 45), isDailyBaseline: false),

                // Day 6 (6 days ago: 2026-10-19)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000018"), taskId: t02, title: "Run dishwasher & put away dishes", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 6, hour: 21, minute: 0), isDailyBaseline: true),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000019"), taskId: t01, title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 6, hour: 19, minute: 10), isDailyBaseline: true),

                // Day 7 (7 days ago: 2026-10-18)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000020"), taskId: t09, title: "Wash bed linens and pillowcases", tag: "BEDROOM", completedAt: relativeDate(daysAgo: 7, hour: 16, minute: 20), isDailyBaseline: false),
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000021"), taskId: t08, title: "Scrub bathtub and shower stall", tag: "BATHROOM", completedAt: relativeDate(daysAgo: 7, hour: 15, minute: 30), isDailyBaseline: false),

                // Day 8 (8 days ago: 2026-10-17)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000022"), taskId: t06, title: "Mop kitchen and entryway floors", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 8, hour: 18, minute: 15), isDailyBaseline: false),

                // Day 9 (9 days ago: 2026-10-16)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000023"), taskId: t10, title: "Deep clean microwave and stovetop", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 9, hour: 17, minute: 0), isDailyBaseline: false),

                // Day 11 (11 days ago: 2026-10-14)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000024"), taskId: t11, title: "Clean refrigerator shelves & drawers", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 11, hour: 16, minute: 45), isDailyBaseline: false),

                // Day 13 (13 days ago: 2026-10-12)
                HistoryRecord(id: id("F1000001-0000-4000-8000-000000000025"), taskId: t14, title: "Clean dryer lint trap and duct vent", tag: "MAINTENANCE", completedAt: relativeDate(daysAgo: 13, hour: 14, minute: 10), isDailyBaseline: false)
            ],
            customTags: [
                "KITCHEN", "BATHROOM", "LIVING", "BEDROOM", "MAINTENANCE", "GENERAL"
            ],
            trackingStartDate: nil,
            focusOverline: "SCHEDULED OPERATIONS",
            focusTitle: "Main Tasks",
            focusSubtitle: "Targeted deep maintenance · Non-routine upkeep",
            heroTools: "PREPARATION: Stage required supplies and workspace before starting major tasks.",
            baselineTitle: "Daily Baseline",
            baselineRule: "RULE: Complete before noon."
        )
    }()

    // MARK: - Exact Literal Timestamp Snapshot (Fixed to 2026-10-25)
    public static func exactFileState() -> DashboardState {
        let isoFormatter = ISO8601DateFormatter()
        let d: (String) -> Date = { isoFormatter.date(from: $0)! }
        let u: (String) -> UUID = { UUID(uuidString: $0)! }

        return DashboardState(
            schemaVersion: 2,
            tasks: [
                TaskItem(id: u("A1000001-0000-4000-8000-000000000001"), title: "Wipe kitchen counters & sink", tag: "KITCHEN", durationMinutes: 10, isCompleted: true, dueDate: d("2026-10-25T16:00:00Z"), lastCompletedAt: d("2026-10-25T09:14:22Z"), recurrence: RecurrenceRule(count: 1, unit: .day), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000002-0000-4000-8000-000000000002"), title: "Run dishwasher & put away dishes", tag: "KITCHEN", durationMinutes: 15, isCompleted: false, dueDate: d("2026-10-25T16:00:00Z"), lastCompletedAt: d("2026-10-24T21:30:00Z"), recurrence: RecurrenceRule(count: 1, unit: .day), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000003-0000-4000-8000-000000000003"), title: "Evening 15-minute house tidy", tag: "LIVING", durationMinutes: 15, isCompleted: false, dueDate: d("2026-10-25T16:00:00Z"), lastCompletedAt: d("2026-10-24T20:45:15Z"), recurrence: RecurrenceRule(count: 1, unit: .day), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000004-0000-4000-8000-000000000004"), title: "Make bed & air out bedroom", tag: "BEDROOM", durationMinutes: 5, isCompleted: true, dueDate: d("2026-10-25T16:00:00Z"), lastCompletedAt: d("2026-10-25T08:45:10Z"), recurrence: RecurrenceRule(count: 1, unit: .day), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000005-0000-4000-8000-000000000005"), title: "Vacuum all rugs and carpets", tag: "LIVING", durationMinutes: 20, isCompleted: false, dueDate: d("2026-10-27T16:00:00Z"), lastCompletedAt: d("2026-10-20T17:45:00Z"), recurrence: RecurrenceRule(count: 1, unit: .week), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000006-0000-4000-8000-000000000006"), title: "Mop kitchen and entryway floors", tag: "KITCHEN", durationMinutes: 25, isCompleted: false, dueDate: d("2026-10-24T16:00:00Z"), lastCompletedAt: d("2026-10-17T18:15:00Z"), recurrence: RecurrenceRule(count: 1, unit: .week), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000007-0000-4000-8000-000000000007"), title: "Clean toilets and bathroom sinks", tag: "BATHROOM", durationMinutes: 20, isCompleted: false, dueDate: d("2026-10-29T16:00:00Z"), lastCompletedAt: d("2026-10-22T16:30:00Z"), recurrence: RecurrenceRule(count: 1, unit: .week), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000008-0000-4000-8000-000000000008"), title: "Scrub bathtub and shower stall", tag: "BATHROOM", durationMinutes: 30, isCompleted: false, dueDate: d("2026-11-01T16:00:00Z"), lastCompletedAt: d("2026-10-18T15:30:00Z"), recurrence: RecurrenceRule(count: 2, unit: .week), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000009-0000-4000-8000-000000000009"), title: "Wash bed linens and pillowcases", tag: "BEDROOM", durationMinutes: 20, isCompleted: false, dueDate: d("2026-11-01T16:00:00Z"), lastCompletedAt: d("2026-10-18T16:20:00Z"), recurrence: RecurrenceRule(count: 2, unit: .week), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000010-0000-4000-8000-000000000010"), title: "Deep clean microwave and stovetop", tag: "KITCHEN", durationMinutes: 25, isCompleted: false, dueDate: d("2026-11-16T16:00:00Z"), lastCompletedAt: d("2026-10-16T17:00:00Z"), recurrence: RecurrenceRule(count: 1, unit: .month), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000011-0000-4000-8000-000000000011"), title: "Clean refrigerator shelves & drawers", tag: "KITCHEN", durationMinutes: 35, isCompleted: false, dueDate: d("2026-11-14T16:00:00Z"), lastCompletedAt: d("2026-10-14T16:45:00Z"), recurrence: RecurrenceRule(count: 1, unit: .month), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000012-0000-4000-8000-000000000012"), title: "Dust ceiling fans and blinds", tag: "LIVING", durationMinutes: 20, isCompleted: false, dueDate: d("2026-10-23T16:00:00Z"), lastCompletedAt: nil, recurrence: RecurrenceRule(count: 1, unit: .month), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000013-0000-4000-8000-000000000013"), title: "Replace HVAC air filters", tag: "MAINTENANCE", durationMinutes: 15, isCompleted: false, dueDate: d("2027-01-24T16:00:00Z"), lastCompletedAt: d("2026-10-24T15:10:12Z"), recurrence: RecurrenceRule(count: 3, unit: .month), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000014-0000-4000-8000-000000000014"), title: "Clean dryer lint trap and duct vent", tag: "MAINTENANCE", durationMinutes: 30, isCompleted: false, dueDate: d("2027-04-12T16:00:00Z"), lastCompletedAt: d("2026-10-12T14:10:00Z"), recurrence: RecurrenceRule(count: 6, unit: .month), createdAt: d("2026-10-01T08:00:00Z")),
                TaskItem(id: u("A1000015-0000-4000-8000-000000000015"), title: "Replace guest bathroom faucet washer", tag: "BATHROOM", durationMinutes: 30, isCompleted: false, dueDate: d("2026-10-25T16:00:00Z"), lastCompletedAt: nil, recurrence: nil, createdAt: d("2026-10-24T10:00:00Z"))
            ],
            historyRecords: [
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000001"), taskId: u("A1000001-0000-4000-8000-000000000001"), title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: d("2026-10-25T09:14:22Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000002"), taskId: u("A1000004-0000-4000-8000-000000000004"), title: "Make bed & air out bedroom", tag: "BEDROOM", completedAt: d("2026-10-25T08:45:10Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000003"), taskId: u("A1000002-0000-4000-8000-000000000002"), title: "Run dishwasher & put away dishes", tag: "KITCHEN", completedAt: d("2026-10-24T21:30:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000004"), taskId: u("A1000003-0000-4000-8000-000000000003"), title: "Evening 15-minute house tidy", tag: "LIVING", completedAt: d("2026-10-24T20:45:15Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000005"), taskId: u("A1000001-0000-4000-8000-000000000001"), title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: d("2026-10-24T18:22:40Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000006"), taskId: u("A1000013-0000-4000-8000-000000000013"), title: "Replace HVAC air filters", tag: "MAINTENANCE", completedAt: d("2026-10-24T15:10:12Z"), isDailyBaseline: false),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000007"), taskId: u("A1000002-0000-4000-8000-000000000002"), title: "Run dishwasher & put away dishes", tag: "KITCHEN", completedAt: d("2026-10-23T22:05:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000008"), taskId: u("A1000003-0000-4000-8000-000000000003"), title: "Evening 15-minute house tidy", tag: "LIVING", completedAt: d("2026-10-23T21:15:30Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000009"), taskId: u("A1000001-0000-4000-8000-000000000001"), title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: d("2026-10-23T19:30:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000010"), taskId: u("A1000004-0000-4000-8000-000000000004"), title: "Make bed & air out bedroom", tag: "BEDROOM", completedAt: d("2026-10-23T08:10:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000011"), taskId: u("A1000002-0000-4000-8000-000000000002"), title: "Run dishwasher & put away dishes", tag: "KITCHEN", completedAt: d("2026-10-22T21:40:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000012"), taskId: u("A1000001-0000-4000-8000-000000000001"), title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: d("2026-10-22T19:15:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000013"), taskId: u("A1000007-0000-4000-8000-000000000007"), title: "Clean toilets and bathroom sinks", tag: "BATHROOM", completedAt: d("2026-10-22T16:30:00Z"), isDailyBaseline: false),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000014"), taskId: u("A1000003-0000-4000-8000-000000000003"), title: "Evening 15-minute house tidy", tag: "LIVING", completedAt: d("2026-10-21T21:10:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000015"), taskId: u("A1000001-0000-4000-8000-000000000001"), title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: d("2026-10-21T19:50:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000016"), taskId: u("A1000004-0000-4000-8000-000000000004"), title: "Make bed & air out bedroom", tag: "BEDROOM", completedAt: d("2026-10-21T08:20:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000017"), taskId: u("A1000005-0000-4000-8000-000000000005"), title: "Vacuum all rugs and carpets", tag: "LIVING", completedAt: d("2026-10-20T17:45:00Z"), isDailyBaseline: false),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000018"), taskId: u("A1000002-0000-4000-8000-000000000002"), title: "Run dishwasher & put away dishes", tag: "KITCHEN", completedAt: d("2026-10-19T21:00:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000019"), taskId: u("A1000001-0000-4000-8000-000000000001"), title: "Wipe kitchen counters & sink", tag: "KITCHEN", completedAt: d("2026-10-19T19:10:00Z"), isDailyBaseline: true),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000020"), taskId: u("A1000009-0000-4000-8000-000000000009"), title: "Wash bed linens and pillowcases", tag: "BEDROOM", completedAt: d("2026-10-18T16:20:00Z"), isDailyBaseline: false),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000021"), taskId: u("A1000008-0000-4000-8000-000000000008"), title: "Scrub bathtub and shower stall", tag: "BATHROOM", completedAt: d("2026-10-18T15:30:00Z"), isDailyBaseline: false),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000022"), taskId: u("A1000006-0000-4000-8000-000000000006"), title: "Mop kitchen and entryway floors", tag: "KITCHEN", completedAt: d("2026-10-17T18:15:00Z"), isDailyBaseline: false),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000023"), taskId: u("A1000010-0000-4000-8000-000000000010"), title: "Deep clean microwave and stovetop", tag: "KITCHEN", completedAt: d("2026-10-16T17:00:00Z"), isDailyBaseline: false),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000024"), taskId: u("A1000011-0000-4000-8000-000000000011"), title: "Clean refrigerator shelves & drawers", tag: "KITCHEN", completedAt: d("2026-10-14T16:45:00Z"), isDailyBaseline: false),
                HistoryRecord(id: u("F1000001-0000-4000-8000-000000000025"), taskId: u("A1000014-0000-4000-8000-000000000014"), title: "Clean dryer lint trap and duct vent", tag: "MAINTENANCE", completedAt: d("2026-10-12T14:10:00Z"), isDailyBaseline: false)
            ],
            customTags: ["KITCHEN", "BATHROOM", "LIVING", "BEDROOM", "MAINTENANCE", "GENERAL"],
            trackingStartDate: nil,
            focusOverline: "SCHEDULED OPERATIONS",
            focusTitle: "Main Tasks",
            focusSubtitle: "Targeted deep maintenance · Non-routine upkeep",
            heroTools: "PREPARATION: Stage required supplies and workspace before starting major tasks.",
            baselineTitle: "Daily Baseline",
            baselineRule: "RULE: Complete before noon."
        )
    }
}