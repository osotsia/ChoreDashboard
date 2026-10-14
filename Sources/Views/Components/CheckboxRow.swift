import SwiftUI

public struct CheckboxRow: View {
    public let title: String
    public let tag: String
    public var isCompleted: Bool
    public var isHighlighted: Bool = false
    public let onToggle: () -> Void
    public var onEdit: (() -> Void)? = nil
    @Environment(\.scaleFactor) private var s

    public var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14 * s) {
                ZStack {
                    Rectangle()
                        .strokeBorder(Color.white, lineWidth: 1.5 * s)
                        .frame(width: 17 * s, height: 17 * s)
                        .background(isCompleted ? Color.white : Color.clear)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11 * s, weight: .black))
                            .foregroundColor(.black)
                    }
                }

                Text(title)
                    .font(.system(size: 15 * s, weight: .bold))
                    .foregroundColor(.white)
                    .strikethrough(isCompleted, color: .white.opacity(0.6))

                Spacer()

                Text(tag)
                    .font(.system(size: 13 * s, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 6 * s)
            .padding(.vertical, 4 * s)
            .background(isHighlighted ? Color.white.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4 * s))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
    }
}