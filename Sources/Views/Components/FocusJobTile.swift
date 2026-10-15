import SwiftUI

public struct FocusJobTile: View {
    public let task: TaskItem
    public var isHighlighted: Bool = false
    public var onToggle: () -> Void
    public var onEdit: (() -> Void)? = nil
    @Environment(\.scaleFactor) private var s

    private var isOverdue: Bool {
        task.healthState() == .overdue && !task.isCompleted
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Row: Tag + Overdue Indicator + Checkbox
            HStack(alignment: .center, spacing: 6 * s) {
                Text(task.tag.uppercased())
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.3 * s)
                    .foregroundColor(task.isCompleted ? Color.white.opacity(0.35) : Color.white.opacity(0.7))
                    .lineLimit(1)

                if isOverdue {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11 * s, weight: .bold))
                        .foregroundColor(AppConfig.Colors.statusOrange)
                }

                Spacer()

                Button(action: onToggle) {
                    ZStack {
                        Rectangle()
                            .strokeBorder(
                                task.isCompleted ? Color.white : Color.white.opacity(0.35),
                                lineWidth: 1.5 * s
                            )
                            .frame(width: 17 * s, height: 17 * s)
                            .background(task.isCompleted ? Color.white : Color.clear)

                        if task.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11 * s, weight: .black))
                                .foregroundColor(.black)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8 * s)

            // Primary Task Title
            Text(task.title)
                .font(.system(size: 14 * s, weight: .bold))
                .foregroundColor(task.isCompleted ? Color.white.opacity(0.4) : .white)
                .strikethrough(task.isCompleted, color: Color.white.opacity(0.4))
                .lineSpacing(1.5 * s)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14 * s)
        .frame(maxWidth: .infinity, minHeight: 88 * s, alignment: .topLeading)
        .background(
            isHighlighted
                ? Color.white.opacity(0.12)
                : (task.isCompleted ? AppConfig.Colors.tileBackground.opacity(0.5) : AppConfig.Colors.tileBackground)
        )
        .overlay(
            Rectangle()
                .strokeBorder(
                    isHighlighted ? Color.white : (task.isCompleted ? Color.white.opacity(0.1) : Color.white.opacity(0.2)),
                    lineWidth: isHighlighted ? 1.5 * s : 1 * s
                )
        )
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit Task", systemImage: "pencil")
                }
            }
        }
    }
}