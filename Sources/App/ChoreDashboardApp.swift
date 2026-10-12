import SwiftUI
import AppKit

// MARK: - Native Window Aspect-Ratio Lock
private struct WindowAspectLock: NSViewRepresentable {
    let ratio: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.aspectRatio = NSSize(width: ratio.width, height: ratio.height)
                window.minSize = NSSize(width: ratio.width, height: ratio.height)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

@main
struct ChoreDashboardApp: App {
    @State private var store = DashboardStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // --- 1. Main Dashboard Window ---
        WindowGroup(id: "dashboard") {
            DashboardView(store: store)
                .background(WindowAspectLock(ratio: AppConfig.aspectRatio))
                .frame(
                    minWidth: AppConfig.baseWidth,
                    minHeight: AppConfig.baseHeight
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
            Text("Daily Baseline: \(store.state.baselineTasks.filter { !$0.isCompleted }.count) Left")
            Text("Scheduled Focus: \(store.state.focusJobs.count) Active Jobs")
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
        }
    }
}