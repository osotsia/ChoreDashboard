import SwiftUI

public struct UpcomingTimelineView: View {
    public var events: [HorizonEvent]

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 4) {
                    // Line 1: Tag + Time Anchor
                    HStack {
                        Text(event.tag.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                        Spacer()
                        Text(event.timeAnchor)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black) // Fixed: explicitly black
                    }

                    // Line 2: Primary Event Title
                    Text(event.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black) // Fixed: explicitly black
                        .padding(.top, 1)

                    // Line 3: Context / Location Notes
                    Text(event.notes)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                        .padding(.top, 1)

                    // Thin Divider Rule
                    Rectangle()
                        .fill(AppConfig.Colors.lineGrey)
                        .frame(height: 0.8)
                        .padding(.top, 10)
                }
                .padding(.vertical, 8)
            }
        }
    }
}