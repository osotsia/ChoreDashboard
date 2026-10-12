import SwiftUI

public enum AppConfig {
    // --- Window Dimensions ---
    public static let baseWidth: CGFloat = 1100
    public static let baseHeight: CGFloat = 850
    public static let splitRatio: CGFloat = 0.65 // Left = 65%, Right = 35%
    public static let aspectRatio = CGSize(width: 1100, height: 850)

    // --- Color Tokens (Calibrated Low-Strain Swiss Palette) ---
    public enum Colors {
        // Left Column (Dark Operational Zones)
        public static let blockBlack     = Color(red: 22/255, green: 24/255, blue: 28/255)   // Lightened from pitch black
        public static let tileBackground = Color(red: 34/255, green: 37/255, blue: 43/255)   // Elevated tile surface
        public static let blockSlate     = Color(red: 70/255, green: 76/255, blue: 85/255)   // Continuous baseline slate

        // Right Column (Softened Horizon Zones)
        public static let panelLight     = Color(red: 240/255, green: 242/255, blue: 245/255) // Softened canvas (replaces harsh white)
        public static let headerGrey     = Color(red: 155/255, green: 159/255, blue: 165/255) // Midpoint: (240 + 70)/2, (242 + 76)/2, (245 + 85)/2
        public static let headerBorder   = Color(red: 125/255, green: 130/255, blue: 138/255) // Header bottom divider
        public static let lineGrey       = Color(red: 195/255, green: 198/255, blue: 202/255) // Timeline rule divider
        public static let subtextGrey    = Color(red: 95/255, green: 100/255, blue: 106/255)
    }

    // --- Persistence ---
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