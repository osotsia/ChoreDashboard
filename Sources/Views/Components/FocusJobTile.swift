// Sources/Views/Components/FocusJobTile.swift
import SwiftUI

public struct FocusJobTile: View {
    public let job: FocusJob
    public var isHighlighted: Bool = false
    public var onToggle: () -> Void
    public var onEdit: (() -> Void)? = nil
    @Environment(\.scaleFactor) private var s

    private var hasSubtitleComment: Bool {
        !job.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Row: System Tag + Checkbox
            HStack(alignment: .center) {
                Text(job.tag.uppercased())
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.3 * s)
                    .foregroundColor(job.isCompleted ? Color.white.opacity(0.35) : Color.white.opacity(0.7))
                    .lineLimit(1)

                Spacer()

                Button(action: onToggle) {
                    ZStack {
                        Rectangle()
                            .strokeBorder(
                                job.isCompleted ? Color.white : Color.white.opacity(0.35),
                                lineWidth: 1.5 * s
                            )
                            .frame(width: 17 * s, height: 17 * s)
                            .background(job.isCompleted ? Color.white : Color.clear)

                        if job.isCompleted {
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

            // Primary Job Title
            Text(job.title)
                .font(.system(size: 14 * s, weight: .bold))
                .foregroundColor(job.isCompleted ? Color.white.opacity(0.4) : .white)
                .strikethrough(job.isCompleted, color: Color.white.opacity(0.4))
                .lineSpacing(1.5 * s)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, hasSubtitleComment ? 6 * s : 0)

            // Contextual Subtitle
            if hasSubtitleComment {
                Text(job.notes)
                    .font(.system(size: 12 * s, weight: .medium))
                    .foregroundColor(job.isCompleted ? Color.white.opacity(0.3) : Color.white.opacity(0.85))
                    .lineSpacing(1.5 * s)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14 * s)
        .frame(maxWidth: .infinity, minHeight: 120 * s, alignment: .topLeading)
        .background(
            isHighlighted
                ? Color.white.opacity(0.12)
                : (job.isCompleted ? AppConfig.Colors.tileBackground.opacity(0.5) : AppConfig.Colors.tileBackground)
        )
        .overlay(
            Rectangle()
                .strokeBorder(
                    isHighlighted ? Color.white : (job.isCompleted ? Color.white.opacity(0.1) : Color.white.opacity(0.2)),
                    lineWidth: isHighlighted ? 1.5 * s : 1 * s
                )
        )
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit Operation", systemImage: "pencil")
                }
            }
        }
    }
}