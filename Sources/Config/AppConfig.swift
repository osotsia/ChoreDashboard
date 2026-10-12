import SwiftUI

public enum AppConfig {
    // --- Window Dimensions ---
    public static let windowWidth: CGFloat = 1100
    public static let windowHeight: CGFloat = 850
    public static let splitRatio: CGFloat = 0.65 // Left = 65%, Right = 35%
    
    // --- Color Tokens (Matching the Swiss / E-Ink Palette) ---
    public enum Colors {
        public static let blockBlack = Color(red: 0.0, green: 0.0, blue: 0.0)
        public static let blockSlate = Color(red: 70/255, green: 76/255, blue: 85/255)
        public static let headerGrey = Color(red: 240/255, green: 242/255, blue: 245/255)
        public static let lineGrey   = Color(red: 200/255, green: 200/255, blue: 200/255)
        public static let subtextGrey = Color(red: 100/255, green: 100/255, blue: 100/255)
    }

    // --- Persistence ---
    public static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("ChoreDashboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("state.json")
    }
}