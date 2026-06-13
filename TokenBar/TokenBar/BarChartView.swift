import SwiftUI

private let accent = Color(red: 0.2, green: 0.7, blue: 1.0)

struct BarChartView: View {
    let days: [DayStats]
    var showTokens: Bool = false

    private var maxValue: Double {
        if showTokens {
            return max(Double(days.map { $0.inputTokens + $0.outputTokens }.max() ?? 0), 1)
        }
        return max(days.map(\.totalCost).max() ?? 0, 0.001)
    }

    private func value(for stat: DayStats) -> Double {
        showTokens ? Double(stat.inputTokens + stat.outputTokens) : stat.totalCost
    }

    private func label(for stat: DayStats) -> String {
        let v = value(for: stat)
        if v == 0 { return "" }
        if showTokens {
            let t = Int(v)
            if t >= 1_000_000 { return String(format: "%.1fM", Double(t)/1_000_000) }
            if t >= 1_000     { return String(format: "%.0fK", Double(t)/1_000) }
            return "\(t)"
        }
        return "$\(String(format: "%.2f", v))"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(days, id: \.day) { stat in
                let isToday = stat.day == isoToday()
                let ratio   = CGFloat(value(for: stat) / maxValue)
                let barH    = max(2, ratio * 56)

                VStack(spacing: 3) {
                    let lbl = label(for: stat)
                    if !lbl.isEmpty {
                        Text(lbl)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(isToday ? accent : Color.white.opacity(0.3))
                    } else {
                        Text(" ").font(.system(size: 7))
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
