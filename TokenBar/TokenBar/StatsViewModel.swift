import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var today   = DayStats(day: "", totalCost: 0, inputTokens: 0, outputTokens: 0)
    @Published var models: [ModelStats]  = []
    @Published var week:   [DayStats]    = []
    @Published var netProcs: [NetProcess] = []
    @Published var isLoading = false

    private var timer: Timer?
    private let parserScript: String = {
        // Resolve parser relative to the .app bundle
        let bundle = Bundle.main.bundlePath
        // During dev: script lives at ../../proxy/log_parser.py relative to MacOS/
        let candidates = [
            bundle + "/Contents/Resources/log_parser.py",
            (bundle as NSString).deletingLastPathComponent
                .components(separatedBy: "/build/")[0]
                + "/proxy/log_parser.py",
            NSHomeDirectory() + "/projects/tools/tokenbar/proxy/log_parser.py"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
            ?? NSHomeDirectory() + "/projects/tools/tokenbar/proxy/log_parser.py"
    }()

    init() {
        syncAndRefresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in self.syncAndRefresh() }
        }
    }

    func syncAndRefresh() {
        Task {
            await runParser()
            refresh()
        }
    }

    private func runParser() async {
        guard FileManager.default.fileExists(atPath: parserScript) else { return }
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                proc.arguments = [self.parserScript]
                proc.standardOutput = FileHandle.nullDevice
                proc.standardError  = FileHandle.nullDevice
                try? proc.run()
                proc.waitUntilExit()
                cont.resume()
            }
        }
    }

    func refresh() {
        let db = TokenDatabase.shared
        today  = db.todayStats()
        models = db.modelBreakdown()
        week   = db.last7Days()
        checkAlerts()
        Task.detached(priority: .utility) {
            let procs = NetworkMonitor.snapshot()
            await MainActor.run { self.netProcs = Array(procs.prefix(8)) }
        }
    }

    private func checkAlerts() {
        let store = SettingsStore.shared
        store.resetFiredAlertsIfNewDay()
        let fraction: Double
        let valueStr: String
        if store.plan.isSubscription {
            let limit = store.dailyTokenLimit
            guard limit > 0 else { return }
            let used = today.inputTokens + today.outputTokens
            fraction = Double(used) / Double(limit)
            valueStr = formatTokens(used)
        } else {
            guard store.apiDailyBudget > 0 else { return }
            fraction = today.totalCost / store.apiDailyBudget
            valueStr = "$\(String(format: "%.2f", today.totalCost))"
        }
        AlertManager.checkThresholds(fraction: fraction,
                                     isSubscription: store.plan.isSubscription,
                                     value: valueStr)
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }

    var menuBarLabel: String {
        let store = SettingsStore.shared
        if store.plan.isSubscription {
            let t = today.inputTokens + today.outputTokens
            if t >= 1_000_000 { return String(format: "%.1fM▸", Double(t)/1_000_000) }
            if t >= 1_000     { return String(format: "%.0fK▸", Double(t)/1_000) }
            return "\(t)▸"
        }
        return "$\(String(format: "%.3f", today.totalCost))"
    }

    deinit { timer?.invalidate() }
}
