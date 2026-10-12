import SwiftUI

public struct TelemetryCardView: View {
    public var metrics: [TelemetryMetric]

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionBadge(text: "SYSTEM CADENCE & RUNWAY")
                .foregroundColor(.black)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(metrics) { metric in
                    HStack(spacing: 4) {
                        Text("•")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.black)
                        Text("\(metric.label):")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                        Text(metric.status)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .border(Color.black, width: 1.5)
    }
}