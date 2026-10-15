import Foundation
@testable import ChoreDashboard

/// In-memory persistence double for testing without filesystem access.
public actor InMemoryPersistenceClient: PersistenceClient {
    public var storedState: DashboardState?
    public var saveCount: Int = 0

    public init(initialState: DashboardState? = nil) {
        self.storedState = initialState
    }

    public func save(_ state: DashboardState) async throws {
        saveCount += 1
        storedState = state
    }

    public func load() async throws -> DashboardState? {
        storedState
    }

    public func evaluateExternalChange() async throws -> DashboardState? {
        nil
    }
}