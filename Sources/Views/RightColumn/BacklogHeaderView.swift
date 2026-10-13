import SwiftUI

public struct BacklogHeaderView: View {
    public let count: Int
    @Environment(\.scaleFactor) private var s

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        HStack {
            Text("OPERATIONAL BACKLOG")
                .font(.system(size: 11 * s, weight: .bold))
                .tracking(2.0 * s)
            Spacer()
            HStack(spacing: 5 * s) {
                Image(systemName: "tray.full")
                    .font(.system(size: 11 * s, weight: .bold))
                Text("ALL ITEMS (\(count))")
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