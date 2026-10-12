import SwiftUI

@main
struct ChoreDashboardApp: App {
    @State private var store = DashboardStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // --- 1. Main Dashboard Window ---
        WindowGroup(id: "dashboard") {
            DashboardView(store: store)
                .frame(
                    minWidth: AppConfig.windowWidth,
                    idealWidth: AppConfig.windowWidth,
                    maxWidth: AppConfig.windowWidth,
                    minHeight: AppConfig.windowHeight,
                    idealHeight: AppConfig.windowHeight,
                    maxHeight: AppConfig.windowHeight
                )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // --- 2. Persistent macOS Menu Bar Item ---
        MenuBarExtra("Chore Dashboard", systemImage: "checklist") {
            Button("Show Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "dashboard")
            }
            Divider()
            Text("Today: \(store.state.heroTasks.filter { !$0.isCompleted }.count) Focus / \(store.state.baselineTasks.filter { !$0.isCompleted }.count) Baseline Left")
            Divider()
            Button("Reset Daily Baseline") {
                store.resetDailyBaseline()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}