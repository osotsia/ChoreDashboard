// Sources/Views/RightColumn/CreateTaskHeaderView.swift
import SwiftUI

public struct CreateTaskHeaderView: View {
    @Environment(\.scaleFactor) private var s

    public init() {}

    public var body: some View {
        HStack {
            Text("TASK ENTRY DISPATCH")
                .font(.system(size: 11 * s, weight: .bold))
                .tracking(2.0 * s)
            Spacer()
            HStack(spacing: 5 * s) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11 * s, weight: .bold))
                Text("NEW OPERATION")
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