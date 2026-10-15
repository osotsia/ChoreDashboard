import SwiftUI

public struct BacklogListView: View {
    public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    public init(store: DashboardStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18 * s) {
            // INVENTORY FORMULA TELEMETRY BANNER
            VStack(alignment: .leading, spacing: 4 * s) {
                Text("TOTAL TASK INVENTORY: \(store.state.tasks.count)")
                    .font(.system(size: 9.5 * s, weight: .black, design: .monospaced))
                    .tracking(1.2 * s)
                    .foregroundColor(.black)

                HStack(spacing: 4 * s) {
                    Text("\(store.focusQueue.count) TODAY")
                        .font(.system(size: 8.5 * s, weight: .bold))
                    Text("+")
                        .font(.system(size: 8.5 * s, weight: .bold))
                    Text("\(store.upcomingEvents.count) HORIZON")
                        .font(.system(size: 8.5 * s, weight: .bold))
                    Text("+")
                        .font(.system(size: 8.5 * s, weight: .bold))
                    Text("\(store.baselineTasks.count) DAILY")
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
                count: store.focusQueue.count
            ) {
                ForEach(store.focusQueue) { job in
                    let isEditing = store.taskDraft?.id == job.id
                    VStack(alignment: .leading, spacing: 3 * s) {
                        HStack {
                            Text(job.tag.uppercased())
                                .font(.system(size: 10 * s, weight: .bold))
                                .tracking(1.0 * s)
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                            Spacer()

                            if job.isCompleted {
                                Text("COMPLETED")
                                    .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppConfig.Colors.statusGreen)
                            } else {
                                Text(job.healthState() == .overdue ? "OVERDUE" : "TODAY")
                                    .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
                                    .foregroundColor(job.healthState() == .overdue ? .red : AppConfig.Colors.subtextGrey)
                            }
                        }

                        HStack {
                            Text(job.title)
                                .font(.system(size: 14 * s, weight: .bold))
                                .foregroundColor(job.isCompleted ? Color.black.opacity(0.4) : .black)
                                .strikethrough(job.isCompleted, color: Color.black.opacity(0.4))
                                .padding(.top, 1 * s)

                            Spacer()

                            if job.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10 * s, weight: .black))
                                    .foregroundColor(.black)
                            }
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
                        Button { store.startEditing(task: job) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                }
            }

            // SECTION 2: HORIZON QUEUE (SCHEDULED AHEAD)
            sectionBlock(
                title: "02 · HORIZON QUEUE (SCHEDULED AHEAD)",
                subtitle: "CADENCE HORIZON · RECURRING (>1 DAY)",
                count: store.upcomingEvents.count
            ) {
                ForEach(store.sortedUpcomingEvents) { event in
                    let isEditing = store.taskDraft?.id == event.id
                    VStack(alignment: .leading, spacing: 3 * s) {
                        HStack {
                            Text(event.tag.uppercased())
                                .font(.system(size: 10 * s, weight: .bold))
                                .tracking(1.0 * s)
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                            Spacer()
                            Text(event.timeAnchor().uppercased())
                                .font(.system(size: 9 * s, weight: .bold))
                                .foregroundColor(.black)
                        }

                        HStack {
                            Text(event.title)
                                .font(.system(size: 14 * s, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.top, 1 * s)

                            Spacer()

                            Button {
                                store.completeHorizonTask(id: event.id)
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 12 * s))
                                    .foregroundColor(AppConfig.Colors.subtextGrey)
                            }
                            .buttonStyle(.plain)
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
                        Button { store.completeHorizonTask(id: event.id) } label: {
                            Label("Mark Complete", systemImage: "checkmark.circle")
                        }
                        Button { store.startEditing(task: event) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                }
            }

            // SECTION 3: DAILY BASELINE (24-HOUR RESET)
            sectionBlock(
                title: "03 · DAILY BASELINE (24-HOUR CADENCE)",
                subtitle: "HABITS & DAILY UPKEEP",
                count: store.baselineTasks.count
            ) {
                ForEach(store.baselineTasks) { task in
                    let isEditing = store.taskDraft?.id == task.id
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
                        Button { store.startEditing(task: task) } label: {
                            Label("Edit", systemImage: "pencil")
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