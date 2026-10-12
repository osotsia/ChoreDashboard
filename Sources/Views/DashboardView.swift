import SwiftUI

public struct DashboardView: View {
    @Bindable public var store: DashboardStore

    public var body: some View {
        GeometryReader { geometry in
            let scalar = max(1.0, geometry.size.width / AppConfig.baseWidth)

            HStack(spacing: 0) {
                // =============================================================
                // LEFT COLUMN: 65% OPERATIONAL FOCUS (Dark Zones)
                // =============================================================
                VStack(spacing: 0) {
                    PrimaryFocusView(store: store)
                        .frame(height: geometry.size.height * 0.54)

                    BaselineResetView(store: store)
                        .frame(height: geometry.size.height * 0.46)
                }
                .frame(width: geometry.size.width * AppConfig.splitRatio)

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
                .frame(width: geometry.size.width * (1.0 - AppConfig.splitRatio))
                .background(AppConfig.Colors.panelLight)
                .environment(\.colorScheme, .light)
            }
            .environment(\.scaleFactor, scalar)
        }
        .ignoresSafeArea()
    }
}