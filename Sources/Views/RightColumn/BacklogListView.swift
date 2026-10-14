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

    private var totalInventoryCount: Int {
        focusJobs.count + upcomingEvents.count + baselineTasks.count
    }

    private var sortedEvents: [HorizonEvent] {
        upcomingEvents.sorted {
            if $0.estimatedDaysRemaining != $1.estimatedDaysRemaining {
                return $0.estimatedDaysRemaining < $1.estimatedDaysRemaining
            }
            return $0.title < $1.title
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18 * s) {
            // INVENTORY FORMULA TELEMETRY BANNER
            VStack(alignment: .leading, spacing: 4 * s) {
                Text("TOTAL TASK INVENTORY: \(totalInventoryCount)")
                    .font(.system(size: 9.5 * s, weight: .black, design: .monospaced))
                    .tracking(1.2 * s)
                    .foregroundColor(.black)

                HStack(spacing: 4 * s) {
                    Text("\(focusJobs.count) TODAY")
                        .font(.system(size: 8.5 * s, weight: .bold))
                    Text("+")
                        .font(.system(size: 8.5 * s, weight: .bold))
                    Text("\(upcomingEvents.count) HORIZON")
                        .font(.system(size: 8.5 * s, weight: .bold))
                    Text("+")
                        .font(.system(size: 8.5 * s, weight: .bold))
                    Text("\(baselineTasks.count) DAILY")
                        .font(.system(size: 8.5 * s, weight: .bold))
                    Spacer()
                }
                .foregroundColor(AppConfig.Colors.subtextGrey)
            }
            .padding(8 * s)
            .background(Color.white)
            .border(AppConfig.Colors.lineGrey, width: 1 * s)

            // SECTION 1: ACTIVE TODAY (FOCUS OPERATIONS)
            sectionBlock(
                title: "01 · ACTIVE TODAY (FOCUS QUEUE)",
                subtitle: "NON-ROUTINE · DUE TODAY",
                count: focusJobs.count
            ) {
                ForEach(focusJobs) { job in
                    let isEditing = highlightedId == job.id
                    VStack(alignment: .leading, spacing: 3 * s) {
                        HStack {
                            Text(job.tag.uppercased())
                                .font(.system(size: 10 * s, weight: .bold))
                                .tracking(1.0 * s)
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                            Spacer()
                            Text(job.isOverdue ? "OVERDUE" : "TODAY")
                                .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
                                .foregroundColor(job.isOverdue ? .red : AppConfig.Colors.subtextGrey)
                        }

                        Text(job.title)
                            .font(.system(size: 14 * s, weight: .bold))
                            .foregroundColor(.black)
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
                        if let onEditFocusJob = onEditFocusJob {
                            Button { onEditFocusJob(job) } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
            }

            // SECTION 2: HORIZON QUEUE (SCHEDULED AHEAD)
            sectionBlock(
                title: "02 · HORIZON QUEUE (SCHEDULED AHEAD)",
                subtitle: "CADENCE HORIZON · RECURRING (>1 DAY)",
                count: upcomingEvents.count
            ) {
                ForEach(sortedEvents) { event in
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
                            Button { onEditUpcomingEvent(event) } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
            }

            // SECTION 3: DAILY BASELINE (24-HOUR RESET)
            sectionBlock(
                title: "03 · DAILY BASELINE (24-HOUR CADENCE)",
                subtitle: "HABITS & DAILY UPKEEP",
                count: baselineTasks.count
            ) {
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
                            Button { onEditBaselineTask(task) } label: {
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
        subtitle: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            HStack {
                VStack(alignment: .leading, spacing: 1 * s) {
                    SectionBadge(text: title)
                        .foregroundColor(.black)
                    Text(subtitle.uppercased())
                        .font(.system(size: 7.5 * s, weight: .bold))
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                }

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