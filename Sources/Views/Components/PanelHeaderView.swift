import SwiftUI

public struct PanelHeaderView: View {
    public let title: String
    public let badgeText: String
    public let badgeIcon: String?
    @Environment(\.scaleFactor) private var s

    public init(title: String, badgeText: String, badgeIcon: String? = nil) {
        self.title = title
        self.badgeText = badgeText
        self.badgeIcon = badgeIcon
    }

    public var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11 * s, weight: .bold))
                .tracking(2.0 * s)
            Spacer()
            HStack(spacing: 5 * s) {
                if let badgeIcon = badgeIcon {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 11 * s, weight: .bold))
                }
                Text(badgeText.uppercased())
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