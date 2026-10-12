import SwiftUI

public struct UpcomingHeaderView: View {
    @Environment(\.scaleFactor) private var s

    public var body: some View {
        HStack {
            Text("UPCOMING & HORIZON")
                .font(.system(size: 11 * s, weight: .bold))
                .tracking(2.0 * s)
            Spacer()
            HStack(spacing: 5 * s) {
                Image(systemName: "calendar")
                    .font(.system(size: 11 * s, weight: .bold))
                Text("CADENCE QUEUE")
                    .font(.system(size: 11 * s, weight: .bold))
            }
        }
        .foregroundColor(.black)
        .padding(.horizontal, 24 * s)
        .frame(height: 52 * s)
        .background(AppConfig.Colors.headerGrey)
        .overlay(
            Rectangle()
                .frame(height: 1 * s)
                .foregroundColor(AppConfig.Colors.headerBorder),
            alignment: .bottom
        )
    }
}