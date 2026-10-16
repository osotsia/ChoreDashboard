// Sources/Views/RightColumn/StatusView.swift
import SwiftUI

public struct StatusView: View {
    public var store: DashboardStore
    @Environment(\.scaleFactor) private var s

    public init(store: DashboardStore) {
        self.store = store
    }

    private var topFiveUpcoming: [TaskItem] {
        Array(store.sortedUpcomingEvents.prefix(5))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18 * s) {
            // ==========================================
            // BLOCK 1: TODAY'S BIRD'S-EYE SNAPSHOT
            // ==========================================
            VStack(alignment: .leading, spacing: 8 * s) {
                HStack {
                    SectionBadge(text: "TODAY'S OPERATIONAL SNAPSHOT")
                        .foregroundColor(.black)
                    Spacer()
                    Text("\(Int(store.todaySnapshot.clearanceRate * 100))% CLEAR")
                        .font(.system(size: 10 * s, weight: .black, design: .monospaced))
                        .foregroundColor(store.todaySnapshot.clearanceRate == 1.0 ? AppConfig.Colors.statusGreen : .black)
                }
                .padding(.vertical, 4 * s)
                .padding(.horizontal, 8 * s)
                .background(AppConfig.Colors.headerGrey.opacity(0.35))
                .border(AppConfig.Colors.lineGrey, width: 1 * s)

                // High-Contrast High-Visibility Metric Strip
                HStack(spacing: 8 * s) {
                    // Focus Operations
                    VStack(alignment: .leading, spacing: 4 * s) {
                        Text("FOCUS TASKS")
                            .font(.system(size: 8.5 * s, weight: .bold))
                            .tracking(1.0 * s)
                            .foregroundColor(AppConfig.Colors.subtextGrey)

                        HStack(alignment: .firstTextBaseline, spacing: 4 * s) {
                            Text("\(store.todaySnapshot.focusRemaining)")
                                .font(.system(size: 36 * s, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                            Text("/ \(store.todaySnapshot.focusTotal) LEFT")
                                .font(.system(size: 10.5 * s, weight: .bold))
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
                                .foregroundColor(AppConfig.Colors.statusGreen)
                        }
                    }
                    .padding(10 * s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .border(AppConfig.Colors.lineGrey, width: 1 * s)

                    // Daily Baseline
                    VStack(alignment: .leading, spacing: 4 * s) {
                        Text("DAILY BASELINE")
                            .font(.system(size: 8.5 * s, weight: .bold))
                            .tracking(1.0 * s)
                            .foregroundColor(AppConfig.Colors.subtextGrey)

                        HStack(alignment: .firstTextBaseline, spacing: 4 * s) {
                            Text("\(store.todaySnapshot.baselineRemaining)")
                                .font(.system(size: 36 * s, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                            Text("/ \(store.todaySnapshot.baselineTotal) LEFT")
                                .font(.system(size: 10.5 * s, weight: .bold))
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                        }

                        Text("~\(store.todaySnapshot.baselineMinutesRemaining) MIN REMAINING")
                            .font(.system(size: 8.5 * s, weight: .bold))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                    }
                    .padding(10 * s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .border(AppConfig.Colors.lineGrey, width: 1 * s)
                }
            }

            // ==========================================
            // BLOCK 2: MONTHLY MAINTENANCE VELOCITY (DUAL-BAR PACING)
            // ==========================================
            let pacing = store.monthlyPacing
            VStack(alignment: .leading, spacing: 8 * s) {
                HStack {
                    SectionBadge(text: "MONTHLY MAINTENANCE VELOCITY · \(pacing.monthTitle)")
                        .foregroundColor(.black)

                    Spacer()

                    HStack(spacing: 3 * s) {
                        if pacing.deltaLead > 0 {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8 * s, weight: .black))
                            Text("+\(pacing.deltaLead) LEAD (AHEAD)")
                                .font(.system(size: 9.5 * s, weight: .black, design: .monospaced))
                                .foregroundColor(AppConfig.Colors.statusGreen)
                        } else if pacing.isLeading || pacing.isOnPace {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8 * s, weight: .black))
                            Text("ON PACE")
                                .font(.system(size: 9.5 * s, weight: .black, design: .monospaced))
                                .foregroundColor(AppConfig.Colors.statusGreen)
                        } else {
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: 8 * s, weight: .black))
                            Text("\(pacing.deltaLead) DEFICIT (LAGGING)")
                                .font(.system(size: 9.5 * s, weight: .black, design: .monospaced))
                                .foregroundColor(AppConfig.Colors.statusOrange)
                        }
                    }
                }
                .padding(.vertical, 4 * s)
                .padding(.horizontal, 8 * s)
                .background(AppConfig.Colors.headerGrey.opacity(0.35))
                .border(AppConfig.Colors.lineGrey, width: 1 * s)

                VStack(alignment: .leading, spacing: 8 * s) {
                    // Top Telemetry Split
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2 * s) {
                            Text("MAINTENANCE TASKS DONE")
                                .font(.system(size: 8 * s, weight: .bold))
                                .foregroundColor(AppConfig.Colors.subtextGrey)

                            HStack(alignment: .firstTextBaseline, spacing: 4 * s) {
                                Text("\(pacing.actualCompleted)")
                                    .font(.system(size: 19 * s, weight: .black, design: .monospaced))
                                    .foregroundColor(.black)
                                Text("/ \(pacing.totalMonthlyQuota) EST.")
                                    .font(.system(size: 9.5 * s, weight: .bold))
                                    .foregroundColor(AppConfig.Colors.subtextGrey)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2 * s) {
                            Text("TIME ELAPSED")
                                .font(.system(size: 8 * s, weight: .bold))
                                .foregroundColor(AppConfig.Colors.subtextGrey)

                            Text("DAY \(pacing.currentDay) OF \(pacing.totalDaysInMonth) (\(Int(pacing.expectedProgressRatio * 100))%)")
                                .font(.system(size: 9.5 * s, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                        }
                    }

                    // Dual Pacing Bars
                    VStack(alignment: .leading, spacing: 4 * s) {
                        // 1. PRIMARY PERFORMANCE BAR (10pt height)
                        GeometryReader { geo in
                            let totalW = geo.size.width
                            let actualRatio = max(0.0, min(1.0, pacing.actualProgressRatio))
                            let expectedRatio = max(0.0, min(1.0, pacing.expectedProgressRatio))

                            HStack(spacing: 0) {
                                if actualRatio >= expectedRatio {
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(width: totalW * CGFloat(expectedRatio))

                                    Rectangle()
                                        .fill(AppConfig.Colors.statusGreen)
                                        .frame(width: totalW * CGFloat(actualRatio - expectedRatio))

                                    Rectangle()
                                        .fill(Color.black.opacity(0.06))
                                        .frame(width: max(0, totalW * CGFloat(1.0 - actualRatio)))
                                } else {
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(width: totalW * CGFloat(actualRatio))

                                    // Display neutral buffer if on pace or leading, orange only if lagging behind closed days
                                    Rectangle()
                                        .fill(pacing.isLeading ? Color.black.opacity(0.18) : AppConfig.Colors.statusOrange.opacity(0.35))
                                        .frame(width: totalW * CGFloat(expectedRatio - actualRatio))

                                    Rectangle()
                                        .fill(Color.black.opacity(0.06))
                                        .frame(width: max(0, totalW * CGFloat(1.0 - expectedRatio)))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 3 * s))
                        }
                        .frame(height: 10 * s)

                        // 2. SECONDARY BASELINE TARGET TRACK (4pt height)
                        GeometryReader { geo in
                            let totalW = geo.size.width
                            let expectedRatio = max(0.0, min(1.0, pacing.expectedProgressRatio))

                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.35))
                                    .frame(width: totalW * CGFloat(expectedRatio))

                                Rectangle()
                                    .fill(Color.black.opacity(0.06))
                                    .frame(width: max(0, totalW * CGFloat(1.0 - expectedRatio)))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 2 * s))
                        }
                        .frame(height: 4 * s)
                    }
                    .padding(.vertical, 2 * s)

