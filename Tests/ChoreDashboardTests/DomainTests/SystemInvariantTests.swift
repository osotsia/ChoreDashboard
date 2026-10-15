import Testing
import Foundation
@testable import ChoreDashboard

@Suite("System-Wide Invariants & Serialization Tests")
struct SystemInvariantTests {

    private func makeCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func makeClock() -> TestClock {
        let cal = makeCalendar()
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 1
        comps.hour = 12
        return TestClock(now: cal.date(from: comps)!, calendar: cal)
    }

    @Test("Rollover is idempotent when called repeatedly on the same calendar day")
    func testRolloverIdempotency() {
        var clock = makeClock()
        let task = TaskItem(
            title: "Task",
            tag: "TEST",
            isCompleted: true,
            lastCompletedAt: clock.now,
            recurrence: RecurrenceRule(count: 1, unit: .week)
        )
        var state = DashboardState(tasks: [task])

        clock.advance(byDays: 1)

        let mutatedFirst = ChoreEngine.rollover(state: &state, clock: clock)
        #expect(mutatedFirst == true)
        let snapshotAfterFirst = state.tasks

        let mutatedSecond = ChoreEngine.rollover(state: &state, clock: clock)
        #expect(mutatedSecond == false)
        #expect(state.tasks == snapshotAfterFirst)

        let mutatedThird = ChoreEngine.rollover(state: &state, clock: clock)
        #expect(mutatedThird == false)
        #expect(state.tasks == snapshotAfterFirst)
    }

    @Test("Tag deletion eliminates all orphaned references throughout tasks and history")
    func testTagOrphanPrevention() {
        let taskA = TaskItem(title: "T1", tag: "TARGET")
        let taskB = TaskItem(title: "T2", tag: "KEEP")
        let record = HistoryRecord(title: "H1", tag: "TARGET")

        var state = DashboardState(
            tasks: [taskA, taskB],
            historyRecords: [record],
            customTags: ["TARGET", "KEEP"]
        )

        ChoreEngine.deleteTag(state: &state, tag: "TARGET")

        #expect(!state.customTags.contains("TARGET"))
        #expect(state.tasks.allSatisfy { $0.tag != "TARGET" })
        #expect(state.historyRecords.allSatisfy { $0.tag != "TARGET" })
    }

    @Test("Available tags projection continuously covers all tags held by tasks, records, and custom registry")
    func testTagRegistryCoverageInvariant() {
        let task = TaskItem(title: "Task", tag: "SPECIAL_A")
        let record = HistoryRecord(title: "History", tag: "SPECIAL_B")
        var state = DashboardState(tasks: [task], historyRecords: [record], customTags: ["CUSTOM_C"])

        var available = ChoreProjections.availableTags(for: state)
        #expect(available.contains("SPECIAL_A"))
        #expect(available.contains("SPECIAL_B"))
        #expect(available.contains("CUSTOM_C"))

        ChoreEngine.deleteTag(state: &state, tag: "SPECIAL_A")
        available = ChoreProjections.availableTags(for: state)
        #expect(!available.contains("SPECIAL_A"))
        #expect(available.contains("GENERAL"))
    }

    @Test("Task deletion preserves historical records to maintain velocity metrics integrity")
    func testHistoryRetentionOnTaskDeletion() {
        let taskId = UUID()
        let task = TaskItem(id: taskId, title: "Retired Task", tag: "GENERAL")
        let record = HistoryRecord(taskId: taskId, title: "Retired Task", tag: "GENERAL")
        var state = DashboardState(tasks: [task], historyRecords: [record])

        ChoreEngine.deleteTask(state: &state, id: taskId)

        #expect(state.tasks.isEmpty)
        #expect(state.historyRecords.count == 1)
        #expect(state.historyRecords[0].taskId == taskId)
    }

    @Test("JSON serialization roundtrip preserves exact values across all properties")
    func testStateSerializationRoundtrip() throws {
        let original = PreviewData.defaultState

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DashboardState.self, from: data)

        #expect(decoded == original)
    }

    @Test("JSON decoding fails cleanly when supplied with corrupted or invalid payloads")
    func testCorruptedJsonDecodingFailure() {
        let invalidJson = "{ \"schemaVersion\": \"not-a-number\" }".data(using: .utf8)!
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(DashboardState.self, from: invalidJson)
        }
    }

    @Test("Deserialization from raw JSON enforces clamping and uppercase sanitization invariants")
    func testDeserializationEnforcesClampingAndSanitizationInvariants() throws {
        let rawJson = """
        {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "title": "Unsanitized Task",
            "tag": "  lowercase_kitchen  ",
            "durationMinutes": -45,
            "isCompleted": false,
            "dueDate": "2026-05-01T12:00:00Z",
            "recurrence": {
                "count": -5,
                "unit": "Day"
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let task = try decoder.decode(TaskItem.self, from: rawJson)

        #expect(task.durationMinutes == 1)
        #expect(task.tag == "LOWERCASE_KITCHEN")
        #expect(task.recurrence?.count == 1)
        #expect(task.recurrence?.intervalDays == 1)
    }

    @Test("Schema version property roundtrips cleanly across encoding boundaries")
    func testSchemaVersionRoundtrip() throws {
        var state = DashboardState()
        state.schemaVersion = 3

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DashboardState.self, from: data)

        #expect(decoded.schemaVersion == 3)
    }
}