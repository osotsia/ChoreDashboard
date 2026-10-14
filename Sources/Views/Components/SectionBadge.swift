import SwiftUI

public struct SectionBadge: View {
    public let text: String
    @Environment(\.scaleFactor) private var s

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10 * s, weight: .bold))
            .tracking(1.5 * s)
    }
}