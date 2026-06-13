import SwiftUI

// Energy estimates per 1M tokens (Wh).
// Source: Luccioni et al. 2023 "Power Hungry Processing" + H100 efficiency scaling.
// Actual Anthropic figures are not public — treat as order-of-magnitude estimates.
private let MODEL_WH_PER_M: [String: Double] = [
    "claude-opus":   500.0,   // large model, ~500 Wh/M
    "claude-sonnet": 150.0,   // mid-size,   ~150 Wh/M
    "claude-haiku":   15.0,   // small/fast,  ~15 Wh/M
    "claude-fable":  300.0,
]
private let DEFAULT_WH_PER_M = 150.0

// 21 цитата — число главы Дао Дэ Цзин о природе самого Дао
private let TAO_QUOTES: [(text: String, source: String)] = [
    // Чжуан-цзы и Дао Дэ Цзин
    (
        "Жизнь моя имеет предел, а знание — нет.\nГнаться за безграничным\nс помощью ограниченного — опасно.",
        "Чжуан-цзы, гл. 3"
    ),
    (
        "У кого мало — тот приобретает.\nУ кого много — тот теряется.",
        "Дао Дэ Цзин, гл. 22"
    ),
    (
        "Лучше остановиться вовремя,\nчем наполнять до краёв.\nНаточи клинок до предела — и он скоро затупится.",
        "Дао Дэ Цзин, гл. 9"
    ),
    (
        "Слава или жизнь — что дороже?\nЖизнь или накопленное — что нужнее?\nПриобретение или потеря — что больнее?",
        "Дао Дэ Цзин, гл. 44"
    ),
    (
        "Знающий других — мудр.\nЗнающий себя — просветлён.\nПобеждающий других — силён.\nПобеждающий себя — непобедим.",
        "Дао Дэ Цзин, гл. 33"
    ),
    (
        "Действуй, пока нет беды.\nНаводи порядок, пока нет смуты.",
        "Дао Дэ Цзин, гл. 64"
    ),
    (
        "Покой побеждает жару.\nСпокойствие создаёт порядок в мире.",
        "Дао Дэ Цзин, гл. 45"
    ),
    (
        "Действуй без действия.\nДелай без усилий.\nВкушай без вкуса.",
        "Дао Дэ Цзин, гл. 63"
    ),
    (
        "Радость и гнев — отступление от дао,\nпечаль и скорбь — утрата блага.",
        "Чжуан-цзы"
    ),
    (
        "Необходимо обрести в сердце неподкупную справедливость,\nоставаться невозмутимым —\nтогда всё начнёт меняться само по себе.",
        "Дао Дэ Цзин (пер. Торчинова)"
    ),
    (
        "Холодный ум создаёт порядок\nв важных делах.",
        "Дао Дэ Цзин, дух"
    ),
    // Марк Аврелий
    (
        "Не трать остаток жизни на мысли о других,\nесли это не связано с общим благом.\nЭто отвлекает тебя от собственного дела.",
        "Марк Аврелий, Размышления"
    ),
    (
        "Делай меньше — лучше.\nБольшинство того, что мы говорим и делаем,\nне является необходимым.",
        "Марк Аврелий, Размышления"
    ),
    // Сенека
    (
        "Пока ты откладываешь жизнь — она проходит.\nВсё чужое, Луцилий.\nВремя — только твоё.",
        "Сенека, Письма к Луцилию"
    ),
    (
        "Нас давит обилие вещей.\nКогда хочешь угодить всем —\nне угождаешь никому, в том числе себе.",
        "Сенека, Письма к Луцилию"
    ),
    // Паскаль
    (
        "Все несчастья человека происходят оттого,\nчто он не умеет спокойно сидеть\nв своей комнате.",
        "Блез Паскаль"
    ),
    // Толстой
    (
        "Один из величайших соблазнов —\nоправдывать своё безделье тем,\nчто ты думаешь о великом.",
        "Лев Толстой"
    ),
    // Конфуций
    (
        "Учиться и не размышлять — напрасно терять время.\nРазмышлять и не учиться — губительно.",
        "Конфуций, Луньюй"
    ),
    // Дхаммапада
    (
        "Ум — предшественник всех действий.\nУм — их властелин.\nИз ума они рождены.",
        "Дхаммапада, гл. 1"
    ),
    // Экклезиаст
    (
        "Во многой мудрости много печали.\nКто умножает познания —\nумножает скорбь.",
        "Экклезиаст 1:18"
    ),
    // Борхес
    (
        "Время разрушает все вещи.\nКаждый раз, когда я что-то вспоминаю —\nя немного изменяю это.",
        "Хорхе Луис Борхес"
    ),
]

// CO₂ intensity: global cloud avg with partial renewables ~0.2 kg/kWh
private let CO2_KG_PER_KWH = 0.2
// Water: ~1.8 L/kWh for data center cooling
private let WATER_L_PER_KWH = 1.8

private let accent  = Color(red: 0.2, green: 0.7, blue: 1.0)
private let leafCol = Color(red: 0.3, green: 0.85, blue: 0.45)
private let bg      = Color(red: 0.08, green: 0.09, blue: 0.12)
private let card    = Color(red: 0.12, green: 0.13, blue: 0.17)
private let dim     = Color.white.opacity(0.35)

