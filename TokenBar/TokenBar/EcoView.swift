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

// 21 quotes — the number of chapter 21 of the Tao Te Ching, which describes the nature of the Tao itself.
private struct Quote {
    let en: String
    let ru: String
    let source_en: String
    let source_ru: String
}

private let TAO_QUOTES: [Quote] = [
    Quote(
        en: "My life has a limit,\nbut my knowledge is without limit.\nTo pursue the limitless with the limited is dangerous.",
        ru: "Жизнь моя имеет предел, а знание — нет.\nГнаться за безграничным\nс помощью ограниченного — опасно.",
        source_en: "Zhuangzi, ch. 3", source_ru: "Чжуан-цзы, гл. 3"
    ),
    Quote(
        en: "Less is more.\nMore is confusion.",
        ru: "У кого мало — тот приобретает.\nУ кого много — тот теряется.",
        source_en: "Tao Te Ching, ch. 22", source_ru: "Дао Дэ Цзин, гл. 22"
    ),
    Quote(
        en: "Better to stop in time\nthan to fill to the brim.\nSharpen a blade too much and it will soon blunt.",
        ru: "Лучше остановиться вовремя,\nчем наполнять до краёв.\nНаточи клинок до предела — и он скоро затупится.",
        source_en: "Tao Te Ching, ch. 9", source_ru: "Дао Дэ Цзин, гл. 9"
    ),
    Quote(
        en: "Fame or life — which matters more?\nLife or wealth — which is more precious?\nGain or loss — which is more painful?",
        ru: "Слава или жизнь — что дороже?\nЖизнь или накопленное — что нужнее?\nПриобретение или потеря — что больнее?",
        source_en: "Tao Te Ching, ch. 44", source_ru: "Дао Дэ Цзин, гл. 44"
    ),
    Quote(
        en: "Knowing others is wisdom.\nKnowing yourself is enlightenment.\nMastering others is strength.\nMastering yourself is true power.",
        ru: "Знающий других — мудр.\nЗнающий себя — просветлён.\nПобеждающий других — силён.\nПобеждающий себя — непобедим.",
        source_en: "Tao Te Ching, ch. 33", source_ru: "Дао Дэ Цзин, гл. 33"
    ),
    Quote(
        en: "Act before trouble arises.\nSet things in order before disorder begins.",
        ru: "Действуй, пока нет беды.\nНаводи порядок, пока нет смуты.",
        source_en: "Tao Te Ching, ch. 64", source_ru: "Дао Дэ Цзин, гл. 64"
    ),
    Quote(
        en: "Stillness overcomes heat.\nSerenity brings order to the world.",
        ru: "Покой побеждает жару.\nСпокойствие создаёт порядок в мире.",
        source_en: "Tao Te Ching, ch. 45", source_ru: "Дао Дэ Цзин, гл. 45"
    ),
    Quote(
        en: "Act without action.\nDo without doing.\nTaste without tasting.",
        ru: "Действуй без действия.\nДелай без усилий.\nВкушай без вкуса.",
        source_en: "Tao Te Ching, ch. 63", source_ru: "Дао Дэ Цзин, гл. 63"
    ),
    Quote(
        en: "Joy and anger are deviations from the Tao.\nSorrow and grief are the loss of virtue.",
        ru: "Радость и гнев — отступление от дао,\nпечаль и скорбь — утрата блага.",
        source_en: "Zhuangzi", source_ru: "Чжуан-цзы"
    ),
    Quote(
        en: "Achieve inner impartiality,\nremain unmoved —\nthen everything will transform of itself.",
        ru: "Необходимо обрести в сердце неподкупную справедливость,\nоставаться невозмутимым —\nтогда всё начнёт меняться само по себе.",
        source_en: "Tao Te Ching", source_ru: "Дао Дэ Цзин"
    ),
    Quote(
        en: "A cool mind\ncreates order in important matters.",
        ru: "Холодный ум создаёт порядок\nв важных делах.",
        source_en: "Tao Te Ching, spirit", source_ru: "Дао Дэ Цзин, дух"
    ),
    Quote(
        en: "Do not waste the rest of your life in thoughts about other people,\nunless it relates to the common good.\nIt distracts you from your own work.",
        ru: "Не трать остаток жизни на мысли о других,\nесли это не связано с общим благом.\nЭто отвлекает тебя от собственного дела.",
        source_en: "Marcus Aurelius, Meditations", source_ru: "Марк Аврелий, Размышления"
    ),
    Quote(
        en: "Do less, better.\nMost of what we say and do\nis not essential.",
        ru: "Делай меньше — лучше.\nБольшинство того, что мы говорим и делаем,\nне является необходимым.",
        source_en: "Marcus Aurelius, Meditations", source_ru: "Марк Аврелий, Размышления"
    ),
    Quote(
        en: "While you delay, life speeds by.\nEverything belongs to others, Lucilius.\nTime alone is yours.",
        ru: "Пока ты откладываешь жизнь — она проходит.\nВсё чужое, Луцилий.\nВремя — только твоё.",
        source_en: "Seneca, Letters to Lucilius", source_ru: "Сенека, Письма к Луцилию"
    ),
    Quote(
        en: "We are oppressed by an abundance of things.\nWhen you try to please everyone\nyou please no one — including yourself.",
        ru: "Нас давит обилие вещей.\nКогда хочешь угодить всем —\nне угождаешь никому, в том числе себе.",
        source_en: "Seneca, Letters to Lucilius", source_ru: "Сенека, Письма к Луцилию"
    ),
    Quote(
        en: "All of humanity's problems stem from man's inability\nto sit quietly in a room alone.",
        ru: "Все несчастья человека происходят оттого,\nчто он не умеет спокойно сидеть\nв своей комнате.",
        source_en: "Blaise Pascal", source_ru: "Блез Паскаль"
    ),
    Quote(
        en: "One of the greatest temptations\nis to justify your idleness by saying\nyou are thinking about great things.",
        ru: "Один из величайших соблазнов —\nоправдывать своё безделье тем,\nчто ты думаешь о великом.",
        source_en: "Leo Tolstoy", source_ru: "Лев Толстой"
    ),
    Quote(
        en: "Learning without thought is labor lost.\nThought without learning is perilous.",
        ru: "Учиться и не размышлять — напрасно терять время.\nРазмышлять и не учиться — губительно.",
        source_en: "Confucius, Analects", source_ru: "Конфуций, Луньюй"
    ),
    Quote(
        en: "Mind is the forerunner of all actions.\nMind is their master.\nFrom mind they are born.",
        ru: "Ум — предшественник всех действий.\nУм — их властелин.\nИз ума они рождены.",
        source_en: "Dhammapada, ch. 1", source_ru: "Дхаммапада, гл. 1"
    ),
    Quote(
        en: "In much wisdom is much grief.\nHe that increases knowledge\nincreases sorrow.",
        ru: "Во многой мудрости много печали.\nКто умножает познания —\nумножает скорбь.",
        source_en: "Ecclesiastes 1:18", source_ru: "Экклезиаст 1:18"
    ),
    Quote(
        en: "Time destroys all things.\nEach time I remember something\nI alter it a little.",
        ru: "Время разрушает все вещи.\nКаждый раз, когда я что-то вспоминаю —\nя немного изменяю это.",
        source_en: "Jorge Luis Borges", source_ru: "Хорхе Луис Борхес"
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
    @ObservedObject private var settings = SettingsStore.shared

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

            let isRu = settings.appLanguage == .ru
            let noteText = isRu
                ? "На создание этого бара потрачено \(fmt) токенов."
                : "This bar was built using \(fmt) tokens."
            let quoteText = isRu ? quote.ru : quote.en
            let quoteSource = isRu ? quote.source_ru : quote.source_en
            let quoteLen = quoteText.count
            let quoteFontSize: CGFloat = quoteLen > 120 ? 8 : (quoteLen > 80 ? 8.5 : 9)

            Text(noteText)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(dim.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("«\(quoteText)»")
                .font(.system(size: quoteFontSize, design: .monospaced))
                .italic()
                .foregroundStyle(leafCol.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            Text("— \(quoteSource)")
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
