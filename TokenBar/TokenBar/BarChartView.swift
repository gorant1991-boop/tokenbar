import SwiftUI

struct BarChartView: View {
    let days: [DayStats]

    private var maxCost: Double {
        days.map(\.totalCost).max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(days, id: \.day) { stat in
                VStack(spacing: 2) {
                    if stat.totalCost > 0 {
                        Text("$\(String(format: "%.2f", stat.totalCost))")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    RoundedRectangle(cornerRadius: 3)
                        .fill(stat.day == isoToday() ? Color.accentColor : Color.secondary.opacity(0.5))
                        .frame(
                            width: 26,
                            height: max(4, CGFloat(stat.totalCost / max(maxCost, 0.001)) * 60)
                        )
                    Text(shortDay(stat.day))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 90)
    }

    private func isoToday() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func shortDay(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 3 else { return iso }
        return "\(parts[1])/\(parts[2])"
    }
}
