import Foundation

struct NetProcess: Identifiable {
    let id = UUID()
    let name: String
    let rxBytes: Int64
    let txBytes: Int64

    var total: Int64 { rxBytes + txBytes }
}

/// Runs `nettop` once and returns per-process byte counters.
enum NetworkMonitor {

    static func snapshot() -> [NetProcess] {
        let out = shell("/usr/bin/nettop",
                        args: ["-P", "-L", "1", "-J", "rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,interface,state",
                               "-k", "proc_name,rx_bytes,tx_bytes"])
        return parse(out)
    }

    // MARK: – Parse

    private static func parse(_ raw: String) -> [NetProcess] {
        var results: [NetProcess] = []
        let lines = raw.components(separatedBy: "\n")
        guard lines.count > 1 else { return [] }

        // Header line tells us column positions
        let header = lines[0]
        guard let rxRange = columnRange(header, "rx_bytes"),
              let txRange = columnRange(header, "tx_bytes") else {
            return parseFallback(lines)
        }

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // Process name is everything before first whitespace run
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 3 else { continue }
            let name = parts[0]
            let rx   = Int64(parts[safe: rxRange] ?? "0") ?? 0
            let tx   = Int64(parts[safe: txRange] ?? "0") ?? 0
            if rx + tx > 0 {
                results.append(NetProcess(name: name, rxBytes: rx, txBytes: tx))
            }
        }
        return results.sorted { $0.total > $1.total }
    }

    // Fallback: nettop -P -L 1 simpler format
    private static func parseFallback(_ lines: [String]) -> [NetProcess] {
        var results: [NetProcess] = []
        for line in lines.dropFirst() {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 3,
                  let rx = Int64(parts[1]),
                  let tx = Int64(parts[2]) else { continue }
            if rx + tx > 0 {
                results.append(NetProcess(name: parts[0], rxBytes: rx, txBytes: tx))
            }
        }
        return results.sorted { $0.total > $1.total }
    }

    private static func columnRange(_ header: String, _ name: String) -> Int? {
        let cols = header.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return cols.firstIndex(of: name)
    }

    // MARK: – Shell

    private static func shell(_ path: String, args: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
