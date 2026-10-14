// Sources/Views/RightColumn/HistoryTimelineView.swift
import SwiftUI

public struct HistoryTimelineView: View {
    public var records: [HistoryRecord]
    @Environment(\.scaleFactor) private var s

    public init(records: [HistoryRecord]) {
        self.records = records
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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        return sortedDayKeys.map { dayDate in
            let dayOffset = cal.dateComponents([.day], from: dayDate, to: nowStartOfDay).day ?? 0
            let headerText: String
            if dayOffset == 0 {
                headerText = "TODAY · \(dateFormatter.string(from: dayDate).uppercased())"
            } else if dayOffset == 1 {
                headerText = "YESTERDAY · \(dateFormatter.string(from: dayDate).uppercased())"
            } else {
                headerText = "\(dayOffset) DAYS AGO · \(dateFormatter.string(from: dayDate).uppercased())"
            }

            return DayGroup(
                id: dayDate,
                title: headerText,
                records: dict[dayDate] ?? []
            )
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).uppercased()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18 * s) {
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
                        // Date Section Header
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

                        // Chronological Log Items
                        ForEach(group.records) { record in
                            VStack(alignment: .leading, spacing: 3 * s) {
                                HStack {
                                    Text(record.tag.uppercased())
                                        .font(.system(size: 10 * s, weight: .bold))
                                        .tracking(1.0 * s)
                                        .foregroundColor(AppConfig.Colors.subtextGrey)

                                    Spacer()

                                    Text(formatTime(record.completedAt))
                                        .font(.system(size: 9 * s, weight: .bold, design: .monospaced))
                                        .foregroundColor(.black)
                                }

                                Text(record.title)
                                    .font(.system(size: 14 * s, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.top, 1 * s)

                                if !record.note.isEmpty {
                                    Text(record.note)
                                        .font(.system(size: 11 * s, weight: .regular))
                                        .foregroundColor(AppConfig.Colors.subtextGrey)
                                        .lineSpacing(1.5 * s)
                                        .padding(.top, 1 * s)
                                }

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