// Sources/Views/RightColumn/HistoryTimelineView.swift
import SwiftUI

public struct HistoryTimelineView: View {
    public var records: [HistoryRecord]
    public var onExport: (() -> Void)? = nil
    public var onLoad: (() -> Void)? = nil
    public var onClear: (() -> Void)? = nil
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

    public init(
        records: [HistoryRecord],
        onExport: (() -> Void)? = nil,
        onLoad: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil
    ) {
        self.records = records
        self.onExport = onExport
        self.onLoad = onLoad
        self.onClear = onClear
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
            // DATA MANAGEMENT UTILITY BANNER
            // ==========================================
            VStack(alignment: .leading, spacing: 8 * s) {
                VStack(alignment: .leading, spacing: 2 * s) {
                    Text("DATA ARCHIVE & RECOVERY")
                        .font(.system(size: 9.5 * s, weight: .black, design: .monospaced))
                        .tracking(1.1 * s)
                        .foregroundColor(.black)

                    Text("Export state to JSON, restore previous archives, or clear system.")
                        .font(.system(size: 8.5 * s, weight: .bold))
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                }

                HStack(spacing: 6 * s) {
                    // Export JSON
                    Button {
                        onExport?()
                    } label: {
                        HStack(spacing: 4 * s) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 10 * s, weight: .bold))
                            Text("EXPORT")
                                .font(.system(size: 9 * s, weight: .black, design: .monospaced))
                                .tracking(0.5 * s)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28 * s)
                        .background(Color.white)
                        .overlay(
                            Rectangle()
                                .strokeBorder(AppConfig.Colors.lineGrey, lineWidth: 1 * s)
                        )
                    }
                    .buttonStyle(TactileButtonStyle())

                    // Load JSON
                    Button {
                        onLoad?()
                    } label: {
                        HStack(spacing: 4 * s) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10 * s, weight: .bold))
                            Text("LOAD")
                                .font(.system(size: 9 * s, weight: .black, design: .monospaced))
                                .tracking(0.5 * s)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28 * s)
                        .background(Color.white)
                        .overlay(
                            Rectangle()
                                .strokeBorder(AppConfig.Colors.lineGrey, lineWidth: 1 * s)
                        )
                    }
                    .buttonStyle(TactileButtonStyle())

                    // Clear All Data
                    Button {
                        onClear?()
                    } label: {
                        HStack(spacing: 4 * s) {
                            Image(systemName: "trash")
                                .font(.system(size: 10 * s, weight: .bold))
                            Text("CLEAR ALL")
                                .font(.system(size: 9 * s, weight: .black, design: .monospaced))
                                .tracking(0.5 * s)
                        }
                        .foregroundColor(AppConfig.Colors.statusRed)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28 * s)
                        .background(Color.white)
                        .overlay(
                            Rectangle()
                                .strokeBorder(AppConfig.Colors.lineGrey, lineWidth: 1 * s)
                        )
                    }
                    .buttonStyle(TactileButtonStyle())
                }
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