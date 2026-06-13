import SwiftUI

private let accent = Color(red: 0.2, green: 0.7, blue: 1.0)

struct BarChartView: View {
    let days: [DayStats]

    private var maxCost: Double {
        max(days.map(\.totalCost).max() ?? 0, 0.001)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(days, id: \.day) { stat in
                let isToday = stat.day == isoToday()
                let ratio   = CGFloat(stat.totalCost / maxCost)
                let barH    = max(2, ratio * 56)

                VStack(spacing: 3) {
                    if stat.totalCost > 0 {
                        Text("$\(String(format: "%.2f", stat.totalCost))")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(isToday ? accent : Color.white.opacity(0.3))
                    } else {
                        Text(" ")
                            .font(.system(size: 7))
                    }

                    RoundedRectangle(cornerRadius: 2)
                        .fill(isToday
                            ? accent
                            : Color.white.opacity(0.18))
                        .frame(width: 24, height: barH)

                    Text(shortDay(stat.day))
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(isToday ? accent.opacity(0.8) : Color.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 86)
    }

    private func isoToday() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func shortDay(_ iso: String) -> String {
        let p = iso.split(separator: "-")
        guard p.count == 3 else { return iso }
        return "\(p[1])/\(p[2])"
    }
}
