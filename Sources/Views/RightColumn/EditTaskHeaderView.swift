// Sources/Views/RightColumn/EditTaskHeaderView.swift
import SwiftUI

public struct EditTaskHeaderView: View {
    @Environment(\.scaleFactor) private var s

    public init() {}

    public var body: some View {
        HStack {
            Text("TASK MODIFICATION")
                .font(.system(size: 11 * s, weight: .bold))
                .tracking(2.0 * s)
            Spacer()
            HStack(spacing: 5 * s) {
                Image(systemName: "pencil")
                    .font(.system(size: 11 * s, weight: .bold))
                Text("EDIT OPERATION")
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