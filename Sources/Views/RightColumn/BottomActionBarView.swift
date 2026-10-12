import SwiftUI

public struct BottomActionBarView: View {
    public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    // Composite tally: Total active jobs (top-left) + unchecked daily tasks (bottom-left)
    private var remainingCount: Int {
        let focusJobsCount = store.state.focusJobs.count
        let uncheckedBaselineCount = store.state.baselineTasks.filter { !$0.isCompleted }.count
        return focusJobsCount + uncheckedBaselineCount
    }

    public var body: some View {
        HStack(spacing: 8 * s) {
            // Button 1: Remaining (Composite Countdown)
            Button(action: {
                // Focus / inspect operational status
            }) {
                VStack(spacing: 3 * s) {
                    Text("\(remainingCount)")
                        .font(.system(size: 16 * s, weight: .black, design: .monospaced))
                        .foregroundColor(.black)

                    Text("REMAINING")
                        .font(.system(size: 9 * s, weight: .bold))
                        .tracking(1.2 * s)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50 * s)
                .background(Color.white)
                .border(Color.black, width: 1.5 * s)
                .contentShape(Rectangle())
            }
            .buttonStyle(TactileButtonStyle())

            // Button 2: New Task (+)
            Button(action: {
                // Hook for task creation workflow
            }) {
                VStack(spacing: 3 * s) {
                    Image(systemName: "plus")
                        .font(.system(size: 15 * s, weight: .bold))
                        .foregroundColor(.black)

                    Text("NEW TASK")
                        .font(.system(size: 9 * s, weight: .bold))
                        .tracking(1.2 * s)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50 * s)
                .background(Color.white)
                .border(Color.black, width: 1.5 * s)
                .contentShape(Rectangle())
            }
            .buttonStyle(TactileButtonStyle())

            // Button 3: Backlog (Tray Icon)
            Button(action: {
                // Hook for opening backlog repository
            }) {
                VStack(spacing: 3 * s) {
                    Image(systemName: "tray.full")
                        .font(.system(size: 14 * s, weight: .bold))
                        .foregroundColor(.black)

                    Text("BACKLOG")
                        .font(.system(size: 9 * s, weight: .bold))
                        .tracking(1.2 * s)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50 * s)
                .background(Color.white)
                .border(Color.black, width: 1.5 * s)
                .contentShape(Rectangle())
            }
            .buttonStyle(TactileButtonStyle())
        }
    }
}

// MARK: - Tactical Button Style (Press Feedback)
private struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}