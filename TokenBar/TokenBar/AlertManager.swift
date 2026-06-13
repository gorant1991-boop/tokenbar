import Foundation
import UserNotifications

enum AlertManager {

    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Call after every refresh with current usage fraction (0…1+).
    static func checkThresholds(fraction: Double, isSubscription: Bool, value: String) {
        let store     = SettingsStore.shared
        let today     = isoToday()

        for threshold in store.alertThresholds.sorted() {
            guard fraction >= threshold else { continue }
            let alertID = "\(today)-\(threshold)"
            guard !store.firedAlerts.contains(alertID) else { continue }

            let pct  = Int(threshold * 100)
            let title: String
            let body:  String

            if isSubscription {
                title = "\(pct)% of daily token limit"
                body  = "Used \(value) tokens today."
            } else {
                title = "\(pct)% of daily budget"
                body  = "Spent \(value) of your daily API budget."
            }

            send(id: alertID, title: title, body: body)
            store.firedAlerts.append(alertID)
        }
    }

    // MARK: –

    private static func send(id: String, title: String, body: String) {
        let content        = UNMutableNotificationContent()
        content.title      = title
        content.body       = body
        content.sound      = .default
        let request = UNNotificationRequest(identifier: id,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func isoToday() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
