import SwiftUI

public struct BaselineResetView: View {
    public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CONTINUOUS BASELINE")
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

            Text(store.state.baselineSubtitle)
                .font(.system(size: 13 * s, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 14 * s)

            VStack(spacing: 10 * s) {
                ForEach(store.state.baselineTasks) { item in
                    CheckboxRow(
                        title: item.title,
                        tag: item.tag,
                        isCompleted: item.isCompleted,
                        onToggle: { store.toggleBaselineTask(id: item.id) }
                    )
                }
            }

            Spacer(minLength: 10 * s)

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
        .background(AppConfig.Colors.blockSlate)
    }
}