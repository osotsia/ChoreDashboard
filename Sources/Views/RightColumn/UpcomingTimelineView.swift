// Sources/Views/RightColumn/UpcomingTimelineView.swift
import SwiftUI

public struct UpcomingTimelineView: View {
    public var events: [HorizonEvent]
    public var highlightedId: UUID? = nil
    public var onEdit: ((HorizonEvent) -> Void)? = nil
    @Environment(\.scaleFactor) private var s

    public init(
        events: [HorizonEvent],
        highlightedId: UUID? = nil,
        onEdit: ((HorizonEvent) -> Void)? = nil
    ) {
        self.events = events
        self.highlightedId = highlightedId
        self.onEdit = onEdit
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(events) { event in
                let isEditingThis = highlightedId == event.id

                VStack(alignment: .leading, spacing: 3 * s) {
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

                    Text(event.title)
                        .font(.system(size: 15 * s, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 1 * s)

                    if !event.notes.isEmpty {
                        Text(event.notes)
                            .font(.system(size: 11 * s, weight: .regular))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                            .lineSpacing(1.5 * s)
                            .padding(.top, 1 * s)
                    }

                    Rectangle()
                        .fill(AppConfig.Colors.lineGrey)
                        .frame(height: 0.8 * s)
                        .padding(.top, 8 * s)
                }
                .padding(.vertical, 6 * s)
                .padding(.horizontal, 6 * s)
                .background(isEditingThis ? Color.black.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4 * s))
                .contentShape(Rectangle())
                .contextMenu {
                    if let onEdit = onEdit {
                        Button {
                            onEdit(event)
                        } label: {
                            Label("Edit Event", systemImage: "pencil")
                        }
                    }
                }
            }
        }
    }
}