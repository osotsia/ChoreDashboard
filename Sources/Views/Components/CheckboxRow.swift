import SwiftUI

public struct CheckboxRow: View {
    public let title: String
    public let tag: String
    public let isCompleted: Bool
    public let onToggle: () -> Void

    public var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Architectural sharp square checkbox
                ZStack {
                    Rectangle()
                        .strokeBorder(Color.white, lineWidth: 1.5)
                        .frame(width: 17, height: 17)
                        .background(isCompleted ? Color.white : Color.clear)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.black)
                    }
                }

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .strikethrough(isCompleted, color: .white.opacity(0.6))

                Spacer()

                Text(tag)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}