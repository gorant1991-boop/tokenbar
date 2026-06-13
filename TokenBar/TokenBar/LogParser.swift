import Foundation
import SQLite3

/// Scans ~/.claude/projects/**/*.jsonl and imports token usage into SQLite.
/// Replaces proxy/log_parser.py — no Python dependency.
enum LogParser {

    // MARK: – Public

    @discardableResult
    static func parseAll() -> Int {
        TokenDatabase.shared.initSchema()
        let claudeDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/projects")
        guard FileManager.default.fileExists(atPath: claudeDir.path) else { return 0 }

        var imported = 0
        let jsonlFiles = findJSONL(in: claudeDir)

        for file in jsonlFiles {
            imported += processFile(file)
        }
        return imported
    }

    // MARK: – File discovery

    private static func findJSONL(in dir: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [URL] = []
        for case let url as URL in enumerator {
            // Security: skip symlinks (prevents path traversal via crafted symlinks)
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
                continue
            }
            if url.pathExtension == "jsonl" {
                results.append(url)
            }
        }
        return results
    }

    // MARK: – File processing

    private static func processFile(_ url: URL) -> Int {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return 0 }

        let fileMtime = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        let fallbackTs = Int(fileMtime?.timeIntervalSince1970 ?? Date().timeIntervalSince1970)

        var count = 0
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let entry = parseJSON(trimmed) else { continue }

            guard let msg = entry["message"] as? [String: Any],
                  let usage = msg["usage"] as? [String: Any],
                  let msgID = msg["id"] as? String,
                  !msgID.isEmpty else { continue }

            guard let model = msg["model"] as? String,
                  !model.isEmpty,
                  !model.hasPrefix("<") else { continue }

            // Skip already imported
            guard !TokenDatabase.shared.exists(msgID: msgID) else { continue }

            // Security: clamp token values to [0, 100_000_000]
            let cap = 100_000_000
            let inp = clamp(usage["input_tokens"],  cap)
            let out = clamp(usage["output_tokens"], cap)
            let cr  = clamp(usage["cache_read_input_tokens"], cap)
            let cw  = clamp(
                (usage["cache_creation_input_tokens"] as? Int) ??
                ((usage["cache_creation"] as? [String: Any])?["ephemeral_1h_input_tokens"] as? Int),
                cap
            )

            let normalizedModel = stripDateSuffix(model)
            let cost = computeCost(model: normalizedModel, input: inp, output: out)
            let day  = isoDate(from: fallbackTs)

            TokenDatabase.shared.insert(
                ts: fallbackTs, day: day, model: normalizedModel,
                input: inp, output: out, cacheRead: cr, cacheWrite: cw,
                cost: cost, tool: "Claude Code", msgID: msgID
            )
            count += 1
        }
        return count
    }

    // MARK: – Helpers

    private static func parseJSON(_ s: String) -> [String: Any]? {
        guard let data = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    private static func clamp(_ value: Any?, _ cap: Int) -> Int {
        guard let v = value as? Int else { return 0 }
        return max(0, min(v, cap))
    }

    private static func stripDateSuffix(_ model: String) -> String {
        // claude-haiku-4-5-20251001 → claude-haiku-4-5
        let pattern = #"-\d{8}$"#
        if let range = model.range(of: pattern, options: .regularExpression) {
            return String(model[..<range.lowerBound])
        }
        return model
    }

    private static func isoDate(from ts: Int) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private static let MODEL_PRICING: [(prefix: String, inp: Double, out: Double)] = [
        ("claude-opus",   15.00, 75.00),
        ("claude-sonnet",  3.00, 15.00),
        ("claude-haiku",   0.25,  1.25),
        ("claude-fable",  15.00, 75.00),
    ]
    private static let DEFAULT_PRICING = (inp: 3.00, out: 15.00)

    private static func computeCost(model: String, input: Int, output: Int) -> Double {
        let p = MODEL_PRICING.first { model.hasPrefix($0.prefix) }
            .map { ($0.inp, $0.out) } ?? (DEFAULT_PRICING.inp, DEFAULT_PRICING.out)
        return Double(input) / 1_000_000 * p.0 + Double(output) / 1_000_000 * p.1
    }
}
