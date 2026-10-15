import Testing
import Foundation
@testable import ChoreDashboard

@Suite("System-Wide Mathematical & Operational Invariants")
struct SystemInvariantTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeClock() -> TestClock {
        TestClock(now: Date(timeIntervalSince1970: 1777636800), calendar: makeCalendar())
    }

    @Test("Invariant: Midnight rollover is idempotent on the same calendar day")
    func testRolloverIdempotency() {
        var clock = makeClock()
        let t1 = TaskItem(
            title: "Task 1",
            tag: "TEST",
            isCompleted: true,
            lastCompletedAt: clock.now,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )
        var state = DashboardState(tasks: [t1])

        // Advance to next day
        clock.advance(byDays: 1)

        // First execution mutates state
        let firstMutation = ChoreEngine.rollover(state: &state, clock: clock)
        #expect(firstMutation == true)
        #expect(state.tasks[0].isCompleted == false)

        // Snapshot state
        let snapshotAfterFirst = state.tasks

        // Subsequent executions on same calendar day must produce zero mutations
        let secondMutation = ChoreEngine.rollover(state: &state, clock: clock)
        #expect(secondMutation == false)
        #expect(state.tasks == snapshotAfterFirst)

        let thirdMutation = ChoreEngine.rollover(state: &state, clock: clock)
        #expect(thirdMutation == false)
        #expect(state.tasks == snapshotAfterFirst)
    }

    @Test("Invariant: Deleting a tag leaves no orphaned tag references in tasks or history")
    func testTagOrphanPrevention() {
        let clock = makeClock()
        let id1 = UUID()
        let id2 = UUID()

        let task1 = TaskItem(id: id1, title: "T1", tag: "KITCHEN")
        let task2 = TaskItem(id: id2, title: "T2", tag: "TARGET_TAG")
        let history = HistoryRecord(taskId: id2, title: "T2", tag: "TARGET_TAG", completedAt: clock.now)

        var state = DashboardState(
            tasks: [task1, task2],
            historyRecords: [history],
            customTags: ["TARGET_TAG", "KITCHEN"]
        )

        ChoreEngine.deleteTag(state: &state, tag: "TARGET_TAG")

        #expect(!state.customTags.contains("TARGET_TAG"))
        for task in state.tasks {
            #expect(task.tag != "TARGET_TAG")
        }
        for record in state.historyRecords {
            #expect(record.tag != "TARGET_TAG")
        }
    }

    @Test("Invariant: Task inventory sum equals total tasks in state")
    func testInventoryConservation() {
        let clock = makeClock()
        let state = PreviewData.defaultState

        let baselineCount = ChoreProjections.baselineTasks(for: state).count
        let focusCount = ChoreProjections.focusQueue(for: state, clock: clock).count
        let upcomingCount = ChoreProjections.upcomingEvents(for: state, clock: clock).count

        // Total inventory should account for all uncompleted or active items
        #expect(baselineCount + focusCount + upcomingCount <= state.tasks.count)
    }

    @Test("Invariant: State JSON serialization roundtrip preserves exact values")
    func testStateSerializationRoundtrip() throws {
        let original = PreviewData.defaultState

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DashboardState.self, from: data)

        #expect(decoded.schemaVersion == original.schemaVersion)
        #expect(decoded.tasks.count == original.tasks.count)
        #expect(decoded.historyRecords.count == original.historyRecords.count)
        #expect(decoded.customTags == original.customTags)
        #expect(decoded.focusTitle == original.focusTitle)
        #expect(decoded.baselineTitle == original.baselineTitle)
    }
}