import SwiftUI

struct PopoverView: View {
    @ObservedObject var vm: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.headline)
                    Text(vm.today.day)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.4f", vm.today.totalCost))")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Text("\(formatTokens(vm.today.inputTokens + vm.today.outputTokens)) tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Token breakdown
            HStack(spacing: 16) {
                tokenStat(label: "Input", value: vm.today.inputTokens, color: .blue)
                tokenStat(label: "Output", value: vm.today.outputTokens, color: .green)
            }

            Divider()

            // Model breakdown
            if !vm.models.isEmpty {
                Text("By Model")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(vm.models, id: \.model) { m in
                    HStack {
                        Text(shortModelName(m.model))
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(formatTokens(m.inputTokens + m.outputTokens))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("$\(String(format: "%.4f", m.cost))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 60, alignment: .trailing)
                    }
                }

                Divider()
            }

            // Week chart
            Text("Last 7 Days")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            BarChartView(days: paddedWeek())
                .frame(maxWidth: .infinity)

            Divider()

            // Actions
            HStack {
                Button("Refresh") { vm.refresh() }
                    .font(.caption)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private func tokenStat(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatTokens(value))
                .font(.callout.monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func paddedWeek() -> [DayStats] {
        let existing = Dictionary(uniqueKeysWithValues: vm.week.map { ($0.day, $0) })
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return (0..<7).reversed().map { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let key = fmt.string(from: d)
            return existing[key] ?? DayStats(day: key, totalCost: 0, inputTokens: 0, outputTokens: 0)
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func shortModelName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-20", with: " (20")
            .appending(model.contains("-20") ? ")" : "")
    }
}
