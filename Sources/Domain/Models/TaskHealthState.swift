import Foundation

/// 5-Tier operational runway state evaluated against a task's cadence and due date.
public enum TaskHealthState: String, CaseIterable, Codable, Sendable {
    case good = "GOOD"         // 100% Runway
    case notYet = "NOT YET"     // 75% Runway
    case halfway = "HALF"       // 50% Runway
    case due = "DUE"           // 25% Runway (Runway exhausted / due soon)
    case overdue = "OVERDUE"   // 0% Runway (Decay Hazard)

    public var subtitle: String {
        switch self {
        case .good:    return "FRESH"
        case .notYet:  return "RUNNING"
        case .halfway: return "MIDWAY"
        case .due:     return "IMMINENT"
        case .overdue: return "URGENT"
        }
    }
}