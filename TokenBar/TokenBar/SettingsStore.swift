import Foundation
import Combine

enum AppLanguage: String, CaseIterable {
    case en = "en"
    case ru = "ru"
    var label: String { self == .en ? "English" : "Русский" }
}

enum PlanType: String, CaseIterable {
    case pro   = "pro"
    case max5  = "max5"
    case max20 = "max20"
    case api   = "api"

    var label: String {
        switch self {
        case .pro:   return "Claude Pro"
        case .max5:  return "Claude Max $100"
        case .max20: return "Claude Max $200"
        case .api:   return "API (pay-per-use)"
        }
    }

    var isSubscription: Bool { self != .api }

    // No hardcoded defaults — Anthropic doesn't publish token limits for subscriptions.
    // User sets their own after observing where they hit rate limits.
    var defaultDailyTokens: Int { 0 }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var plan: PlanType {
        didSet { save("plan", plan.rawValue) }
    }
    // Subscription: custom daily token limit (0 = use plan default)
    @Published var customDailyTokens: Int {
        didSet { save("customDailyTokens", customDailyTokens) }
    }
    // API: daily dollar budget alert threshold
    @Published var apiDailyBudget: Double {
        didSet { save("apiDailyBudget", apiDailyBudget) }
    }
    @Published var appLanguage: AppLanguage {
        didSet { save("appLanguage", appLanguage.rawValue) }
    }
    // Alert thresholds as fractions, e.g. [0.5, 0.75]
    @Published var alertThresholds: [Double] {
        didSet { save("alertThresholds", alertThresholds) }
    }
    // Track which thresholds have already fired today
    @Published var firedAlerts: [String] {
        didSet { save("firedAlerts", firedAlerts) }
    }

    var dailyTokenLimit: Int {
        customDailyTokens > 0 ? customDailyTokens : plan.defaultDailyTokens
    }

    private init() {
        let d = UserDefaults.standard
        appLanguage        = AppLanguage(rawValue: d.string(forKey: "appLanguage") ?? "") ?? .en
        plan               = PlanType(rawValue: d.string(forKey: "plan") ?? "") ?? .pro
        customDailyTokens  = d.integer(forKey: "customDailyTokens")
        apiDailyBudget     = d.object(forKey: "apiDailyBudget") as? Double ?? 10.0
        alertThresholds    = d.array(forKey: "alertThresholds") as? [Double] ?? [0.5, 0.75]
        firedAlerts        = d.array(forKey: "firedAlerts") as? [String] ?? []
        resetFiredAlertsIfNewDay()
    }

    private func save(_ key: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }

    func resetFiredAlertsIfNewDay() {
        let today = isoToday()
        let key   = "firedAlertsDay"
        if UserDefaults.standard.string(forKey: key) != today {
            firedAlerts = []
            UserDefaults.standard.set(today, forKey: key)
        }
    }

    private func isoToday() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
