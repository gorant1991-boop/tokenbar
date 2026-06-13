import SwiftUI

private let accent  = Color(red: 0.2, green: 0.7, blue: 1.0)
private let green   = Color(red: 0.4, green: 0.9, blue: 0.6)
private let orange  = Color(red: 1.0, green: 0.6, blue: 0.2)
private let red     = Color(red: 1.0, green: 0.35, blue: 0.35)
private let bg      = Color(red: 0.08, green: 0.09, blue: 0.12)
private let card    = Color(red: 0.12, green: 0.13, blue: 0.17)
private let dim     = Color.white.opacity(0.35)

struct PopoverView: View {
    @ObservedObject var vm: StatsViewModel
    @ObservedObject private var store = SettingsStore.shared
    @State private var showSettings = false

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            if showSettings {
                SettingsView(isShowing: $showSettings)
            } else {
                mainView
            }
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: – Main

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            progressSection
            statRow
            modelSection
            chartSection
            netSection
            footer
        }
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
                if store.plan.isSubscription {
                    Text(formatTokens(vm.today.inputTokens + vm.today.outputTokens))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(progressColor)
                    Text("tokens used")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(dim)
                } else {
                    Text("$\(String(format: "%.4f", vm.today.totalCost))")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(progressColor)
                    Text("\(formatTokens(vm.today.inputTokens + vm.today.outputTokens)) tokens")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(dim)
                }
            }
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(dim)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    // MARK: – Progress bar

    @ViewBuilder
    private var progressSection: some View {
        let fraction = usageFraction
        let hasLimit = store.plan.isSubscription ? store.dailyTokenLimit > 0 : store.apiDailyBudget > 0
        if hasLimit && (fraction > 0 || store.plan == .api) {
            VStack(alignment: .leading, spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(progressColor)
                            .frame(width: geo.size.width * min(CGFloat(fraction), 1.0), height: 5)

                        // Threshold markers
                        ForEach(store.alertThresholds, id: \.self) { t in
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 1, height: 5)
                                .offset(x: geo.size.width * CGFloat(t) - 0.5)
                        }
                    }
                }
                .frame(height: 5)

                HStack {
                    Text(progressLabel)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(progressColor.opacity(0.8))
                    Spacer()
                    Text(limitLabel)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(dim)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
    }

    // MARK: – In/Out cards

    private var statRow: some View {
        HStack(spacing: 0) {
            statCell(label: "INPUT",  value: vm.today.inputTokens,  color: accent)
            thinDivider(vertical: true)
            statCell(label: "OUTPUT", value: vm.today.outputTokens, color: green)
        }
        .background(card)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func statCell(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(dim).kerning(1.2)
            Text(formatTokens(value))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: – Models

    @ViewBuilder
    private var modelSection: some View {
        if !vm.models.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("BY MODEL")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(dim).kerning(1.5)
                ForEach(vm.models, id: \.model) { m in modelRow(m) }
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
            thinDivider(vertical: false).padding(.horizontal, 18).padding(.bottom, 14)
        }
    }

    private func modelRow(_ m: ModelStats) -> some View {
        let totalTok = vm.today.inputTokens + vm.today.outputTokens
        let modelTok = m.inputTokens + m.outputTokens
        let pct = totalTok > 0 ? Int(Double(modelTok) / Double(totalTok) * 100) : 0

        return HStack(spacing: 6) {
            Circle().fill(accent.opacity(0.7)).frame(width: 4, height: 4)
            Text(shortModelName(m.model))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75)).lineLimit(1)
            Spacer()
            Text(formatTokens(modelTok))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(dim)
            if store.plan.isSubscription {
                Text("\(pct)%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(accent.opacity(0.7))
                    .frame(width: 36, alignment: .trailing)
            } else {
                Text("$\(String(format: "%.4f", m.cost))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(accent.opacity(0.9))
                    .frame(width: 64, alignment: .trailing)
            }
        }
    }

    // MARK: – Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAST 7 DAYS")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(dim).kerning(1.5)
            BarChartView(days: paddedWeek(), showTokens: store.plan.isSubscription)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18).padding(.bottom, 14)
    }

    // MARK: – Network

    @ViewBuilder
    private var netSection: some View {
        if !vm.netProcs.isEmpty {
            thinDivider(vertical: false).padding(.horizontal, 18).padding(.bottom, 14)
            VStack(alignment: .leading, spacing: 8) {
                Text("NETWORK")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(dim).kerning(1.5)
                ForEach(vm.netProcs.prefix(5)) { p in netRow(p) }
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
        }
    }

    private func netRow(_ p: NetProcess) -> some View {
        HStack(spacing: 6) {
            Circle().fill(orange.opacity(0.7)).frame(width: 4, height: 4)
            Text(p.name)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75)).lineLimit(1)
            Spacer()
            Text("↓\(formatBytes(p.rxBytesPerSec))/s")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(dim)
            Text("↑\(formatBytes(p.txBytesPerSec))/s")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(dim)
        }
    }

    // MARK: – Footer

    private var footer: some View {
        HStack {
            Button(action: { vm.syncAndRefresh() }) {
                Text("REFRESH")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .kerning(1.2).foregroundStyle(dim)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(store.plan.label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(dim.opacity(0.6))
            Spacer()
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("QUIT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .kerning(1.2).foregroundStyle(Color.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(card)
    }

    // MARK: – Progress logic

    private var usageFraction: Double {
        if store.plan.isSubscription {
            let limit = store.dailyTokenLimit
            guard limit > 0 else { return 0 }
            return Double(vm.today.inputTokens + vm.today.outputTokens) / Double(limit)
        } else {
            guard store.apiDailyBudget > 0 else { return 0 }
            return vm.today.totalCost / store.apiDailyBudget
        }
    }

    private var progressColor: Color {
        let f = usageFraction
        if f >= 0.9 { return red }
        if f >= (store.alertThresholds.max() ?? 0.75) { return orange }
        return accent
    }

    private var progressLabel: String {
        let f = usageFraction
        return String(format: "%.0f%%", min(f * 100, 100))
    }

    private var limitLabel: String {
        if store.plan.isSubscription {
            return "/ \(formatTokens(store.dailyTokenLimit))"
        } else {
            return "/ $\(String(format: "%.2f", store.apiDailyBudget))"
        }
    }

    // MARK: – Helpers

    private func thinDivider(vertical: Bool) -> some View {
        Color.white.opacity(0.07)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }

    private func paddedWeek() -> [DayStats] {
        let existing = Dictionary(uniqueKeysWithValues: vm.week.map { ($0.day, $0) })
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return (0..<7).reversed().map { offset in
            let d   = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let key = fmt.string(from: d)
            return existing[key] ?? DayStats(day: key, totalCost: 0, inputTokens: 0, outputTokens: 0)
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    private func formatBytes(_ b: Int64) -> String {
        let mb = Double(b)/1_048_576
        if mb >= 1024 { return String(format: "%.1fG", mb/1024) }
        if mb >= 0.1  { return String(format: "%.1fM", mb) }
        return String(format: "%.0fK", Double(b)/1024)
    }

    private func shortModelName(_ model: String) -> String {
        var s = model.replacingOccurrences(of: "claude-", with: "")
        // Strip date suffix: haiku-4-5-20251001 → haiku-4-5
        if let range = s.range(of: #"-\d{8}$"#, options: .regularExpression) {
            s.removeSubrange(range)
        }
        return s
    }
}
