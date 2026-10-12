import SwiftUI

public struct PrimaryFocusView: View {
    public var store: DashboardStore

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                SectionBadge(text: "ZONE 02: BATHROOM")
                Spacer()
                HStack(spacing: 4) {
                    Text("TODAY")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "bolt.fill")
                }
            }
            .padding(.bottom, 16)

            // Titles
            Text(store.state.heroTitle)
                .font(.system(size: 34, weight: .bold))
                .lineSpacing(4)
                .padding(.bottom, 8)

            Text(store.state.heroSubtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 20)

            // Tasks
            VStack(spacing: 12) {
                ForEach(store.state.heroTasks) { item in
                    CheckboxRow(
                        title: item.title,
                        tag: item.tag,
                        isCompleted: item.isCompleted,
                        onToggle: { store.toggleTask(id: item.id) }
                    )
                }
            }

            Spacer(minLength: 16)

            // Divider & Tools Footer
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
                .padding(.bottom, 8)

            Text(store.state.heroTools)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(32)
        .foregroundColor(.white)
        .background(AppConfig.Colors.blockBlack)
    }
}