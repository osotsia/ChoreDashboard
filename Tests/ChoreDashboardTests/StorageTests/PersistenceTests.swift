import Testing
import Foundation
@testable import ChoreDashboard

private actor ChangeRecorder {
    var wasTriggered = false
    func markTriggered() { wasTriggered = true }
    func isTriggered() -> Bool { wasTriggered }
}

private actor ConcurrentErrorCollector {
    var errors: [String] = []
    func append(_ description: String) { errors.append(description) }
    func all() -> [String] { errors }
}

@Suite("FilePersistenceClient Disk I/O & Recovery Tests")
struct PersistenceTests {

    private func makeTemporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("test-dashboard-\(UUID().uuidString).json")
    }

    private func makeTemporaryDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-dir-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Roundtrip atomic persistence writes and loads complete state")
    func testSaveAndLoadRoundtrip() async throws {
        let tempURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = FilePersistenceClient(storageURL: tempURL)
        let original = PreviewData.defaultState

        try await client.save(original)
        let loaded = try await client.load()

        #expect(loaded != nil)
        #expect(loaded == original)
    }

    @Test("evaluateExternalChange returns nil when file is unmodified and state when changed")
    func testExternalChangeEvaluation() async throws {
        let tempURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = FilePersistenceClient(storageURL: tempURL)
        var state = PreviewData.defaultState
        try await client.save(state)

        let noChange = try await client.evaluateExternalChange()
        #expect(noChange == nil)

        state.tasks.append(TaskItem(title: "External Insertion", tag: "TEST"))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: tempURL, options: .atomic)

        let updated = try await client.evaluateExternalChange()
        #expect(updated != nil)
        #expect(updated?.tasks.count == state.tasks.count)
    }

    @Test("loadInitialBlocking recovers nil without trapping on non-existent or corrupted files")
    func testBlockingLoaderFailureModes() throws {
        let nonExistentURL = makeTemporaryFileURL()
        #expect(FilePersistenceClient.loadInitialBlocking(from: nonExistentURL) == nil)

        let corruptURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: corruptURL) }
        try "corrupted json payload".write(to: corruptURL, atomically: true, encoding: .utf8)

        #expect(FilePersistenceClient.loadInitialBlocking(from: corruptURL) == nil)
    }

    @Test("DirectoryWatcher initializes, triggers callback on atomic disk write, and tears down cleanly")
    func testDirectoryWatcherEventDispatch() async throws {
        let dir = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let recorder = ChangeRecorder()
        var watcher: DirectoryWatcher? = DirectoryWatcher(directoryURL: dir) {
            Task { await recorder.markTriggered() }
        }
        #expect(watcher != nil)

        let targetFile = dir.appendingPathComponent("probe.txt")
        try "atomic replacement event".write(to: targetFile, atomically: true, encoding: .utf8)

        var detected = false
        let deadline = ContinuousClock.now + .seconds(3)
        while ContinuousClock.now < deadline {
            if await recorder.isTriggered() {
                detected = true
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(detected == true)

        watcher = nil
        #expect(watcher == nil)
    }

    // MARK: - Fault Tolerance & Concurrency Limits

    @Test("FilePersistenceClient throws when attempting to persist to unwritable directory")
    func testSaveToUnwritablePathFails() async {
        let unwritableURL = URL(fileURLWithPath: "/dev/null/impossible_dir/state.json")
        let client = FilePersistenceClient(storageURL: unwritableURL)

        await #expect(throws: Error.self) {
            try await client.save(PreviewData.defaultState)
        }
    }

    @Test("evaluateExternalChange throws when file contents become malformed externally")
    func testExternalChangeWithCorruptedPayloadFails() async throws {
        let tempURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = FilePersistenceClient(storageURL: tempURL)
        try await client.save(PreviewData.defaultState)

        try "corrupt binary stream {".write(to: tempURL, atomically: true, encoding: .utf8)

        await #expect(throws: DecodingError.self) {
            _ = try await client.evaluateExternalChange()
        }
    }

    @Test("Rapid concurrent atomic writes do not corrupt storage state")
    func testRapidConcurrentSaves() async throws {
        let tempURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = FilePersistenceClient(storageURL: tempURL)
        let errorCollector = ConcurrentErrorCollector()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<15 {
                group.addTask {
                    var state = PreviewData.defaultState
                    state.focusTitle = "Iteration \(i)"
                    do {
                        try await client.save(state)
                    } catch {
                        await errorCollector.append("Save \(i) failed: \(error)")
                    }
                }
            }
        }

        let recordedErrors = await errorCollector.all()
        #expect(recordedErrors.isEmpty)

        let loaded = try await client.load()
        #expect(loaded != nil)
        #expect(loaded?.schemaVersion == 2)
        #expect(loaded?.focusTitle.starts(with: "Iteration ") == true)

        let fileData = try Data(contentsOf: tempURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let directDecoded = try decoder.decode(DashboardState.self, from: fileData)
        #expect(directDecoded == loaded)
    }

    @Test("Store reloads cleanly when an external process modifies the state file directly on disk")
    @MainActor
    func testStoreReloadWithFilePersistenceClientIntegration() async throws {
        let tempURL = makeTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let client = FilePersistenceClient(storageURL: tempURL)
        var initialState = PreviewData.defaultState
        initialState.focusTitle = "Disk Base"
        try await client.save(initialState)

        let store = DashboardStore(
            initialState: initialState,
            persistenceClient: client,
            clock: SystemClock(),
            enableSystemIntegration: false
        )

        var externalState = initialState
        externalState.focusTitle = "Disk External Update"
        externalState.tasks.append(TaskItem(title: "Externally Injected Task", tag: "TEST"))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let externalData = try encoder.encode(externalState)
        try externalData.write(to: tempURL, options: .atomic)

        await store.reloadFromDisk().value

        #expect(store.state.focusTitle == "Disk External Update")
        #expect(store.state.tasks.contains(where: { $0.title == "Externally Injected Task" }))
    }
}