struct EcoStats {
    let whTotal:   Double   // watt-hours
    let co2Grams:  Double   // grams CO₂
    let waterMl:   Double   // millilitres

    var kWh: Double { whTotal / 1000 }

    // Fun comparisons
    var phoneCharges: Double { whTotal / 12.0 }          // ~12 Wh per charge
    var teslaKm:      Double { kWh * 6.5 }               // Tesla Model 3 ~6.5 km/kWh
    var netflixMin:   Double { kWh / 0.036 * 60 }        // ~36 Wh/hr streaming
}

struct EcoView: View {
    @ObservedObject var vm: StatsViewModel
    @Binding var isShowing: Bool

    private var stats: EcoStats { computeStats() }
    @State private var quote = TAO_QUOTES.randomElement()!

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 12) {
                        mainCards
                        comparisons
                        disclaimer
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: – Header

    private var header: some View {
        HStack {
            Button(action: { isShowing = false }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(leafCol)
                Text("ECO IMPACT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(dim)
                    .kerning(1.5)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: – Main cards

    private var mainCards: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ecoCard(
                    icon: "bolt.fill",
                    color: Color(red: 1.0, green: 0.8, blue: 0.2),
                    title: "ENERGY",
                    value: formatWh(stats.whTotal),
                    sub: "today"
                )
                ecoCard(
                    icon: "cloud.fill",
                    color: Color(red: 0.6, green: 0.8, blue: 1.0),
                    title: "CO₂ equiv",
                    value: formatCO2(stats.co2Grams),
                    sub: "estimated"
                )
            }
            HStack(spacing: 8) {
                ecoCard(
                    icon: "drop.fill",
                    color: Color(red: 0.3, green: 0.7, blue: 1.0),
                    title: "WATER",
                    value: formatWater(stats.waterMl),
                    sub: "cooling"
                )
                ecoCard(
                    icon: "scalemass.fill",
                    color: leafCol,
                    title: "TOKENS",
                    value: formatTokens(vm.today.inputTokens + vm.today.outputTokens),
                    sub: "processed"
                )
            }
        }
    }

    private func ecoCard(icon: String, color: Color, title: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(dim)
                    .kerning(1.2)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(sub)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(dim.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: – Comparisons

    private var comparisons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EQUIVALENT TO")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(dim)
                .kerning(1.5)

            compRow("iphone.gen3", color: Color(red: 0.8, green: 0.8, blue: 0.9),
                    text: "\(String(format: "%.1f", stats.phoneCharges)) phone charges")
            compRow("car.fill", color: Color(red: 0.9, green: 0.7, blue: 0.3),
                    text: "\(String(format: "%.2f", stats.teslaKm)) km in a Tesla")
            compRow("play.rectangle.fill", color: Color(red: 0.8, green: 0.3, blue: 0.3),
                    text: "\(String(format: "%.0f", stats.netflixMin)) min of Netflix")
        }
        .padding(14)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func compRow(_ icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: – Disclaimer

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("~ Estimates based on ML inference research.\nAnthropic uses renewable energy — actual\nCO₂ may be significantly lower.")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(dim.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            foundingNote
        }
    }

    private var foundingNote: some View {
        let total = TokenDatabase.shared.allTimeTokens()
        let fmt: String
        if total >= 1_000_000 { fmt = String(format: "%.1fM", Double(total)/1_000_000) }
        else if total >= 1_000 { fmt = String(format: "%.0fK", Double(total)/1_000) }
        else { fmt = "\(total)" }

        return VStack(alignment: .center, spacing: 6) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            Text("На создание этого бара потрачено \(fmt) токенов.")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(dim.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("«\(quote.text)»")
                .font(.system(size: 9, design: .monospaced))
                .italic()
                .foregroundStyle(leafCol.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("— \(quote.source)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(dim.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.top, 4)
    }

    // MARK: – Compute

    private func computeStats() -> EcoStats {
        var whTotal = 0.0
        for m in vm.models {
            let tokens = Double(m.inputTokens + m.outputTokens) / 1_000_000
            let rate = MODEL_WH_PER_M.first { m.model.contains($0.key) }?.value ?? DEFAULT_WH_PER_M
            whTotal += tokens * rate
        }
        // If no model breakdown, use totals with default rate
        if vm.models.isEmpty {
            let tokens = Double(vm.today.inputTokens + vm.today.outputTokens) / 1_000_000
            whTotal = tokens * DEFAULT_WH_PER_M
        }
        let co2  = whTotal / 1000 * CO2_KG_PER_KWH * 1000  // grams
        let water = whTotal / 1000 * WATER_L_PER_KWH * 1000 // ml
        return EcoStats(whTotal: whTotal, co2Grams: co2, waterMl: water)
    }

    // MARK: – Formatters

    private func formatWh(_ wh: Double) -> String {
        if wh >= 1000 { return String(format: "%.2f kWh", wh/1000) }
        if wh >= 1    { return String(format: "%.1f Wh", wh) }
        return String(format: "%.0f mWh", wh * 1000)
    }

    private func formatCO2(_ g: Double) -> String {
        if g >= 1000 { return String(format: "%.2f kg", g/1000) }
        return String(format: "%.1f g", g)
    }

    private func formatWater(_ ml: Double) -> String {
        if ml >= 1000 { return String(format: "%.2f L", ml/1000) }
        return String(format: "%.0f ml", ml)
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
        return "\(n)"
    }
}
