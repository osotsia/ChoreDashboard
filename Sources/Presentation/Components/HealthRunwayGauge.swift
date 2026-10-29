import SwiftUI

/// Tactile segmented operational runway instrument with interactive scrub and direct level selection.
public struct HealthRunwayGauge: View {
    public let state: TaskHealthState
    public let s: CGFloat
    public let segmentCount: Int
    public let filledSegments: Int
    public let totalDays: Int
    public let daysRemaining: Int
    public let targetDate: Date?
    public let isOverdue: Bool
    public let isInteractive: Bool
    public let onSelectLevel: ((Int) -> Void)?
    public let onToggleOverdue: (() -> Void)?

    private static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }()

    public init(
        state: TaskHealthState,
        s: CGFloat,
        segmentCount: Int = 4,
        filledSegments: Int? = nil,
        totalDays: Int = 30,
        daysRemaining: Int? = nil,
        targetDate: Date? = nil,
        isOverdue: Bool? = nil,
        isInteractive: Bool = false,
        onSelectLevel: ((Int) -> Void)? = nil,
        onToggleOverdue: (() -> Void)? = nil
    ) {
        self.state = state
        self.s = s
        let safeCount = max(1, segmentCount)
        self.segmentCount = safeCount
        self.totalDays = max(1, totalDays)
        self.targetDate = targetDate
        self.isInteractive = isInteractive
        self.onSelectLevel = onSelectLevel
        self.onToggleOverdue = onToggleOverdue

        let resolvedOverdue = isOverdue ?? (state == .overdue)
        self.isOverdue = resolvedOverdue

        if let filled = filledSegments {
            self.filledSegments = max(0, min(safeCount, filled))
        } else {
            switch state {
            case .good:    self.filledSegments = safeCount
            case .notYet:  self.filledSegments = max(1, Int(round(Double(safeCount) * 0.75)))
            case .halfway: self.filledSegments = max(1, safeCount / 2)
            case .due:     self.filledSegments = safeCount == 4 ? 1 : max(0, Int(round(Double(safeCount) * 0.25)))
            case .overdue: self.filledSegments = 0
            }
        }

        if let remaining = daysRemaining {
            self.daysRemaining = remaining
        } else {
            let ratio = Double(self.filledSegments) / Double(safeCount)
            self.daysRemaining = Int(round(Double(self.totalDays) * ratio))
        }
    }

    private var stateColor: Color {
        if isOverdue { return AppConfig.Colors.statusRed }
        switch state {
        case .good:    return AppConfig.Colors.statusGreen
        case .notYet:  return Color(red: 132/255, green: 204/255, blue: 22/255)
        case .halfway: return AppConfig.Colors.statusYellow
        case .due:     return AppConfig.Colors.statusOrange
        case .overdue: return AppConfig.Colors.statusRed
        }
    }

    private var runwayHeadline: String {
        if isOverdue {
            return "RUNWAY: 0% · DECAY HAZARD"
        }
        if filledSegments == 0 {
            return "RUNWAY: 0% · DUE TODAY"
        }
        let ratio = Double(filledSegments) / Double(segmentCount)
        let percentage = Int(round(ratio * 100))
        return "RUNWAY: \(percentage)% (\(state.rawValue))"
    }

    private var timeRemainingDetail: String {
        if isOverdue {
            return "OVERDUE (-1D)"
        }
        if daysRemaining <= 0 {
            return "DUE TODAY"
        }
        if daysRemaining == 1 {
            if let date = targetDate {
                return "1 DAY (\(Self.shortDateFormatter.string(from: date).uppercased()))"
            }
            return "IN 1 DAY"
        }
        if let date = targetDate {
            return "\(daysRemaining) DAYS (\(Self.shortDateFormatter.string(from: date).uppercased()))"
        }
        return "IN \(daysRemaining) DAYS"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5 * s) {
            // Live Telemetry Header
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 4 * s) {
                    Text(runwayHeadline)
                        .font(.system(size: 8.5 * s, weight: .black, design: .monospaced))
                        .tracking(0.8 * s)
                        .foregroundColor(stateColor)

                    if isOverdue {
                        Image(systemName: "radiation")
                            .font(.system(size: 10 * s, weight: .black))
                            .foregroundColor(stateColor)
                    }
                }

                Spacer()

                Text(timeRemainingDetail)
                    .font(.system(size: 8.5 * s, weight: .bold, design: .monospaced))
                    .foregroundColor(isOverdue ? AppConfig.Colors.statusRed : AppConfig.Colors.subtextGrey)
            }

            // Segmented Mechanical Level Track
            GeometryReader { geometry in
                let totalW = geometry.size.width
                let count = max(1, segmentCount)
                let spacing: CGFloat = 2.5 * s
                let innerPadding: CGFloat = 3 * s

                HStack(spacing: spacing) {
                    ForEach(0..<count, id: \.self) { index in
                        let isFilled = !isOverdue && (index < filledSegments)
                        RoundedRectangle(cornerRadius: 1.5 * s)
                            .fill(isFilled ? stateColor : (isOverdue ? stateColor.opacity(0.12) : Color.black.opacity(0.06)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 1.5 * s)
                                    .strokeBorder(isFilled ? stateColor.opacity(0.4) : Color.clear, lineWidth: 0.5 * s)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(innerPadding)
                .background(isOverdue ? AppConfig.Colors.statusRed.opacity(0.06) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4 * s))
                .overlay(
                    RoundedRectangle(cornerRadius: 4 * s)
                        .strokeBorder(isOverdue ? AppConfig.Colors.statusRed : Color.black.opacity(0.8), lineWidth: 1.5 * s)
                )
                .contentShape(Rectangle())
                .highPriorityGesture(
                    isInteractive ? DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = max(0.0, min(1.0, value.location.x / totalW))
                            let level = Int(round(fraction * Double(count)))
                            onSelectLevel?(level)
                        }
                    : nil
                )
            }
            .frame(height: 24 * s)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: filledSegments)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOverdue)

            // Micro Tick Readout
            if isInteractive {
                HStack {
                    Text("0% (TODAY)")
                        .font(.system(size: 7.5 * s, weight: .bold, design: .monospaced))
                        .foregroundColor(AppConfig.Colors.subtextGrey)

                    Spacer()

                    Text("LEVEL \(filledSegments)/\(segmentCount)")
                        .font(.system(size: 7.5 * s, weight: .bold, design: .monospaced))
                        .foregroundColor(stateColor)

                    Spacer()

                    Text("100% (\(totalDays)D)")
                        .font(.system(size: 7.5 * s, weight: .bold, design: .monospaced))
                        .foregroundColor(AppConfig.Colors.subtextGrey)
                }
                .padding(.top, 1 * s)
            }
        }
        .padding(.vertical, 2 * s)
    }
}

/// Tactile radio tab for selecting recurrence types and deadlines.
public struct CadenceTypeTab: View {
    public let title: String
    public let isSelected: Bool
    public let s: CGFloat
    public let action: () -> Void

    public init(title: String, isSelected: Bool, s: CGFloat, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.s = s
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8.5 * s, weight: isSelected ? .black : .bold))
                .tracking(0.6 * s)
                .padding(.horizontal, 8 * s)
                .padding(.vertical, 4 * s)
                .background(isSelected ? Color.white : Color.clear)
                .foregroundColor(isSelected ? .black : AppConfig.Colors.subtextGrey)
                .clipShape(RoundedRectangle(cornerRadius: 4 * s))
                .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

/// Button style providing tactile press feedback.
public struct SubtlePressStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.06) : Color.clear)
    }
}