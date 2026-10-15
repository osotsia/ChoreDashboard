import Foundation

/// Asynchronous persistence contract for storing and reloading DashboardState.
public protocol PersistenceClient: Sendable {
    func save(_ state: DashboardState) async throws
    func load() async throws -> DashboardState?
    func evaluateExternalChange() async throws -> DashboardState?
}