import Testing
import Foundation
@testable import ChoreDashboard

@Suite("FilePersistenceClient Roundtrip & Change Detection")
struct PersistenceTests {

    private func makeTemporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("test-state-\(UUID().uuidString).json")
    }

    @Test("Roundtrip save and load preserves state equality")
    func testSaveAndLoadRoundtrip() async throws {
        let tempURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = FilePersistenceClient(storageURL: tempURL)
        let original = PreviewData.defaultState

        try await client.save(original)
        let loaded = try await client.load()

        #expect(loaded != nil)
        #expect(loaded?.schemaVersion == original.schemaVersion)
        #expect(loaded?.tasks.count == original.tasks.count)
        #expect(loaded?.historyRecords.count == original.historyRecords.count)
    }

    @Test("evaluateExternalChange returns nil when file has not been modified externally")
    func testChecksumShortCircuit() async throws {
        let tempURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = FilePersistenceClient(storageURL: tempURL)
        let original = PreviewData.defaultState

        try await client.save(original)
        let change = try await client.evaluateExternalChange()

        #expect(change == nil)
    }

    @Test("evaluateExternalChange detects and decodes external file modifications")
    func testExternalChangeDetection() async throws {
        let tempURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = FilePersistenceClient(storageURL: tempURL)
        var state = PreviewData.defaultState
        try await client.save(state)

        // Simulate external modification by writing directly to disk
        state.tasks.append(TaskItem(title: "External Task", tag: "TEST"))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: tempURL, options: .atomic)

        let reloaded = try await client.evaluateExternalChange()
        #expect(reloaded != nil)
        #expect(reloaded?.tasks.count == state.tasks.count)
    }
}