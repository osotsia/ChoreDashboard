import SwiftUI

public struct StatusView: View {
    public var store: DashboardStore
    public var onEditUpcomingEvent: ((HorizonEvent) -> Void)? = nil
    @Environment(\.scaleFactor) private var s

    public init(
        store: DashboardStore,
        onEditUpcomingEvent: ((HorizonEvent) -> Void)? = nil
    ) {
        self.store = store
        self.onEditUpcomingEvent = onEditUpcomingEvent
    }

    private var topFiveUpcoming: [HorizonEvent] {
        Array(store.sortedUpcomingEvents.prefix(5))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20 * s) {
            // BLOCK 1: TODAY'S BIRD'S-EYE SNAPSHOT
            VStack(alignment: .leading, spacing: 8 * s) {
                HStack {
                    SectionBadge(text: "TODAY'S OPERATIONAL SNAPSHOT")
                        .foregroundColor(.black)
                    Spacer()
                    Text("\(Int(store.todaySnapshot.clearanceRate * 100))% CLEAR")
                        .font(.system(size: 10 * s, weight: .black, design: .monospaced))
                        .foregroundColor(store.todaySnapshot.clearanceRate == 1.0 ? Color(red: 16/255, green: 185/255, blue: 129/255) : .black)
                }
                .padding(.vertical, 4 * s)
                .padding(.horizontal, 8 * s)
                .background(AppConfig.Colors.headerGrey.opacity(0.35))
                .border(AppConfig.Colors.lineGrey, width: 1 * s)

                // High-Density Metric Strip
                HStack(spacing: 8 * s) {
                    // Focus Operations
                    VStack(alignment: .leading, spacing: 3 * s) {
                        Text("FOCUS TASKS")
                            .font(.system(size: 8.5 * s, weight: .bold))
                            .tracking(1.0 * s)
                            .foregroundColor(AppConfig.Colors.subtextGrey)

                        HStack(alignment: .firstTextBaseline, spacing: 4 * s) {
                            Text("\(store.todaySnapshot.focusRemaining)")
                                .font(.system(size: 20 * s, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                            Text("/ \(store.todaySnapshot.focusTotal) LEFT")
                                .font(.system(size: 9.5 * s, weight: .bold))
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                        }

                        if store.todaySnapshot.focusOverdue > 0 {
                            HStack(spacing: 3 * s) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8 * s, weight: .black))
                                Text("\(store.todaySnapshot.focusOverdue) OVERDUE")
                                    .font(.system(size: 8 * s, weight: .black))
                            }
                            .foregroundColor(.red)
                        } else {
                            Text("ALL CURRENT")
                                .font(.system(size: 8 * s, weight: .bold))
                                .foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
                        }
                    }
                    .padding(8 * s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .border(AppConfig.Colors.lineGrey, width: 1 * s)

                    // Daily Baseline
                    VStack(alignment: .leading, spacing: 3 * s) {
                        Text("DAILY BASELINE")
                            .font(.system(size: 8.5 * s, weight: .bold))
                            .tracking(1.0 * s)
                            .foregroundColor(AppConfig.Colors.subtextGrey)

                        HStack(alignment: .firstTextBaseline, spacing: 4 * s) {
                            Text("\(store.todaySnapshot.baselineRemaining)")
                                .font(.system(size: 20 * s, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                            Text("/ \(store.todaySnapshot.baselineTotal) LEFT")
                                .font(.system(size: 9.5 * s, weight: .bold))
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                        }

                        Text("~\(store.todaySnapshot.baselineMinutesRemaining) MIN REMAINING")
                            .font(.system(size: 8 * s, weight: .bold))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                    }
                    .padding(8 * s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .border(AppConfig.Colors.lineGrey, width: 1 * s)
                }
            }

            // BLOCK 2: TOP 5 COMING UP NEXT
            VStack(alignment: .leading, spacing: 8 * s) {
                HStack {
                    SectionBadge(text: "HORIZON QUEUE · NEXT 5 UP")
                        .foregroundColor(.black)
                    Spacer()
                    Text("SHOWING 5 OF \(store.state.upcomingEvents.count)")
                        .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                }
                .padding(.vertical, 4 * s)
                .padding(.horizontal, 8 * s)
                .background(AppConfig.Colors.headerGrey.opacity(0.35))
                .border(AppConfig.Colors.lineGrey, width: 1 * s)

                if topFiveUpcoming.isEmpty {
                    Text("NO SCHEDULED HORIZON TASKS")
                        .font(.system(size: 11 * s, weight: .bold))
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                        .padding(.vertical, 12 * s)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(topFiveUpcoming.enumerated()), id: \.element.id) { index, event in
                            VStack(alignment: .leading, spacing: 3 * s) {
                                HStack {
                                    Text("\(String(format: "%02d", index + 1)) · \(event.tag.uppercased())")
                                        .font(.system(size: 9.5 * s, weight: .bold))
                                        .tracking(1.0 * s)
                                        .foregroundColor(AppConfig.Colors.subtextGrey)

                                    Spacer()

                                    Text(event.timeAnchor.uppercased())
                                        .font(.system(size: 9.5 * s, weight: .bold))
                                        .foregroundColor(.black)
                                }

                                Text(event.title)
                                    .font(.system(size: 13.5 * s, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.top, 1 * s)

                                Rectangle()
                                    .fill(AppConfig.Colors.lineGrey)
                                    .frame(height: 0.8 * s)
                                    .padding(.top, 6 * s)
                            }
                            .padding(.vertical, 4 * s)
                            .padding(.horizontal, 4 * s)
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
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}