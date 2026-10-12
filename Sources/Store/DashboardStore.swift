import SwiftUI
import Observation

@Observable
public final class DashboardStore {
    public var state: DashboardState

    public init() {
        self.state = Self.loadFromDisk() ?? PreviewData.defaultState
    }

    public func toggleTask(id: UUID) {
        if let idx = state.heroTasks.firstIndex(where: { $0.id == id }) {
            state.heroTasks[idx].isCompleted.toggle()
        } else if let idx = state.baselineTasks.firstIndex(where: { $0.id == id }) {
            state.baselineTasks[idx].isCompleted.toggle()
        }
        persist()
    }

    public func resetDailyBaseline() {
        for idx in state.baselineTasks.indices {
            state.baselineTasks[idx].isCompleted = false
        }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: AppConfig.storageURL, options: .atomic)
        } catch {
            print("Failed to persist JSON state: \(error)")
        }
    }

    private static func loadFromDisk() -> DashboardState? {
        guard FileManager.default.fileExists(atPath: AppConfig.storageURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: AppConfig.storageURL)
            return try JSONDecoder().decode(DashboardState.self, from: data)
        } catch {
            print("Failed to decode JSON state: \(error)")
            return nil
        }
    }
}