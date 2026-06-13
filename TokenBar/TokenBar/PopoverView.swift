import SwiftUI

private let accent = Color(red: 0.2, green: 0.7, blue: 1.0)
private let bg     = Color(red: 0.08, green: 0.09, blue: 0.12)
private let card   = Color(red: 0.12, green: 0.13, blue: 0.17)
private let dim    = Color.white.opacity(0.35)

struct PopoverView: View {
    @ObservedObject var vm: StatsViewModel

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                statRow
                modelSection
                chartSection
                netSection
                footer
            }
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: – Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(dim)
                    .kerning(1.5)
                Text(vm.today.day)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(dim)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("$\(String(format: "%.4f", vm.today.totalCost))")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                Text("\(formatTokens(vm.today.inputTokens + vm.today.outputTokens)) tokens")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(dim)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: – In / Out

    private var statRow: some View {
        HStack(spacing: 0) {
            statCell(label: "INPUT", value: vm.today.inputTokens, color: accent)
            thinDivider(vertical: true)
            statCell(label: "OUTPUT", value: vm.today.outputTokens, color: Color(red: 0.4, green: 0.9, blue: 0.6))
        }
        .background(card)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func statCell(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(dim)
                .kerning(1.2)
            Text(formatTokens(value))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: – Models

    @ViewBuilder
    private var modelSection: some View {
        if !vm.models.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("BY MODEL")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(dim)
                    .kerning(1.5)

                ForEach(vm.models, id: \.model) { m in
                    modelRow(m)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            thinDivider(vertical: false)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
        }
    }

    private func modelRow(_ m: ModelStats) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent.opacity(0.7))
                .frame(width: 4, height: 4)
            Text(shortModelName(m.model))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            Spacer()
            Text(formatTokens(m.inputTokens + m.outputTokens))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(dim)
            Text("$\(String(format: "%.4f", m.cost))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(accent.opacity(0.9))
                .frame(width: 64, alignment: .trailing)
        }
    }

    // MARK: – Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAST 7 DAYS")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(dim)
                .kerning(1.5)

            BarChartView(days: paddedWeek())
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    // MARK: – Network

    @ViewBuilder
    private var netSection: some View {
        if !vm.netProcs.isEmpty {
            thinDivider(vertical: false)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 8) {
                Text("NETWORK")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(dim)
                    .kerning(1.5)

                ForEach(vm.netProcs.prefix(6)) { p in
                    netRow(p)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
    }

    private func netRow(_ p: NetProcess) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(red: 0.9, green: 0.5, blue: 0.2).opacity(0.7))
                .frame(width: 4, height: 4)
            Text(p.name)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            Spacer()
            Text("↓ \(formatBytes(p.rxBytes))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(dim)
            Text("↑ \(formatBytes(p.txBytes))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(dim)
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let kb = Double(b) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1   { return String(format: "%.1fG", gb) }
        if mb >= 0.1 { return String(format: "%.1fM", mb) }
        if kb >= 1   { return String(format: "%.0fK", kb) }
        return "\(b)B"
    }

    // MARK: – Footer

    private var footer: some View {
        HStack {
            Button(action: { vm.refresh() }) {
                Text("REFRESH")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(dim)
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("QUIT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(Color.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(card)
    }

    // MARK: – Helpers

    private func thinDivider(vertical: Bool) -> some View {
        Color.white.opacity(0.07)
            .frame(
                width:  vertical ? 1 : nil,
                height: vertical ? nil : 1
            )
    }

    private func paddedWeek() -> [DayStats] {
        let existing = Dictionary(uniqueKeysWithValues: vm.week.map { ($0.day, $0) })
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return (0..<7).reversed().map { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let key = fmt.string(from: d)
            return existing[key] ?? DayStats(day: key, totalCost: 0, inputTokens: 0, outputTokens: 0)
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func shortModelName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-20", with: " '")
            + (model.contains("-20") ? "" : "")
    }
}
