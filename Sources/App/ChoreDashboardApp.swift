import SwiftUI
import AppKit

@main
struct ChoreDashboardApp: App {
    @State private var store = DashboardStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Chore Dashboard", id: "dashboard") {
            DashboardView(store: store)
                .frame(
                    minWidth: AppConfig.baseWidth,
                    minHeight: AppConfig.baseHeight
                )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            Button("Show Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "dashboard")
            }
            Divider()
            Text("Daily Baseline: \(store.baselineTasks.filter { !$0.isCompleted }.count) Left")
            Text("Scheduled Focus: \(store.focusQueue.filter { !$0.isCompleted }.count) Active Jobs")
            Divider()
            Button("Reset Daily Baseline") {
                store.resetDailyBaseline()
            }
            Button("Reload from Disk") {
                store.reloadFromDisk()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(nsImage: MenuBarIcon.template)
        }
    }
}