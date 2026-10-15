import SwiftUI

/// High-visibility 4-segment operational buffer indicator with hazard alerts.
public struct HealthRunwayGauge: View {
    public let state: TaskHealthState
    public let s: CGFloat

    public init(state: TaskHealthState, s: CGFloat) {
        self.state = state
        self.s = s
    }

    private var filledSegments: Int {
        switch state {
        case .good:    return 4 // 100%
        case .notYet:  return 3 // 75%
        case .halfway: return 2 // 50%
        case .due:     return 1 // 25%
        case .overdue: return 0 // 0%
        }
    }

    private var stateColor: Color {
        switch state {
        case .good:    return AppConfig.Colors.statusGreen
        case .notYet:  return Color(red: 132/255, green: 204/255, blue: 22/255)
        case .halfway: return AppConfig.Colors.statusYellow
        case .due:     return AppConfig.Colors.statusOrange
        case .overdue: return AppConfig.Colors.statusRed
        }
    }

    private var runwayLabel: String {
        switch state {
        case .good:    return "RUNWAY: 100% (HEALTHY BUFFER)"
        case .notYet:  return "RUNWAY: 75% (MID-CYCLE BUFFER)"
        case .halfway: return "RUNWAY: 50% (HALFWAY RUNWAY)"
        case .due:     return "RUNWAY: 25% (CYCLE EXHAUSTED)"
        case .overdue: return "RUNWAY: 0% (DECAY HAZARD)"
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5 * s) {
            HStack {
                Text(runwayLabel)
                    .font(.system(size: 8.5 * s, weight: .black, design: .monospaced))
                    .tracking(0.8 * s)
                    .foregroundColor(stateColor)

                Spacer()

                if state == .overdue {
                    HStack(spacing: 3 * s) {
                        Image(systemName: "radiation")
                            .font(.system(size: 11 * s, weight: .black))
                            .foregroundColor(stateColor)
                        Text("DECAY HAZARD")
                            .font(.system(size: 8 * s, weight: .black))
                            .foregroundColor(stateColor)
                    }
                }
            }

            HStack(spacing: 3 * s) {
                ForEach(0..<4, id: \.self) { index in
                    let isFilled = index < filledSegments
                    RoundedRectangle(cornerRadius: 1.5 * s)
                        .fill(isFilled ? stateColor : stateColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 1.5 * s)
                                .strokeBorder(isFilled ? stateColor.opacity(0.4) : Color.clear, lineWidth: 0.5 * s)
                        )
                }
            }
            .padding(3.5 * s)
            .frame(height: 18 * s)
            .background(stateColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 4 * s))
            .overlay(
                RoundedRectangle(cornerRadius: 4 * s)
                    .strokeBorder(stateColor.opacity(0.75), lineWidth: 1.5 * s)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: state)
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