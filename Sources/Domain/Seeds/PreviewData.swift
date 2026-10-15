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

    private static func daysFromNow(_ days: Int, hour: Int = 12, minute: Int = 0) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) + days
        comps.hour = hour
        comps.minute = minute
        return cal.date(from: comps) ?? Date()
    }

    public static let defaultState: DashboardState = {
        // MARK: - Task Identifiers
        // Self
        let stretchId        = UUID()
        let meditationId     = UUID()

        // Kitchen
        let wipeCountersId   = UUID()
        let prepKombucha2Id  = UUID()
        let cleanFloorsId    = UUID()
        let cleanFridgeId    = UUID()
        let washBottlesId    = UUID()
        let prepKombucha1Id  = UUID()
        let deepCountersId   = UUID()
        let tidyFridgeId     = UUID()

        // Bathroom
        let deepEdgesId      = UUID()
        let cleanWallsId     = UUID()
        let cleanToiletId    = UUID()
        let cleanSinkId      = UUID()
        let cleanBathtubId   = UUID()
        let showerWall1Id    = UUID()
        let showerWall2Id    = UUID()
        let bathroomTrashId  = UUID()

        // General
        let waterFlowersId   = UUID()
        let basicVacuumId    = UUID()
        let tidyRearrangeId  = UUID()
        let dustSurfacesId   = UUID()
        let tidyBoxesId      = UUID()
        let deepVacuumId     = UUID()

        return DashboardState(
            schemaVersion: 2,
            tasks: [
                // ==========================================
                // 1. DAILY BASELINE (1-Day Cadence)
                // ==========================================
                TaskItem(
                    id: stretchId,
                    title: "Stretch (shoulders, inner thigh, hip flexor, squat)",
                    tag: "SELF",
                    durationMinutes: 10,
                    isCompleted: false,
                    dueDate: daysFromNow(0),
                    lastCompletedAt: relativeDate(daysAgo: 1, hour: 15, minute: 57),
                    recurrence: RecurrenceRule(count: 1, unit: .day)
                ),
                TaskItem(
                    id: meditationId,
                    title: "13m meditation",
                    tag: "SELF",
                    durationMinutes: 13,
                    isCompleted: false,
                    dueDate: daysFromNow(0),
                    lastCompletedAt: relativeDate(daysAgo: 1, hour: 18, minute: 31),
                    recurrence: RecurrenceRule(count: 1, unit: .day)
                ),
                TaskItem(
                    id: wipeCountersId,
                    title: "Wipe counters",
                    tag: "KITCHEN",
                    durationMinutes: 5,
                    isCompleted: false,
                    dueDate: daysFromNow(0),
                    lastCompletedAt: relativeDate(daysAgo: 2, hour: 14, minute: 12),
                    recurrence: RecurrenceRule(count: 1, unit: .day)
                ),

                // ==========================================
                // 2. ACTIVE TODAY / OVERDUE FOCUS QUEUE
                // ==========================================
                TaskItem(
                    id: prepKombucha2Id,
                    title: "Prep kombucha 2/2",
                    tag: "KITCHEN",
                    durationMinutes: 20,
                    isCompleted: false,
                    dueDate: daysFromNow(-7), // 7 days overdue
                    lastCompletedAt: nil,
                    recurrence: RecurrenceRule(count: 1, unit: .month)
                ),
                TaskItem(
                    id: cleanFloorsId,
                    title: "Deep clean floors and edges",
                    tag: "KITCHEN",
                    durationMinutes: 45,
                    isCompleted: false,
                    dueDate: daysFromNow(-77), // 77 days overdue
                    lastCompletedAt: nil,
                    recurrence: RecurrenceRule(count: 3, unit: .month)
                ),
                TaskItem(
                    id: cleanFridgeId,
                    title: "Deep clean fridge",
                    tag: "KITCHEN",
                    durationMinutes: 35,
                    isCompleted: false,
                    dueDate: daysFromNow(-4), // 4 days overdue
                    lastCompletedAt: nil,
                    recurrence: RecurrenceRule(count: 3, unit: .month)
                ),
                TaskItem(
                    id: washBottlesId,
                    title: "Wash kombucha bottles",
                    tag: "KITCHEN",
                    durationMinutes: 15,
                    isCompleted: false,
                    dueDate: daysFromNow(0),
                    lastCompletedAt: nil,
                    recurrence: nil // One-Time execution
                ),
                TaskItem(
                    id: deepEdgesId,
                    title: "Deep clean edges",
                    tag: "BATHROOM",
                    durationMinutes: 25,
                    isCompleted: false,
                    dueDate: daysFromNow(-17), // 17 days overdue
                    lastCompletedAt: nil,
                    recurrence: RecurrenceRule(count: 3, unit: .month)
                ),
                TaskItem(
                    id: cleanWallsId,
                    title: "Clean walls",
                    tag: "BATHROOM",
                    durationMinutes: 30,
                    isCompleted: false,
                    dueDate: daysFromNow(-5), // 5 days overdue
                    lastCompletedAt: nil,
                    recurrence: RecurrenceRule(count: 3, unit: .month)
                ),

                // ==========================================
                // 3. UPCOMING HORIZON QUEUE
                // ==========================================
                TaskItem(
                    id: cleanToiletId,
                    title: "Clean toilet",
                    tag: "BATHROOM",
                    durationMinutes: 10,
                    isCompleted: false,
                    dueDate: daysFromNow(2),
                    lastCompletedAt: relativeDate(daysAgo: 5, hour: 13, minute: 7),
                    recurrence: RecurrenceRule(count: 1, unit: .week)
                ),
                TaskItem(
                    id: waterFlowersId,
                    title: "Water flowers",
                    tag: "GENERAL",
                    durationMinutes: 5,
                    isCompleted: false,
                    dueDate: daysFromNow(2),
                    lastCompletedAt: relativeDate(daysAgo: 1, hour: 16, minute: 37),
                    recurrence: RecurrenceRule(count: 4, unit: .day)
                ),
                TaskItem(
                    id: basicVacuumId,
                    title: "Basic vacùùming",
                    tag: "GENERAL",
                    durationMinutes: 15,
                    isCompleted: false,
                    dueDate: daysFromNow(9),
                    lastCompletedAt: relativeDate(daysAgo: 5, hour: 16, minute: 58),
                    recurrence: RecurrenceRule(count: 2, unit: .week)
                ),
                TaskItem(
                    id: cleanSinkId,
                    title: "Clean sink",
                    tag: "BATHROOM",
                    durationMinutes: 10,
                    isCompleted: false,
                    dueDate: daysFromNow(10),
                    lastCompletedAt: relativeDate(daysAgo: 4, hour: 20, minute: 1),
                    recurrence: RecurrenceRule(count: 2, unit: .week)
                ),
                TaskItem(
                    id: tidyRearrangeId,
                    title: "Tidy up / rearrange stuff",
                    tag: "GENERAL",
                    durationMinutes: 20,
                    isCompleted: false,
                    dueDate: daysFromNow(10),
                    lastCompletedAt: relativeDate(daysAgo: 4, hour: 19, minute: 41),
                    recurrence: RecurrenceRule(count: 2, unit: .week)
                ),
                TaskItem(
                    id: dustSurfacesId,
                    title: "Dust surfaces",
                    tag: "GENERAL",
                    durationMinutes: 15,
                    isCompleted: false,
                    dueDate: daysFromNow(13),
                    lastCompletedAt: relativeDate(daysAgo: 1, hour: 16, minute: 53),
                    recurrence: RecurrenceRule(count: 2, unit: .week)
                ),
                TaskItem(
                    id: cleanBathtubId,
                    title: "Clean bathtub",
                    tag: "BATHROOM",
                    durationMinutes: 20,
                    isCompleted: false,
                    dueDate: daysFromNow(25),
                    lastCompletedAt: relativeDate(daysAgo: 5, hour: 13, minute: 7),
                    recurrence: RecurrenceRule(count: 1, unit: .month)
                ),
                TaskItem(
                    id: tidyBoxesId,
                    title: "Tidy up boxes",
                    tag: "GENERAL",
                    durationMinutes: 20,
                    isCompleted: false,
                    dueDate: daysFromNow(25),
                    lastCompletedAt: relativeDate(daysAgo: 5, hour: 13, minute: 25),
                    recurrence: RecurrenceRule(count: 1, unit: .month)
                ),
                TaskItem(
                    id: tidyFridgeId,
                    title: "Tidy up fridge",
                    tag: "KITCHEN",
                    durationMinutes: 15,
                    isCompleted: false,
                    dueDate: daysFromNow(26),
                    lastCompletedAt: relativeDate(daysAgo: 4, hour: 20, minute: 10),
                    recurrence: RecurrenceRule(count: 1, unit: .month)
                ),
                TaskItem(
                    id: showerWall1Id,
                    title: "Shower wall 1/2",
                    tag: "BATHROOM",
                    durationMinutes: 15,
                    isCompleted: false,
                    dueDate: daysFromNow(26),
                    lastCompletedAt: relativeDate(daysAgo: 4, hour: 17, minute: 8),
                    recurrence: RecurrenceRule(count: 1, unit: .month)
                ),
                TaskItem(
                    id: showerWall2Id,
                    title: "Shower wall 2/2",
                    tag: "BATHROOM",
                    durationMinutes: 15,
                    isCompleted: false,
                    dueDate: daysFromNow(27),
                    lastCompletedAt: relativeDate(daysAgo: 3, hour: 11, minute: 50),
                    recurrence: RecurrenceRule(count: 1, unit: .month)
                ),
                TaskItem(
                    id: deepCountersId,
                    title: "Deep clean counters",
                    tag: "KITCHEN",
                    durationMinutes: 25,
                    isCompleted: false,
                    dueDate: daysFromNow(28),
                    lastCompletedAt: relativeDate(daysAgo: 2, hour: 14, minute: 12),
                    recurrence: RecurrenceRule(count: 1, unit: .month)
                ),
                TaskItem(
                    id: prepKombucha1Id,
                    title: "Prep kombucha 1/2",
                    tag: "KITCHEN",
                    durationMinutes: 20,
                    isCompleted: false,
                    dueDate: daysFromNow(30),
                    lastCompletedAt: relativeDate(daysAgo: 0, hour: 9, minute: 20),
                    recurrence: RecurrenceRule(count: 1, unit: .month)
                ),
                TaskItem(
                    id: deepVacuumId,
                    title: "Deep vacuuming",
                    tag: "GENERAL",
                    durationMinutes: 30,
                    isCompleted: false,
                    dueDate: daysFromNow(40),
                    lastCompletedAt: nil,
                    recurrence: RecurrenceRule(count: 3, unit: .month)
                ),
                TaskItem(
                    id: bathroomTrashId,
                    title: "Bathroom trash",
                    tag: "BATHROOM",
                    durationMinutes: 5,
                    isCompleted: false,
                    dueDate: daysFromNow(56),
                    lastCompletedAt: relativeDate(daysAgo: 4, hour: 20, minute: 5),
                    recurrence: RecurrenceRule(count: 2, unit: .month)
                )
            ],
            historyRecords: [
                // Oct 15 (0 days ago)
                HistoryRecord(taskId: prepKombucha1Id, title: "Prep kombucha 1/2", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 0, hour: 9, minute: 20)),

                // Oct 14 (1 day ago)
                HistoryRecord(taskId: meditationId, title: "13m meditation", tag: "SELF", completedAt: relativeDate(daysAgo: 1, hour: 18, minute: 31)),
                HistoryRecord(taskId: dustSurfacesId, title: "Dust surfaces", tag: "GENERAL", completedAt: relativeDate(daysAgo: 1, hour: 16, minute: 53)),
                HistoryRecord(taskId: waterFlowersId, title: "Water flowers", tag: "GENERAL", completedAt: relativeDate(daysAgo: 1, hour: 16, minute: 37)),
                HistoryRecord(taskId: stretchId, title: "Stretch (shoulders, inner thigh, hip flexor, squat)", tag: "SELF", completedAt: relativeDate(daysAgo: 1, hour: 15, minute: 57)),

                // Oct 13 (2 days ago)
                HistoryRecord(taskId: deepCountersId, title: "Deep clean counters", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 2, hour: 14, minute: 12)),
                HistoryRecord(taskId: wipeCountersId, title: "Wipe counters", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 2, hour: 14, minute: 12)),
                HistoryRecord(taskId: meditationId, title: "13m meditation", tag: "SELF", completedAt: relativeDate(daysAgo: 2, hour: 12, minute: 6)),
                HistoryRecord(taskId: stretchId, title: "Stretch (shoulders, inner thigh, hip flexor, squat)", tag: "SELF", completedAt: relativeDate(daysAgo: 2, hour: 12, minute: 6)),

                // Oct 12 (3 days ago)
                HistoryRecord(taskId: meditationId, title: "13m meditation", tag: "SELF", completedAt: relativeDate(daysAgo: 3, hour: 13, minute: 52)),
                HistoryRecord(taskId: stretchId, title: "Stretch (shoulders, inner thigh, hip flexor, squat)", tag: "SELF", completedAt: relativeDate(daysAgo: 3, hour: 13, minute: 38)),
                HistoryRecord(taskId: showerWall2Id, title: "Shower wall 2/2", tag: "BATHROOM", completedAt: relativeDate(daysAgo: 3, hour: 11, minute: 50)),

                // Oct 11 (4 days ago)
                HistoryRecord(taskId: tidyFridgeId, title: "Tidy up fridge", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 4, hour: 20, minute: 10)),
                HistoryRecord(taskId: bathroomTrashId, title: "Bathroom trash", tag: "BATHROOM", completedAt: relativeDate(daysAgo: 4, hour: 20, minute: 5)),
                HistoryRecord(taskId: cleanSinkId, title: "Clean sink", tag: "BATHROOM", completedAt: relativeDate(daysAgo: 4, hour: 20, minute: 1)),
                HistoryRecord(taskId: tidyRearrangeId, title: "Tidy up / rearrange stuff", tag: "GENERAL", completedAt: relativeDate(daysAgo: 4, hour: 19, minute: 41)),
                HistoryRecord(taskId: meditationId, title: "13m meditation", tag: "SELF", completedAt: relativeDate(daysAgo: 4, hour: 17, minute: 36)),
                HistoryRecord(taskId: stretchId, title: "Stretch (shoulders, inner thigh, hip flexor, squat)", tag: "SELF", completedAt: relativeDate(daysAgo: 4, hour: 17, minute: 18)),
                HistoryRecord(taskId: showerWall1Id, title: "Shower wall 1/2", tag: "BATHROOM", completedAt: relativeDate(daysAgo: 4, hour: 17, minute: 8)),

                // Oct 10 (5 days ago)
                HistoryRecord(taskId: meditationId, title: "13m meditation", tag: "SELF", completedAt: relativeDate(daysAgo: 5, hour: 17, minute: 38)),
                HistoryRecord(taskId: basicVacuumId, title: "Basic vacùùming", tag: "GENERAL", completedAt: relativeDate(daysAgo: 5, hour: 16, minute: 58)),
                HistoryRecord(taskId: waterFlowersId, title: "Water flowers", tag: "GENERAL", completedAt: relativeDate(daysAgo: 5, hour: 13, minute: 27)),
                HistoryRecord(taskId: tidyBoxesId, title: "Tidy up boxes", tag: "GENERAL", completedAt: relativeDate(daysAgo: 5, hour: 13, minute: 25)),
                HistoryRecord(taskId: stretchId, title: "Stretch (shoulders, inner thigh, hip flexor, squat)", tag: "SELF", completedAt: relativeDate(daysAgo: 5, hour: 13, minute: 18)),
                HistoryRecord(taskId: cleanToiletId, title: "Clean toilet", tag: "BATHROOM", completedAt: relativeDate(daysAgo: 5, hour: 13, minute: 7)),
                HistoryRecord(taskId: cleanBathtubId, title: "Clean bathtub", tag: "BATHROOM", completedAt: relativeDate(daysAgo: 5, hour: 13, minute: 7))
            ],
            customTags: [
                "KITCHEN", "BATHROOM", "GENERAL", "SELF"
            ],
            focusOverline: "SCHEDULED OPERATIONS",
            focusTitle: "Main Tasks",
            focusSubtitle: "Targeted deep maintenance · Non-routine upkeep",
            heroTools: "TOOLS: Sanitizer, microfiber kit, squeegee, scrubber.",
            baselineTitle: "Daily Baseline",
            baselineRule: "RULE: Complete daily routines before noon."
        )
    }()
}