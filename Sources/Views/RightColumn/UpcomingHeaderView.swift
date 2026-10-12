import SwiftUI

public struct UpcomingHeaderView: View {
    public var body: some View {
        HStack {
            SectionBadge(text: "UPCOMING & HORIZON")
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .bold))
                Text("CADENCE QUEUE")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .foregroundColor(.black)
        .padding(.horizontal, 24)
        .frame(height: 52)
        .background(AppConfig.Colors.headerGrey)
        .overlay(
            Rectangle()
                .frame(height: 0.8)
                .foregroundColor(AppConfig.Colors.lineGrey),
            alignment: .bottom
        )
    }
}