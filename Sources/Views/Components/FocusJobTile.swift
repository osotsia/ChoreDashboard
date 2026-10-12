import SwiftUI

public struct FocusJobTile: View {
    public let job: FocusJob
    @Environment(\.scaleFactor) private var s

    private var hasSubtitleComment: Bool {
        !job.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Detailed System Badge
            Text(job.tag.uppercased())
                .font(.system(size: 10 * s, weight: .bold))
                .tracking(1.3 * s)
                .foregroundColor(Color.white.opacity(0.7))
                .lineLimit(1)
                .padding(.bottom, 6 * s)

            // Primary Job Title
            Text(job.title)
                .font(.system(size: 14 * s, weight: .bold))
                .foregroundColor(.white)
                .lineSpacing(1.5 * s)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, hasSubtitleComment ? 6 * s : 0)

            // Contextual 1-Sentence Subtitle
            if hasSubtitleComment {
                Text(job.notes)
                    .font(.system(size: 12 * s, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineSpacing(1.5 * s)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14 * s)
        .frame(maxWidth: .infinity, minHeight: 120 * s, alignment: .topLeading)
        .background(AppConfig.Colors.tileBackground)
        .overlay(
            Rectangle()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1 * s)
        )
    }
}