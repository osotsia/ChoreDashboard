import SwiftUI

private struct LeftColumnAdaptiveLayout: Layout {
    let maxBottomRatio: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (AppConfig.baseWidth * AppConfig.splitRatio)
        let height = proposal.height ?? AppConfig.baseHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count >= 2 else {
            for subview in subviews { subview.place(at: bounds.origin, proposal: proposal) }
            return
        }

        let topView = subviews[0]
        let bottomView = subviews[1]

        let maxBottomHeight = bounds.height * maxBottomRatio
        let bottomNaturalSize = bottomView.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        let bottomHeight = min(bottomNaturalSize.height, maxBottomHeight)
        let topHeight = bounds.height - bottomHeight

        topView.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: ProposedViewSize(width: bounds.width, height: topHeight)
        )

        bottomView.place(
            at: CGPoint(x: bounds.minX, y: bounds.maxY - bottomHeight),
            proposal: ProposedViewSize(width: bounds.width, height: bottomHeight)
        )
    }
}

public struct DashboardView: View {
    @Bindable public var store: DashboardStore

    private var totalBacklogCount: Int {
        store.state.focusJobs.count + store.state.upcomingEvents.count + store.state.baselineTasks.count
    }

    public var body: some View {
        GeometryReader { geometry in
            let scalar = max(1.0, geometry.size.width / AppConfig.baseWidth)

            HStack(spacing: 0) {
                // LEFT COLUMN: 65% OPERATIONAL FOCUS
                LeftColumnAdaptiveLayout(maxBottomRatio: 0.40) {
                    PrimaryFocusView(store: store)
                    BaselineResetView(store: store)
                }
                .frame(
                    width: geometry.size.width * AppConfig.splitRatio,
                    height: geometry.size.height
                )

                // RIGHT COLUMN: 35% DECK
                VStack(spacing: 0) {
                    ZStack {
                        switch store.activeRightTab {
                        case .create:
                            VStack(spacing: 0) {
                                PanelHeaderView(title: "TASK ENTRY DISPATCH", badgeText: "NEW OPERATION", badgeIcon: "plus.circle")
                                ScrollView(.vertical) {
                                    TaskEditorView(store: store, mode: .create)
                                        .padding(.horizontal, 24 * scalar)
                                        .padding(.top, 16 * scalar)
                                        .padding(.bottom, 24 * scalar)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))

                        case .edit:
                            if let target = store.editingTarget {
                                VStack(spacing: 0) {
                                    PanelHeaderView(title: "TASK MODIFICATION", badgeText: "EDIT OPERATION", badgeIcon: "pencil")
                                    ScrollView(.vertical) {
                                        TaskEditorView(store: store, mode: .edit(target))
                                            .padding(.horizontal, 24 * scalar)
                                            .padding(.top, 16 * scalar)
                                            .padding(.bottom, 24 * scalar)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            }

                        case .upcoming:
                            VStack(spacing: 0) {
                                PanelHeaderView(title: "UPCOMING & HORIZON", badgeText: "CADENCE QUEUE", badgeIcon: "calendar")
                                ScrollView(.vertical) {
                                    UpcomingTimelineView(
                                        events: store.state.upcomingEvents,
                                        highlightedId: store.editingTarget?.id,
                                        onEdit: { event in
                                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                                store.startEditing(upcomingEvent: event)
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 24 * scalar)
                                    .padding(.top, 12 * scalar)
                                    .padding(.bottom, 16 * scalar)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))

                        case .backlog:
                            VStack(spacing: 0) {
                                PanelHeaderView(title: "OPERATIONAL BACKLOG", badgeText: "ALL ITEMS (\(totalBacklogCount))", badgeIcon: "tray.full")
                                ScrollView(.vertical) {
                                    BacklogListView(
                                        focusJobs: store.state.focusJobs,
                                        upcomingEvents: store.state.upcomingEvents,
                                        baselineTasks: store.state.baselineTasks,
                                        highlightedId: store.editingTarget?.id,
                                        onEditFocusJob: { job in
                                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                                store.startEditing(focusJob: job)
                                            }
                                        },
                                        onEditBaselineTask: { task in
                                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                                store.startEditing(baselineTask: task)
                                            }
                                        },
                                        onEditUpcomingEvent: { event in
                                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                                store.startEditing(upcomingEvent: event)
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 24 * scalar)
                                    .padding(.top, 12 * scalar)
                                    .padding(.bottom, 24 * scalar)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))

                        case .history:
                            VStack(spacing: 0) {
                                PanelHeaderView(title: "OPERATIONAL HISTORY", badgeText: "LOGGED (\(store.state.historyRecords.count))", badgeIcon: "clock.arrow.circlepath")
                                ScrollView(.vertical) {
                                    HistoryTimelineView(records: store.state.historyRecords)
                                        .padding(.horizontal, 24 * scalar)
                                        .padding(.top, 12 * scalar)
                                        .padding(.bottom, 24 * scalar)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    BottomActionBarView(store: store)
                        .padding(.horizontal, 24 * scalar)
                        .padding(.top, 16 * scalar)
                        .padding(.bottom, 24 * scalar)
                }
                .frame(
                    width: geometry.size.width * (1.0 - AppConfig.splitRatio),
                    height: geometry.size.height
                )
                .background(AppConfig.Colors.panelLight)
                .environment(\.colorScheme, .light)
            }
            .environment(\.scaleFactor, scalar)
        }
        .ignoresSafeArea()
    }
}