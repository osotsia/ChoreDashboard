import SwiftUI

public struct PrimaryFocusView: View {
    public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    public var body: some View {
        let threeColumns = [
            GridItem(.flexible(), spacing: 10 * s),
            GridItem(.flexible(), spacing: 10 * s),
            GridItem(.flexible(), spacing: 10 * s)
        ]

        VStack(alignment: .leading, spacing: 0) {
            // Header: Offset with windowChromeTopInset to avoid traffic light overlap
            HStack {
                Text(store.state.focusOverline.uppercased())
                    .font(.system(size: 11 * s, weight: .bold))
                    .tracking(2.0 * s)

                Spacer()

                HStack(spacing: 4 * s) {
                    Text("TODAY")
                        .font(.system(size: 13 * s, weight: .bold))
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12 * s))
                }
            }
            .padding(.top, AppConfig.windowChromeTopInset * s)
            .padding(.bottom, 6 * s)

            Text(store.state.focusTitle)
                .font(.system(size: 24 * s, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 4 * s)

            Text(store.state.focusSubtitle)
                .font(.system(size: 13 * s, weight: .regular))
                .foregroundColor(Color.white.opacity(0.8))
                .padding(.bottom, 14 * s)

            // Dynamic grid populated from projected focusQueue
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: threeColumns, spacing: 10 * s) {
                    ForEach(store.focusQueue) { task in
                        let isEditingThis = store.taskDraft?.id == task.id
                        FocusJobTile(
                            task: task,
                            isHighlighted: isEditingThis,
                            onToggle: {
                                store.toggleTask(id: task.id)
                            },
                            onEdit: {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    store.startEditing(task: task)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 2 * s)
            }

            Spacer(minLength: 8 * s)

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1 * s)
                .padding(.bottom, 6 * s)

            Text(store.state.heroTools)
                .font(.system(size: 11 * s, weight: .bold))
                .foregroundColor(Color.white.opacity(0.6))
        }
        .padding(.horizontal, 24 * s)
        .padding(.bottom, 24 * s)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppConfig.Colors.blockBlack)
    }
}