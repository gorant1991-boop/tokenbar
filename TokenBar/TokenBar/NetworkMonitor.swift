import Foundation

struct NetProcess: Identifiable {
    let id      = UUID()
    let name:   String
    let rxBytesPerSec: Int64
    let txBytesPerSec: Int64
    var total:  Int64 { rxBytesPerSec + txBytesPerSec }
}

enum NetworkMonitor {

    /// Returns per-process traffic over a ~1 second window (delta mode).
    /// Blocks the calling thread for ~1 second — call from a background task.
    static func snapshot() -> [NetProcess] {
        let out = shell("/usr/bin/nettop",
                        args: ["-P", "-L", "2", "-s", "1", "-x", "-n", "-d"])
        return parse(out)
    }

    private static func parse(_ raw: String) -> [NetProcess] {
        let lines = raw.components(separatedBy: "\n")
        guard lines.count > 1 else { return [] }

        let header = lines[0].components(separatedBy: ",")
        guard let rxIdx = header.firstIndex(of: "bytes_in"),
              let txIdx = header.firstIndex(of: "bytes_out") else { return [] }

        // With -L 2 -d, output has two batches of rows separated by blank lines.
        // The LAST batch is the delta over the sample interval.
        var batches: [[String]] = []
        var current: [String]  = []
        for line in lines.dropFirst() {
            let cols = line.components(separatedBy: ",")
            if cols.count > 1 && !cols[1].trimmingCharacters(in: .whitespaces).isEmpty {
                current.append(line)
            } else if !current.isEmpty {
                batches.append(current)
                current = []
            }
        }
        if !current.isEmpty { batches.append(current) }

        let rows = batches.last ?? []
        var totals: [String: (Int64, Int64)] = [:]

        for line in rows {
            let cols = line.components(separatedBy: ",")
            guard cols.count > max(rxIdx, txIdx) else { continue }
            let procField = cols[1].trimmingCharacters(in: .whitespaces)
            // Strip trailing .pid
            let name = procField.components(separatedBy: ".").dropLast().joined(separator: ".")
            guard !name.isEmpty else { continue }
            let rx = Int64(cols[rxIdx]) ?? 0
            let tx = Int64(cols[txIdx]) ?? 0
            if rx + tx < 512 { continue }   // ignore < 512 B/s noise
            let prev = totals[name] ?? (0, 0)
            totals[name] = (prev.0 + rx, prev.1 + tx)
        }

        return totals
            .map { NetProcess(name: $0.key, rxBytesPerSec: $0.value.0, txBytesPerSec: $0.value.1) }
            .sorted { $0.total > $1.total }
    }

    private static func shell(_ path: String, args: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        do { try proc.run(); proc.waitUntilExit() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }
}
