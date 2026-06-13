import Foundation
import SQLite3

struct DayStats {
    let day: String
    let totalCost: Double
    let inputTokens: Int
    let outputTokens: Int
}

struct ModelStats {
    let model: String
    let cost: Double
    let inputTokens: Int
    let outputTokens: Int
}

final class TokenDatabase {
    static let shared = TokenDatabase()
    private let dbPath: String

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".tokenbar")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbPath = dir.appendingPathComponent("usage.db").path
    }

    // MARK: - Queries

    func todayStats() -> DayStats {
        let today = isoToday()
        var cost = 0.0
        var input = 0
        var output = 0

        withDB { db in
            var stmt: OpaquePointer?
            let sql = "SELECT COALESCE(SUM(cost_usd),0), COALESCE(SUM(input_tok),0), COALESCE(SUM(output_tok),0) FROM usage WHERE day=?"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                bind(stmt, 1, today)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    cost   = sqlite3_column_double(stmt, 0)
                    input  = Int(sqlite3_column_int(stmt, 1))
                    output = Int(sqlite3_column_int(stmt, 2))
                }
            }
            sqlite3_finalize(stmt)
        }
        return DayStats(day: today, totalCost: cost, inputTokens: input, outputTokens: output)
    }

    func modelBreakdown(day: String? = nil) -> [ModelStats] {
        let filter = day ?? isoToday()
        var results: [ModelStats] = []

        withDB { db in
            var stmt: OpaquePointer?
            let sql = """
                SELECT model,
                       COALESCE(SUM(cost_usd),0),
                       COALESCE(SUM(input_tok),0),
                       COALESCE(SUM(output_tok),0)
                FROM usage WHERE day=?
                GROUP BY model ORDER BY SUM(cost_usd) DESC
            """
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                bind(stmt, 1, filter)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let model  = String(cString: sqlite3_column_text(stmt, 0))
                    let cost   = sqlite3_column_double(stmt, 1)
                    let input  = Int(sqlite3_column_int(stmt, 2))
                    let output = Int(sqlite3_column_int(stmt, 3))
                    results.append(ModelStats(model: model, cost: cost, inputTokens: input, outputTokens: output))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }

    func last7Days() -> [DayStats] {
        var results: [DayStats] = []

        withDB { db in
            var stmt: OpaquePointer?
            let sql = """
                SELECT day,
                       COALESCE(SUM(cost_usd),0),
                       COALESCE(SUM(input_tok),0),
                       COALESCE(SUM(output_tok),0)
                FROM usage
                WHERE day >= date('now','-6 days')
                GROUP BY day ORDER BY day ASC
            """
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let day    = String(cString: sqlite3_column_text(stmt, 0))
                    let cost   = sqlite3_column_double(stmt, 1)
                    let input  = Int(sqlite3_column_int(stmt, 2))
                    let output = Int(sqlite3_column_int(stmt, 3))
                    results.append(DayStats(day: day, totalCost: cost, inputTokens: input, outputTokens: output))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }

    func allTimeTokens() -> Int {
        var total = 0
        withDB { db in
            var stmt: OpaquePointer?
            let sql = "SELECT COALESCE(SUM(input_tok + output_tok), 0) FROM usage"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    total = Int(sqlite3_column_int(stmt, 0))
                }
            }
            sqlite3_finalize(stmt)
        }
        return total
    }

    // MARK: - Helpers

    private func isoToday() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    // SQLITE_TRANSIENT — SQLite copies the string before the call returns
    private let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private func bind(_ stmt: OpaquePointer?, _ idx: Int32, _ s: String) {
        sqlite3_bind_text(stmt, idx, s, -1, TRANSIENT)
    }

    private func withDB(_ block: (OpaquePointer) -> Void) {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else { return }
        block(db)
        sqlite3_close(db)
    }
}
