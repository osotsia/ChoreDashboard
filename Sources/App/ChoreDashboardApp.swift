import SwiftUI
import AppKit

private final class AspectLockView: NSView {
    var ratio: CGSize = .zero

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = window, ratio.width > 0, ratio.height > 0 else { return }
        window.aspectRatio = NSSize(width: ratio.width, height: ratio.height)
        window.minSize = NSSize(width: ratio.width, height: ratio.height)
    }
}

private struct WindowAspectLock: NSViewRepresentable {
    let ratio: CGSize

    func makeNSView(context: Context) -> AspectLockView {
        let view = AspectLockView()
        view.ratio = ratio
        return view
    }

    func updateNSView(_ nsView: AspectLockView, context: Context) {
        nsView.ratio = ratio
    }
}

@main
struct ChoreDashboardApp: App {
    @State private var store = DashboardStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Chore Dashboard", id: "dashboard") {
            DashboardView(store: store)
                .background(WindowAspectLock(ratio: AppConfig.aspectRatio))
                .frame(
                    minWidth: AppConfig.baseWidth,
                    minHeight: AppConfig.baseHeight
                )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)

        MenuBarExtra("Chore Dashboard", systemImage: "checklist") {
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
        }
    }
}