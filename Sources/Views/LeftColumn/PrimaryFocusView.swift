// Sources/Views/LeftColumn/PrimaryFocusView.swift
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
            // Header
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
            .padding(.bottom, 6 * s)

            // Primary Title
            Text(store.state.focusTitle)
                .font(.system(size: 24 * s, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 4 * s)

            // Subtitle
            Text(store.state.focusSubtitle)
                .font(.system(size: 13 * s, weight: .regular))
                .foregroundColor(Color.white.opacity(0.8))
                .padding(.bottom, 14 * s)

            // 3-Column Modern UI Tile Grid
            LazyVGrid(columns: threeColumns, spacing: 10 * s) {
                ForEach(store.state.focusJobs) { job in
                    FocusJobTile(job: job) {
                        store.toggleFocusJob(id: job.id)
                    }
                }
            }

            Spacer(minLength: 8 * s)

            // Divider & Tools Footer
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1 * s)
                .padding(.bottom, 6 * s)

            Text(store.state.heroTools)
                .font(.system(size: 11 * s, weight: .bold))
                .foregroundColor(Color.white.opacity(0.6))
        }
        .padding(24 * s)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppConfig.Colors.blockBlack)
    }
}