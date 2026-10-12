import SwiftUI

public struct DashboardView: View {
    @Bindable public var store: DashboardStore

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // =============================================================
                // LEFT COLUMN: 65% OPERATIONAL FOCUS (Full-Bleed Dark Zones)
                // =============================================================
                VStack(spacing: 0) {
                    PrimaryFocusView(store: store)
                        .frame(height: geometry.size.height * 0.54)
                    
                    BaselineResetView(store: store)
                        .frame(height: geometry.size.height * 0.46)
                }
                .frame(width: geometry.size.width * AppConfig.splitRatio)

                // =============================================================
                // RIGHT COLUMN: 35% HORIZON (Light Background, Locked Theme)
                // =============================================================
                VStack(spacing: 0) {
                    UpcomingHeaderView()

                    VStack(spacing: 0) {
                        UpcomingTimelineView(events: store.state.upcomingEvents)
                        Spacer(minLength: 16)
                        TelemetryCardView(metrics: store.state.telemetryMetrics)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .frame(width: geometry.size.width * (1.0 - AppConfig.splitRatio))
                .background(Color.white)
                .environment(\.colorScheme, .light) // Prevents dark mode white text
            }
        }
        .ignoresSafeArea()
    }
}