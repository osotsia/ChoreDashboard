// --- File: Sources/Views/RightColumn/BacklogListView.swift ---
import SwiftUI

public struct BacklogListView: View {
    public var focusJobs: [FocusJob]
    public var upcomingEvents: [HorizonEvent]
    public var baselineTasks: [ChoreItem]
    public var highlightedId: UUID? = nil
    public var onEditFocusJob: ((FocusJob) -> Void)? = nil
    public var onEditBaselineTask: ((ChoreItem) -> Void)? = nil
    public var onEditUpcomingEvent: ((HorizonEvent) -> Void)? = nil
    @Environment(\.scaleFactor) private var s

    public init(
        focusJobs: [FocusJob],
        upcomingEvents: [HorizonEvent],
        baselineTasks: [ChoreItem],
        highlightedId: UUID? = nil,
        onEditFocusJob: ((FocusJob) -> Void)? = nil,
        onEditBaselineTask: ((ChoreItem) -> Void)? = nil,
        onEditUpcomingEvent: ((HorizonEvent) -> Void)? = nil
    ) {
        self.focusJobs = focusJobs
        self.upcomingEvents = upcomingEvents
        self.baselineTasks = baselineTasks
        self.highlightedId = highlightedId
        self.onEditFocusJob = onEditFocusJob
        self.onEditBaselineTask = onEditBaselineTask
        self.onEditUpcomingEvent = onEditUpcomingEvent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20 * s) {
            // SECTION 1: MAIN TASKS
            sectionBlock(title: "01 · MAIN TASKS", count: focusJobs.count) {
                ForEach(focusJobs) { job in
                    let isEditing = highlightedId == job.id
                    VStack(alignment: .leading, spacing: 3 * s) {
                        HStack {
                            Text(job.tag.uppercased())
                                .font(.system(size: 10 * s, weight: .bold))
                                .tracking(1.0 * s)
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                            Spacer()
                            Text("FOCUS OPERATION")
                                .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                        }

                        Text(job.title)
                            .font(.system(size: 14 * s, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.top, 1 * s)

                        if !job.notes.isEmpty {
                            Text(job.notes)
                                .font(.system(size: 11 * s, weight: .regular))
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                                .lineSpacing(1.5 * s)
                                .padding(.top, 1 * s)
                        }

                        Rectangle()
                            .fill(AppConfig.Colors.lineGrey)
                            .frame(height: 0.8 * s)
                            .padding(.top, 6 * s)
                    }
                    .padding(.vertical, 4 * s)
                    .padding(.horizontal, 6 * s)
                    .background(isEditing ? Color.black.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4 * s))
                    .contentShape(Rectangle())
                    .contextMenu {
                        if let onEditFocusJob = onEditFocusJob {
                            Button {
                                onEditFocusJob(job)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
            }

            // SECTION 2: UPCOMING HORIZON
            sectionBlock(title: "02 · UPCOMING HORIZON", count: upcomingEvents.count) {
                ForEach(upcomingEvents) { event in
                    let isEditing = highlightedId == event.id
                    VStack(alignment: .leading, spacing: 3 * s) {
                        HStack {
                            Text(event.tag.uppercased())
                                .font(.system(size: 10 * s, weight: .bold))
                                .tracking(1.0 * s)
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                            Spacer()
                            Text(event.timeAnchor.uppercased())
                                .font(.system(size: 9 * s, weight: .bold))
                                .foregroundColor(.black)
                        }

                        Text(event.title)
                            .font(.system(size: 14 * s, weight: .bold))
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
                            .padding(.top, 6 * s)
                    }
                    .padding(.vertical, 4 * s)
                    .padding(.horizontal, 6 * s)
                    .background(isEditing ? Color.black.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4 * s))
                    .contentShape(Rectangle())
                    .contextMenu {
                        if let onEditUpcomingEvent = onEditUpcomingEvent {
                            Button {
                                onEditUpcomingEvent(event)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
            }

            // SECTION 3: DAILY BASELINE
            sectionBlock(title: "03 · DAILY BASELINE", count: baselineTasks.count) {
                ForEach(baselineTasks) { task in
                    let isEditing = highlightedId == task.id
                    VStack(alignment: .leading, spacing: 3 * s) {
                        HStack {
                            Text(task.tag.uppercased())
                                .font(.system(size: 10 * s, weight: .bold))
                                .tracking(1.0 * s)
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                            Spacer()
                            Text("\(task.durationMinutes) MIN")
                                .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                        }

                        HStack(spacing: 8 * s) {
                            Text(task.title)
                                .font(.system(size: 14 * s, weight: .bold))
                                .foregroundColor(.black)
                                .strikethrough(task.isCompleted, color: Color.black.opacity(0.4))

                            Spacer()

                            if task.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10 * s, weight: .black))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.top, 1 * s)

                        Rectangle()
                            .fill(AppConfig.Colors.lineGrey)
                            .frame(height: 0.8 * s)
                            .padding(.top, 6 * s)
                    }
                    .padding(.vertical, 4 * s)
                    .padding(.horizontal, 6 * s)
                    .background(isEditing ? Color.black.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4 * s))
                    .contentShape(Rectangle())
                    .contextMenu {
                        if let onEditBaselineTask = onEditBaselineTask {
                            Button {
                                onEditBaselineTask(task)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func sectionBlock<Content: View>(
        title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            HStack {
                SectionBadge(text: title)
                    .foregroundColor(.black)

                Spacer()

                Text("\(count) ITEMS")
                    .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
                    .tracking(1.0 * s)
                    .foregroundColor(AppConfig.Colors.subtextGrey)
            }
            .padding(.vertical, 4 * s)
            .padding(.horizontal, 8 * s)
            .background(AppConfig.Colors.headerGrey.opacity(0.35))
            .border(AppConfig.Colors.lineGrey, width: 1 * s)

            content()
        }
    }
}