import SwiftUI

struct LeftColumnAdaptiveLayout: Layout {
    let maxBottomRatio: CGFloat

    static func calculateSplit(
        boundsHeight: CGFloat,
        bottomNaturalHeight: CGFloat,
        maxBottomRatio: CGFloat
    ) -> (topHeight: CGFloat, bottomHeight: CGFloat) {
        let maxBottomHeight = boundsHeight * maxBottomRatio
        let bottomHeight = max(0, min(bottomNaturalHeight, maxBottomHeight))
        let topHeight = max(0, boundsHeight - bottomHeight)
        return (topHeight, bottomHeight)
    }

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

        let bottomNaturalSize = bottomView.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        let split = Self.calculateSplit(
            boundsHeight: bounds.height,
            bottomNaturalHeight: bottomNaturalSize.height,
            maxBottomRatio: maxBottomRatio
        )

        topView.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: ProposedViewSize(width: bounds.width, height: split.topHeight)
        )

        bottomView.place(
            at: CGPoint(x: bounds.minX, y: bounds.maxY - split.bottomHeight),
            proposal: ProposedViewSize(width: bounds.width, height: split.bottomHeight)
        )
    }
}

public struct DashboardView: View {
    @Bindable public var store: DashboardStore

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
                            if store.taskDraft != nil {
                                VStack(spacing: 0) {
                                    PanelHeaderView(
                                        title: "TASK ENTRY DISPATCH",
                                        badgeText: "NEW OPERATION",
                                        badgeIcon: "plus.circle"
                                    )
                                    ScrollView(.vertical) {
                                        TaskEditorView(store: store)
                                            .padding(.horizontal, 24 * scalar)
                                            .padding(.top, 16 * scalar)
                                            .padding(.bottom, 24 * scalar)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            }

                        case .edit:
                            if let draft = store.taskDraft {
                                VStack(spacing: 0) {
                                    PanelHeaderView(
                                        title: "TASK MODIFICATION",
                                        badgeText: "EDIT OPERATION",
                                        badgeIcon: "pencil"
                                    )
                                    ScrollView(.vertical) {
                                        TaskEditorView(store: store)
                                            .id(draft.id)
                                            .padding(.horizontal, 24 * scalar)
                                            .padding(.top, 16 * scalar)
                                            .padding(.bottom, 24 * scalar)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            }

                        case .status:
                            VStack(spacing: 0) {
                                PanelHeaderView(
                                    title: "OPERATIONAL STATUS",
                                    badgeText: "OVERVIEW",
                                    badgeIcon: "gauge.with.needle"
                                )
                                ScrollView(.vertical) {
                                    StatusView(store: store)
                                        .padding(.horizontal, 24 * scalar)
                                        .padding(.top, 16 * scalar)
                                        .padding(.bottom, 24 * scalar)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))

                        case .backlog:
                            VStack(spacing: 0) {
                                PanelHeaderView(
                                    title: "OPERATIONAL BACKLOG",
                                    badgeText: "ALL ITEMS (\(store.state.tasks.count))",
                                    badgeIcon: "tray.full"
                                )
                                ScrollView(.vertical) {
                                    BacklogListView(store: store)
                                        .padding(.horizontal, 24 * scalar)
                                        .padding(.top, 12 * scalar)
                                        .padding(.bottom, 24 * scalar)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))

                        case .history:
                            VStack(spacing: 0) {
                                PanelHeaderView(
                                    title: "OPERATIONAL HISTORY",
                                    badgeText: "LOGGED (\(store.state.historyRecords.count))",
                                    badgeIcon: "clock.arrow.circlepath"
                                )
                                ScrollView(.vertical) {
                                    HistoryTimelineView(
                                        records: store.state.historyRecords,
                                        onExport: { store.exportStateToDisk() }
                                    )
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