import SwiftUI

public struct BaselineResetView: View {
    public var store: DashboardStore

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionBadge(text: "CONTINUOUS BASELINE")
                Spacer()
                Button(action: { store.resetDailyBaseline() }) {
                    HStack(spacing: 4) {
                        Text("RESET")
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            Text("Zero-State Daily Reset")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 4)

            Text("Est: 15 min · Maintain apartment entropy floor")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 16)

            VStack(spacing: 10) {
                ForEach(store.state.baselineTasks) { item in
                    CheckboxRow(
                        title: item.title,
                        tag: item.tag,
                        isCompleted: item.isCompleted,
                        onToggle: { store.toggleTask(id: item.id) }
                    )
                }
            }

            Spacer(minLength: 12)

            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
                .padding(.bottom, 6)

            Text("RULE: Zero soiled dishes or wet trash past 22:00.")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(32)
        .foregroundColor(.white)
        .background(AppConfig.Colors.blockSlate)
    }
}