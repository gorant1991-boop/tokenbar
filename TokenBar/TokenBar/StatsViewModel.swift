import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var today = DayStats(day: "", totalCost: 0, inputTokens: 0, outputTokens: 0)
    @Published var models: [ModelStats] = []
    @Published var week: [DayStats] = []

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task { @MainActor in self.refresh() }
        }
    }

    func refresh() {
        let db = TokenDatabase.shared
        today  = db.todayStats()
        models = db.modelBreakdown()
        week   = db.last7Days()
    }

    var menuBarLabel: String {
        "$\(String(format: "%.3f", today.totalCost))"
    }

    deinit { timer?.invalidate() }
}
