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

    // MARK: - Schema

    func initSchema() {
        withDB { db in
            sqlite3_exec(db, """
                CREATE TABLE IF NOT EXISTS usage (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    ts          INTEGER NOT NULL,
                    day         TEXT NOT NULL,
                    model       TEXT NOT NULL,
                    input_tok   INTEGER NOT NULL DEFAULT 0,
                    output_tok  INTEGER NOT NULL DEFAULT 0,
                    cache_read  INTEGER NOT NULL DEFAULT 0,
                    cache_write INTEGER NOT NULL DEFAULT 0,
                    cost_usd    REAL    NOT NULL DEFAULT 0,
                    tool        TEXT,
                    msg_id      TEXT UNIQUE
                );
                CREATE INDEX IF NOT EXISTS idx_day ON usage(day);
                CREATE INDEX IF NOT EXISTS idx_msg ON usage(msg_id);
            """, nil, nil, nil)
        }
    }

    func exists(msgID: String) -> Bool {
        var found = false
        withDB { db in
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT 1 FROM usage WHERE msg_id=?", -1, &stmt, nil) == SQLITE_OK {
                bind(stmt, 1, msgID)
                found = sqlite3_step(stmt) == SQLITE_ROW
            }
            sqlite3_finalize(stmt)
        }
        return found
    }

    func insert(ts: Int, day: String, model: String,
                input: Int, output: Int, cacheRead: Int, cacheWrite: Int,
                cost: Double, tool: String, msgID: String) {
        withDB { db in
            var stmt: OpaquePointer?
            let sql = """
                INSERT OR IGNORE INTO usage
                (ts,day,model,input_tok,output_tok,cache_read,cache_write,cost_usd,tool,msg_id)
                VALUES (?,?,?,?,?,?,?,?,?,?)
            """
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, Int64(ts))
                bind(stmt, 2, day);   bind(stmt, 3, model)
                sqlite3_bind_int64(stmt, 4, Int64(input))
                sqlite3_bind_int64(stmt, 5, Int64(output))
                sqlite3_bind_int64(stmt, 6, Int64(cacheRead))
                sqlite3_bind_int64(stmt, 7, Int64(cacheWrite))
                sqlite3_bind_double(stmt, 8, cost)
                bind(stmt, 9, tool);  bind(stmt, 10, msgID)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
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
