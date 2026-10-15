import Foundation

/// Navigation destinations for the secondary 35% Horizon & Deck panel.
public enum RightPanelTab: String, Codable, CaseIterable, Sendable {
    case status
    case backlog
    case history
    case create
    case edit
}