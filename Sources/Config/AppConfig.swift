import SwiftUI

/// Central design tokens, window geometry, and storage locations.
public enum AppConfig {
    // MARK: - Window Dimensions & Layout
    public static let baseWidth: CGFloat = 1100
    public static let baseHeight: CGFloat = 850
    public static let splitRatio: CGFloat = 0.65 // Left = 65%, Right = 35%
    
    /// Top padding inset applied to views bordering the top window chrome
    /// to prevent collision with macOS traffic lights when using .hiddenTitleBar.
    public static let windowChromeTopInset: CGFloat = 32

    // MARK: - Color Tokens (Calibrated Low-Strain Swiss Palette)
    public enum Colors {
        // Left Column (Dark Operational Zones)
        public static let blockBlack     = Color(red: 22/255, green: 24/255, blue: 28/255)
        public static let tileBackground = Color(red: 34/255, green: 37/255, blue: 43/255)
        public static let blockSlate     = Color(red: 70/255, green: 76/255, blue: 85/255)

        // Right Column (Softened Horizon Zones)
        public static let panelLight     = Color(red: 240/255, green: 242/255, blue: 245/255)
        public static let headerGrey     = Color(red: 155/255, green: 159/255, blue: 165/255)
        public static let headerBorder   = Color(red: 125/255, green: 130/255, blue: 138/255)
        public static let lineGrey       = Color(red: 195/255, green: 198/255, blue: 202/255)
        public static let subtextGrey    = Color(red: 95/255, green: 100/255, blue: 106/255)
        
        // Status Indicators
        public static let statusGreen    = Color(red: 16/255, green: 185/255, blue: 129/255)
        public static let statusYellow   = Color(red: 234/255, green: 179/255, blue: 8/255)
        public static let statusOrange   = Color(red: 249/255, green: 115/255, blue: 22/255)
        public static let statusRed      = Color(red: 239/255, green: 68/255, blue: 68/255)
    }

    // MARK: - Persistence Paths
    public static var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ChoreDashboard", isDirectory: true)
    }

    public static var storageURL: URL {
        return storageDirectory.appendingPathComponent("state.json")
    }
}

// MARK: - Scaled Metric Environment Injection
private struct ScaleFactorKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    public var scaleFactor: CGFloat {
        get { self[ScaleFactorKey.self] }
        set { self[ScaleFactorKey.self] = newValue }
    }
}