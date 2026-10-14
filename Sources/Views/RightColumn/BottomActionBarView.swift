// Sources/Views/RightColumn/BottomActionBarView.swift
import SwiftUI

public struct BottomActionBarView: View {
    public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    public var body: some View {
        HStack(spacing: 2 * s) {
            RibbonActionButton(
                icon: "plus.circle",
                label: "NEW",
                isSelected: false
            ) {
                // Hook for task creation workflow
            }

            RibbonActionButton(
                icon: "calendar",
                label: "UPCOMING",
                isSelected: store.activeRightTab == .upcoming
            ) {
                if store.activeRightTab != .upcoming {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        store.selectRightTab(.upcoming)
                    }
                }
            }

            RibbonActionButton(
                icon: "tray.full",
                label: "BACKLOG",
                isSelected: store.activeRightTab == .backlog
            ) {
                if store.activeRightTab != .backlog {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        store.selectRightTab(.backlog)
                    }
                }
            }

            RibbonActionButton(
                icon: "clock.arrow.circlepath",
                label: "HISTORY",
                isSelected: store.activeRightTab == .history
            ) {
                if store.activeRightTab != .history {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        store.selectRightTab(.history)
                    }
                }
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

private struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}