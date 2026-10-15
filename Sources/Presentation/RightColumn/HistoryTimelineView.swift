// Sources/Views/RightColumn/HistoryTimelineView.swift
import SwiftUI

public struct HistoryTimelineView: View {
    public var records: [HistoryRecord]
    public var onExport: (() -> Void)? = nil
    @Environment(\.scaleFactor) private var s

    private static let dayDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }()

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df
    }()

    public init(records: [HistoryRecord], onExport: (() -> Void)? = nil) {
        self.records = records
        self.onExport = onExport
    }

    private struct DayGroup: Identifiable {
        let id: Date
        let title: String
        let records: [HistoryRecord]
    }

    private var groupedDays: [DayGroup] {
        let cal = Calendar.current
        let sorted = records.sorted { $0.completedAt > $1.completedAt }
        let dict = Dictionary(grouping: sorted) { record in
            cal.startOfDay(for: record.completedAt)
        }

        let sortedDayKeys = dict.keys.sorted(by: >)
        let nowStartOfDay = cal.startOfDay(for: Date())

        return sortedDayKeys.map { dayDate in
            let dayOffset = cal.dateComponents([.day], from: dayDate, to: nowStartOfDay).day ?? 0
            let headerText: String
            if dayOffset == 0 {
                headerText = "TODAY · \(Self.dayDateFormatter.string(from: dayDate).uppercased())"
            } else if dayOffset == 1 {
                headerText = "YESTERDAY · \(Self.dayDateFormatter.string(from: dayDate).uppercased())"
            } else {
                headerText = "\(dayOffset) DAYS AGO · \(Self.dayDateFormatter.string(from: dayDate).uppercased())"
            }

            return DayGroup(
                id: dayDate,
                title: headerText,
                records: dict[dayDate] ?? []
            )
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18 * s) {
            // ==========================================
            // EXPORT DATA UTILITY BANNER
            // ==========================================
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3 * s) {
                    Text("DATA BACKUP & PORTABILITY")
                        .font(.system(size: 9.5 * s, weight: .black, design: .monospaced))
                        .tracking(1.1 * s)
                        .foregroundColor(.black)

                    Text("Export complete system state, tasks, and history to a JSON file.")
                        .font(.system(size: 8.5 * s, weight: .bold))
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                }

                Spacer()

                Button {
                    onExport?()
                } label: {
                    HStack(spacing: 5 * s) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11 * s, weight: .bold))
                        Text("EXPORT JSON")
                            .font(.system(size: 9.5 * s, weight: .black, design: .monospaced))
                            .tracking(0.6 * s)
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 10 * s)
                    .frame(height: 30 * s)
                    .background(Color.white)
                    .overlay(
                        Rectangle()
                            .strokeBorder(AppConfig.Colors.lineGrey, lineWidth: 1 * s)
                    )
                }
                .buttonStyle(TactileButtonStyle())
            }
            .padding(10 * s)
            .background(Color.white)
            .border(AppConfig.Colors.lineGrey, width: 1 * s)

            // ==========================================
            // TIMELINE GROUPS
            // ==========================================
            if groupedDays.isEmpty {
                VStack(spacing: 8 * s) {
                    Text("NO RECORDED HISTORY")
                        .font(.system(size: 11 * s, weight: .bold))
                        .tracking(1.5 * s)
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                    Text("Jobs marked completed will appear here chronologically.")
                        .font(.system(size: 12 * s, weight: .regular))
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40 * s)
            } else {
                ForEach(groupedDays) { group in
                    VStack(alignment: .leading, spacing: 6 * s) {
                        HStack {
                            Text(group.title)
                                .font(.system(size: 10 * s, weight: .bold))
                                .tracking(1.5 * s)
                                .foregroundColor(.black)
                            Spacer()
                            Text("\(group.records.count) DONE")
                                .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
                                .tracking(1.0 * s)
                                .foregroundColor(AppConfig.Colors.subtextGrey)
                        }
                        .padding(.vertical, 4 * s)
                        .padding(.horizontal, 8 * s)
                        .background(AppConfig.Colors.headerGrey.opacity(0.35))
                        .border(AppConfig.Colors.lineGrey, width: 1 * s)

                        ForEach(group.records) { record in
                            VStack(alignment: .leading, spacing: 3 * s) {
                                HStack {
                                    Text(record.tag.uppercased())
                                        .font(.system(size: 10 * s, weight: .bold))
                                        .tracking(1.0 * s)
                                        .foregroundColor(AppConfig.Colors.subtextGrey)
                                    Spacer()
                                    Text(Self.timeFormatter.string(from: record.completedAt).uppercased())
                                        .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
                                        .foregroundColor(.black)
                                }

                                Text(record.title)
                                    .font(.system(size: 14 * s, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.top, 1 * s)

                                Rectangle()
                                    .fill(AppConfig.Colors.lineGrey)
                                    .frame(height: 0.8 * s)
                                    .padding(.top, 6 * s)
                            }
                            .padding(.vertical, 4 * s)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}