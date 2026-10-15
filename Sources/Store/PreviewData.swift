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

    private static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
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
            schemaVersion: 2,
            tasks: [
                // 1. Daily Baseline Items (Cadence: 1 Day)
                TaskItem(id: stretchId, title: "Stretch", tag: "BODY", durationMinutes: 10, isCompleted: false, dueDate: Date(), recurrence: RecurrenceRule(count: 1, unit: .day)),
                TaskItem(id: meditateId, title: "13-minute meditation", tag: "MIND", durationMinutes: 13, isCompleted: false, dueDate: Date(), recurrence: RecurrenceRule(count: 1, unit: .day)),
                TaskItem(id: dishesId, title: "Wash dishes", tag: "KITCHEN", durationMinutes: 8, isCompleted: false, dueDate: Date(), recurrence: RecurrenceRule(count: 1, unit: .day)),

                // 2. Active Focus Items (Due Today / Overdue)
                TaskItem(id: kitchenId, title: "Deep clean countertops", tag: "KITCHEN", durationMinutes: 15, isCompleted: false, dueDate: Date(), recurrence: RecurrenceRule(count: 1, unit: .week)),
                TaskItem(id: floorsId, title: "Scrub floors & crevices", tag: "FLOORS", durationMinutes: 20, isCompleted: false, dueDate: daysFromNow(-1), recurrence: RecurrenceRule(count: 1, unit: .week)),
                TaskItem(id: fridgeId, title: "Deep clean refrigerator", tag: "APPLIANCE", durationMinutes: 30, isCompleted: false, dueDate: Date(), recurrence: RecurrenceRule(count: 1, unit: .month)),
                TaskItem(id: bottlesId, title: "Wash kombucha bottles", tag: "PANTRY", durationMinutes: 15, isCompleted: false, dueDate: Date(), recurrence: RecurrenceRule(count: 2, unit: .week)),
                TaskItem(id: brewingId, title: "Prep kombucha batch", tag: "BREWING", durationMinutes: 25, isCompleted: false, dueDate: Date(), recurrence: RecurrenceRule(count: 2, unit: .week)),
                TaskItem(id: sinkId, title: "Sanitize sink & drain", tag: "PLUMBING", durationMinutes: 10, isCompleted: false, dueDate: Date(), recurrence: RecurrenceRule(count: 1, unit: .week)),

                // 3. Upcoming Scheduled Horizon Tasks
                TaskItem(title: "Water flowers", tag: "PLANTS", durationMinutes: 10, dueDate: daysFromNow(2), recurrence: RecurrenceRule(count: 4, unit: .day)),
                TaskItem(title: "Kitchen trash", tag: "WASTE", durationMinutes: 5, dueDate: daysFromNow(3), recurrence: RecurrenceRule(count: 1, unit: .week)),
                TaskItem(title: "Replace water filter", tag: "WATER", durationMinutes: 5, dueDate: daysFromNow(7), recurrence: RecurrenceRule(count: 1, unit: .week)),
                TaskItem(title: "Basic vacuuming", tag: "FLOORS", durationMinutes: 15, dueDate: daysFromNow(12), recurrence: RecurrenceRule(count: 2, unit: .week)),
                TaskItem(title: "Wipe interior windows", tag: "WINDOWS", durationMinutes: 25, dueDate: daysFromNow(21), recurrence: RecurrenceRule(count: 3, unit: .week)),
                TaskItem(title: "Tidy up boxes", tag: "STORAGE", durationMinutes: 20, dueDate: daysFromNow(28), recurrence: RecurrenceRule(count: 1, unit: .month)),
                TaskItem(title: "Clean bathtub", tag: "BATH", durationMinutes: 20, dueDate: daysFromNow(28), recurrence: RecurrenceRule(count: 1, unit: .month)),
                TaskItem(title: "Sanitize washer drum", tag: "APPLIANCE", durationMinutes: 15, dueDate: daysFromNow(60), recurrence: RecurrenceRule(count: 2, unit: .month))
            ],
            historyRecords: [
                HistoryRecord(taskId: kitchenId, title: "Deep clean countertops", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 0, hour: 9, minute: 15)),
                HistoryRecord(taskId: sinkId, title: "Sanitize sink & drain", tag: "PLUMBING", completedAt: relativeDate(daysAgo: 1, hour: 19, minute: 40)),
                HistoryRecord(taskId: dishesId, title: "Wash dishes", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 1, hour: 12, minute: 30)),
                HistoryRecord(taskId: floorsId, title: "Scrub floors & crevices", tag: "FLOORS", completedAt: relativeDate(daysAgo: 2, hour: 11, minute: 10)),
                HistoryRecord(taskId: kitchenId, title: "Deep clean countertops", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 3, hour: 16, minute: 20)),
                HistoryRecord(taskId: bottlesId, title: "Wash kombucha bottles", tag: "PANTRY", completedAt: relativeDate(daysAgo: 4, hour: 14, minute: 0)),
                HistoryRecord(taskId: sinkId, title: "Sanitize sink & drain", tag: "PLUMBING", completedAt: relativeDate(daysAgo: 5, hour: 20, minute: 15)),
                HistoryRecord(taskId: kitchenId, title: "Deep clean countertops", tag: "KITCHEN", completedAt: relativeDate(daysAgo: 6, hour: 8, minute: 45))
            ],
            customTags: [
                "KITCHEN", "FLOORS", "APPLIANCE", "PLUMBING", "PANTRY",
                "BREWING", "BODY", "MIND", "PLANTS", "WASTE", "STORAGE",
                "BATH", "WATER", "WINDOWS"
            ]
        )
    }()
}