                    // Diagnostic Breakdown Subtext
                    HStack {
                        HStack(spacing: 4 * s) {
                            Rectangle()
                                .fill(pacing.isLeading ? AppConfig.Colors.statusGreen : Color.black)
                                .frame(width: 8 * s, height: 8 * s)
                                .clipShape(RoundedRectangle(cornerRadius: 1.5 * s))

                            Text(pacing.deltaLead > 0 ? "LEAD: +\(pacing.deltaLead) EXCESS" : (pacing.isLeading ? "ON PACE: \(Int(pacing.actualProgressRatio * 100))%" : "DEFICIT: \(pacing.deltaLead) TASKS"))
                                .font(.system(size: 8 * s, weight: .bold, design: .monospaced))
                                .foregroundColor(pacing.isLeading ? AppConfig.Colors.statusGreen : AppConfig.Colors.subtextGrey)
                        }

                        Spacer()

                        HStack(spacing: 4 * s) {
                            Rectangle()
                                .fill(Color.black.opacity(0.35))
                                .frame(width: 8 * s, height: 4 * s)
                                .clipShape(RoundedRectangle(cornerRadius: 1 * s))

                            Text("TARGET PACE: \(Int(pacing.expectedProgressRatio * 100))% (DAY \(pacing.currentDay))")
                                .font(.system(size: 8 * s, weight: .bold, design: .monospaced))
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                        }
                    }
                }
                .padding(10 * s)
                .background(Color.white)
                .border(AppConfig.Colors.lineGrey, width: 1 * s)
            }

            // ==========================================
            // BLOCK 3: DAILY BASELINE COMPLIANCE (ROUTINE ADHERENCE)
            // ==========================================
            let compliance = store.baselineCompliance
            VStack(alignment: .leading, spacing: 8 * s) {
                HStack {
                    SectionBadge(text: "DAILY BASELINE COMPLIANCE · \(compliance.activeDaysTracked)D ACTIVE")
                        .foregroundColor(.black)

                    Spacer()

                    HStack(spacing: 3 * s) {
                        Image(systemName: compliance.isNominal ? "checkmark.shield.fill" : (compliance.complianceRatio >= 0.70 ? "checkmark.shield" : "exclamationmark.shield.fill"))
                            .font(.system(size: 8 * s, weight: .black))
                        Text("\(compliance.compliancePercentage)% \(compliance.statusBadgeText)")
                            .font(.system(size: 9.5 * s, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(compliance.complianceRatio >= 0.70 ? AppConfig.Colors.statusGreen : AppConfig.Colors.statusOrange)
                }
                .padding(.vertical, 4 * s)
                .padding(.horizontal, 8 * s)
                .background(AppConfig.Colors.headerGrey.opacity(0.35))
                .border(AppConfig.Colors.lineGrey, width: 1 * s)

                VStack(alignment: .leading, spacing: 8 * s) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2 * s) {
                            Text("ROUTINE ADHERENCE")
                                .font(.system(size: 8 * s, weight: .bold))
                                .foregroundColor(AppConfig.Colors.subtextGrey)

                            HStack(alignment: .firstTextBaseline, spacing: 4 * s) {
                                Text("\(compliance.completedCount)")
                                    .font(.system(size: 19 * s, weight: .black, design: .monospaced))
                                    .foregroundColor(.black)
                                Text("/ \(compliance.expectedCount) EXECUTIONS")
                                    .font(.system(size: 9.5 * s, weight: .bold))
                                    .foregroundColor(AppConfig.Colors.subtextGrey)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2 * s) {
                            Text("DAILY TARGET")
                                .font(.system(size: 8 * s, weight: .bold))
                                .foregroundColor(AppConfig.Colors.subtextGrey)

                            Text("\(compliance.totalBaselineTasks) TASKS / DAY")
                                .font(.system(size: 9.5 * s, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                        }
                    }

                    // Compliance Progress Bar
                    GeometryReader { geo in
                        let totalW = geo.size.width
                        let ratio = max(0.0, min(1.0, compliance.complianceRatio))
                        let barColor: Color = compliance.complianceRatio >= 0.70
                            ? AppConfig.Colors.statusGreen
                            : (compliance.complianceRatio >= 0.50 ? AppConfig.Colors.statusYellow : AppConfig.Colors.statusOrange)

                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(barColor)
                                .frame(width: totalW * CGFloat(ratio))

                            Rectangle()
                                .fill(Color.black.opacity(0.06))
                                .frame(width: max(0, totalW * CGFloat(1.0 - ratio)))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 3 * s))
                    }
                    .frame(height: 8 * s)
                    .padding(.vertical, 2 * s)

                    // Subtext Breakdown
                    HStack {
                        Text("TARGET: ≥80% CONSISTENCY")
                            .font(.system(size: 8 * s, weight: .bold, design: .monospaced))
                            .foregroundColor(AppConfig.Colors.subtextGrey)

                        Spacer()

                        Text("TRACKED OVER \(compliance.activeDaysTracked) \(compliance.activeDaysTracked == 1 ? "DAY" : "DAYS")")
                            .font(.system(size: 8 * s, weight: .bold, design: .monospaced))
                            .foregroundColor(AppConfig.Colors.subtextGrey)
                    }
                }
                .padding(10 * s)
                .background(Color.white)
                .border(AppConfig.Colors.lineGrey, width: 1 * s)
            }

            // ==========================================
            // BLOCK 4: HORIZON QUEUE · NEXT 5 UP
            // ==========================================
            VStack(alignment: .leading, spacing: 8 * s) {
                HStack {
                    SectionBadge(text: "HORIZON QUEUE · NEXT 5 UP")
                        .foregroundColor(.black)
                    Spacer()
                    Text("SHOWING \(topFiveUpcoming.count) OF \(store.upcomingEvents.count)")
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

                                    Text(event.timeAnchor().uppercased())
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
                                Button {
                                    store.completeHorizonTask(id: event.id)
                                } label: {
                                    Label("Mark Complete Early", systemImage: "checkmark.circle")
                                }

                                Button {
                                    store.startEditing(task: event)
                                } label: {
                                    Label("Edit Task", systemImage: "pencil")
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