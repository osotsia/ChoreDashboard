import Foundation
@testable import ChoreDashboard

/// In-memory persistence double for testing without filesystem access.
public actor InMemoryPersistenceClient: PersistenceClient {
    public var storedState: DashboardState?
    public var saveCount: Int = 0
    public var stagedExternalChange: DashboardState?
    public var shouldThrowOnSave: Bool = false

    public init(initialState: DashboardState? = nil) {
        self.storedState = initialState
    }

    public func save(_ state: DashboardState) async throws {
        if shouldThrowOnSave {
            throw NSError(
                domain: "InMemoryPersistenceClientError",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Simulated write error."]
            )
        }
        saveCount += 1
        storedState = state
    }

    public func load() async throws -> DashboardState? {
        storedState
    }

    public func evaluateExternalChange() async throws -> DashboardState? {
        let change = stagedExternalChange
        stagedExternalChange = nil
        if let change = change {
            storedState = change
        }
        return change
    }

    public func stageExternalChange(_ state: DashboardState) {
        self.stagedExternalChange = state
    }

    public func setShouldThrowOnSave(_ shouldThrow: Bool) {
        self.shouldThrowOnSave = shouldThrow
    }
}