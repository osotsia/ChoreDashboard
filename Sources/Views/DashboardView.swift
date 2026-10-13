import SwiftUI

// MARK: - Left Column Layout (Adaptive Split: Hug Content up to 40%)
private struct LeftColumnAdaptiveLayout: Layout {
    let maxBottomRatio: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (AppConfig.baseWidth * AppConfig.splitRatio)
        let height = proposal.height ?? AppConfig.baseHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count >= 2 else {
            for subview in subviews {
                subview.place(at: bounds.origin, proposal: proposal)
            }
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

    public var body: some View {
        GeometryReader { geometry in
            let scalar = max(1.0, geometry.size.width / AppConfig.baseWidth)

            HStack(spacing: 0) {
                // =============================================================
                // LEFT COLUMN: 65% OPERATIONAL FOCUS (Dark Zones)
                // =============================================================
                LeftColumnAdaptiveLayout(maxBottomRatio: 0.40) {
                    PrimaryFocusView(store: store)
                    BaselineResetView(store: store)
                }
                .frame(
                    width: geometry.size.width * AppConfig.splitRatio,
                    height: geometry.size.height
                )

                // =============================================================
                // RIGHT COLUMN: 35% HORIZON (Softened Light Background)
                // =============================================================
                VStack(spacing: 0) {
                    UpcomingHeaderView()

                    VStack(spacing: 0) {
                        UpcomingTimelineView(events: store.state.upcomingEvents)
                        Spacer(minLength: 16 * scalar)
                        BottomActionBarView(store: store)
                    }
                    .padding(.horizontal, 24 * scalar)
                    .padding(.top, 12 * scalar)
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