import SwiftUI

public struct TelemetryCardView: View {
    public var metrics: [TelemetryMetric]
    @Environment(\.scaleFactor) private var s

    public var body: some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            Text("SYSTEM CADENCE & RUNWAY")
                .font(.system(size: 11 * s, weight: .bold))
                .tracking(2.0 * s)
                .foregroundColor(.black)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6 * s) {
                ForEach(metrics) { metric in
                    HStack(spacing: 4 * s) {
                        Text("•")
                            .font(.system(size: 11 * s, weight: .black))
                            .foregroundColor(.black)
                        Text("\(metric.label):")
                            .font(.system(size: 11 * s, weight: .bold))
                            .foregroundColor(.black)
                        Text(metric.status)
                            .font(.system(size: 11 * s, weight: .regular))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12 * s)
        .background(Color.white)
        .border(Color.black, width: 1.5 * s)
    }
}