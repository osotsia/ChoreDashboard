import SwiftUI

public struct BottomActionBarView: View {
    public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    public var body: some View {
        HStack(spacing: 2 * s) {
            // 1. New (Stub)
            RibbonActionButton(
                icon: "plus.circle",
                label: "NEW",
                isSelected: false
            ) {
                // Hook for task creation workflow
            }

            // 2. Upcoming (Active view toggle)
            RibbonActionButton(
                icon: "calendar",
                label: "UPCOMING",
                isSelected: !store.isShowingBacklog
            ) {
                if store.isShowingBacklog {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        store.isShowingBacklog = false
                    }
                }
            }

            // 3. Backlog (Active view toggle)
            RibbonActionButton(
                icon: "tray.full",
                label: "BACKLOG",
                isSelected: store.isShowingBacklog
            ) {
                if !store.isShowingBacklog {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        store.isShowingBacklog = true
                    }
                }
            }

            // 4. History (Stub)
            RibbonActionButton(
                icon: "clock.arrow.circlepath",
                label: "HISTORY",
                isSelected: false
            ) {
                // Hook for operational history log
            }
        }
        .padding(4 * s)
        .background(Color.white)
        .overlay(
            Rectangle()
                .strokeBorder(AppConfig.Colors.lineGrey, lineWidth: 1 * s)
        )
    }
}

// MARK: - Ribbon Action Button Component
private struct RibbonActionButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.scaleFactor) private var s

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4 * s) {
                Image(systemName: icon)
                    .font(.system(size: 19 * s, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .black : AppConfig.Colors.subtextGrey)
                    .frame(height: 22 * s)

                Text(label)
                    .font(.system(size: 9 * s, weight: isSelected ? .bold : .semibold))
                    .tracking(1.1 * s)
                    .foregroundColor(isSelected ? .black : AppConfig.Colors.subtextGrey)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54 * s)
            .background(
                isSelected ? Color.black.opacity(0.06) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(TactileButtonStyle())
    }
}

// MARK: - Button Press Feedback
private struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}