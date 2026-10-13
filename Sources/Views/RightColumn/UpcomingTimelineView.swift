import SwiftUI

public struct UpcomingTimelineView: View {
    public var events: [HorizonEvent]
    @Environment(\.scaleFactor) private var s

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 3 * s) {
                    // Line 1: Tag + Time Anchor (Scales with window)
                    HStack {
                        Text(event.tag.uppercased())
                            .font(.system(size: 10 * s, weight: .bold))
                            .tracking(1.0 * s)
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                        Spacer()
                        Text(event.timeAnchor)
                            .font(.system(size: 12 * s, weight: .bold))
                            .foregroundColor(.black)
                    }

                    // Line 2: Primary Event Title (Scales with window)
                    Text(event.title)
                        .font(.system(size: 15 * s, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 1 * s)

                    // Line 3: Context / Location Notes (Scales with window)
                    if !event.notes.isEmpty {
                        Text(event.notes)
                            .font(.system(size: 11 * s, weight: .regular))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                            .lineSpacing(1.5 * s)
                            .padding(.top, 1 * s)
                    }

                    // Thin Divider Rule (Scales with window)
                    Rectangle()
                        .fill(AppConfig.Colors.lineGrey)
                        .frame(height: 0.8 * s)
                        .padding(.top, 8 * s)
                }
                .padding(.vertical, 6 * s)
            }
        }
    }
}