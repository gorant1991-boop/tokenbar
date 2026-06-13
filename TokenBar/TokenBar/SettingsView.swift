import SwiftUI

private let accent = Color(red: 0.2, green: 0.7, blue: 1.0)
private let bg     = Color(red: 0.08, green: 0.09, blue: 0.12)
private let card   = Color(red: 0.12, green: 0.13, blue: 0.17)
private let dim    = Color.white.opacity(0.35)

struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @Binding var isShowing: Bool

    @State private var customTokensStr = ""
    @State private var budgetStr       = ""
    @State private var threshold1Str   = ""
    @State private var threshold2Str   = ""

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                settingsHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        planSection
                        limitSection
                        alertSection
                    }
                    .padding(18)
                }
                saveButton
            }
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { loadFromStore() }
    }

    // MARK: – Header

    private var settingsHeader: some View {
        HStack {
            Button(action: { isShowing = false }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("SETTINGS")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(dim)
                .kerning(1.5)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: – Plan

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("PLAN")
            VStack(spacing: 6) {
                ForEach(PlanType.allCases, id: \.rawValue) { p in
                    planRow(p)
                }
            }
        }
    }

    private func planRow(_ p: PlanType) -> some View {
        let selected = store.plan == p
        return Button(action: { store.plan = p }) {
            HStack {
                Circle()
                    .strokeBorder(selected ? accent : dim, lineWidth: 1.5)
                    .background(Circle().fill(selected ? accent : Color.clear))
                    .frame(width: 10, height: 10)
                Text(p.label)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(selected ? .white : dim)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? card : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: – Limit

    @ViewBuilder
    private var limitSection: some View {
        if store.plan.isSubscription {
            VStack(alignment: .leading, spacing: 10) {
                label("DAILY TOKEN LIMIT")
                HStack {
                    field($customTokensStr, placeholder: "\(formatTokens(store.plan.defaultDailyTokens)) (plan default)")
                    Text("tokens")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(dim)
                }
                Text("Leave blank to use plan default")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(dim.opacity(0.7))
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                label("DAILY BUDGET ALERT")
                HStack {
                    Text("$")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(dim)
                    field($budgetStr, placeholder: "10.00")
                    Text("USD / day")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(dim)
                }
            }
        }
    }

    // MARK: – Alerts

    private var alertSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("ALERT THRESHOLDS")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FIRST")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(dim)
                        .kerning(1)
                    HStack {
                        field($threshold1Str, placeholder: "50")
                            .frame(width: 50)
                        Text("%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(dim)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("SECOND")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(dim)
                        .kerning(1)
                    HStack {
                        field($threshold2Str, placeholder: "75")
                            .frame(width: 50)
                        Text("%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(dim)
                    }
                }
            }
        }
    }

    // MARK: – Save

    private var saveButton: some View {
        Button(action: saveToStore) {
            Text("SAVE")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(card)
    }

    // MARK: – Helpers

    private func loadFromStore() {
        customTokensStr = store.customDailyTokens > 0 ? "\(store.customDailyTokens)" : ""
        budgetStr       = store.apiDailyBudget > 0 ? String(format: "%.2f", store.apiDailyBudget) : ""
        let t = store.alertThresholds.sorted()
        threshold1Str   = t.count > 0 ? "\(Int((t[0]) * 100))" : "50"
        threshold2Str   = t.count > 1 ? "\(Int((t[1]) * 100))" : "75"
    }

    private func saveToStore() {
        store.customDailyTokens = Int(customTokensStr) ?? 0
        store.apiDailyBudget    = Double(budgetStr) ?? 10.0

        var thresholds: [Double] = []
        if let v1 = Double(threshold1Str), v1 > 0 { thresholds.append(v1 / 100) }
        if let v2 = Double(threshold2Str), v2 > 0 { thresholds.append(v2 / 100) }
        store.alertThresholds = thresholds.isEmpty ? [0.5, 0.75] : thresholds

        isShowing = false
    }

    private func label(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .foregroundStyle(dim)
            .kerning(1.5)
    }

    private func field(_ binding: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: binding)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.white)
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
        return "\(n)"
    }
}
