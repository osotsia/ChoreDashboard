import SwiftUI

public struct BaselineResetView: View {
    public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    private var taskList: some View {
        VStack(spacing: 8 * s) {
            ForEach(store.baselineTasks) { task in
                let isEditingThis = store.taskDraft?.id == task.id
                CheckboxRow(
                    title: task.title,
                    tag: task.tag,
                    isCompleted: task.isCompleted,
                    isHighlighted: isEditingThis,
                    onToggle: { store.toggleTask(id: task.id) },
                    onEdit: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            store.startEditing(task: task)
                        }
                    }
                )
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ROUTINE OPERATIONS")
                    .font(.system(size: 11 * s, weight: .bold))
                    .tracking(2.0 * s)
                Spacer()
                Button(action: { store.resetDailyBaseline() }) {
                    HStack(spacing: 4 * s) {
                        Text("RESET")
                            .font(.system(size: 13 * s, weight: .bold))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12 * s, weight: .bold))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10 * s)

            Text(store.state.baselineTitle)
                .font(.system(size: 24 * s, weight: .bold))
                .padding(.bottom, 4 * s)

            Text("Est: \(store.baselineTotalMinutes) min · 24-hour cycle")
                .font(.system(size: 13 * s, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 14 * s)

            ViewThatFits(in: .vertical) {
                taskList
                ScrollView(.vertical, showsIndicators: false) {
                    taskList
                }
            }
            .padding(.bottom, 14 * s)

            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1 * s)
                .padding(.bottom, 6 * s)

            Text(store.state.baselineRule)
                .font(.system(size: 11 * s, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(28 * s)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppConfig.Colors.blockSlate)
    }
}