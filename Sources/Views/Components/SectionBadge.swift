import SwiftUI

public struct SectionBadge: View {
    public let text: String

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .default))
            .tracking(2.0)
    }
}