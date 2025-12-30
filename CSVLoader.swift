import Foundation
import SwiftData

enum CSVLoader {

    /// ✅ Auto-refresh pri každom spustení
    @MainActor
    static func refreshFromBundle(context: ModelContext) {

        // 1) vymaž všetky existujúce transakcie
        deleteAllTransactions(context: context)

        // 2) načítaj CSV priamo z Bundle (Xcode)
        guard let url = Bundle.main.url(forResource: "transactions", withExtension: "csv") else {
            print("❌ transactions.csv nie je v Bundle (skontroluj, že je v 'Copy Bundle Resources')")
            return
        }

        // 3) import
        importCSV(from: url, context: context)
    }

    // MARK: - Delete all (TransactionEntity)
    @MainActor
    private static func deleteAllTransactions(context: ModelContext) {
        let descriptor = FetchDescriptor<TransactionEntity>()
        do {
            let all = try context.fetch(descriptor)
            for tx in all {
                context.delete(tx)
            }
            try context.save()
            print("🧹 Zmazané transakcie: \(all.count)")
        } catch {
            print("❌ Chyba pri mazaní transakcií:", error)
        }
    }

    // MARK: - Import CSV
    @MainActor
    private static func importCSV(from url: URL, context: ModelContext) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: .newlines).dropFirst()

            var imported = 0

            for row in rows {
                let cols = parseCSVLine(row)
                guard cols.count >= 15 else { continue }

                guard
                    let date = parseDate(cols[0]),
                    let amount = parseAmount(cols[2], type: cols[4])
                else { continue }

                let title = cols[14].isEmpty ? cols[13] : cols[14]
                let category = guessCategory(from: title)

                let tx = TransactionEntity(
                    title: title,
                    category: category,
                    amount: amount,
                    date: date
                )

                context.insert(tx)
                imported += 1
            }

            try context.save()
            print("✅ Auto-refresh import hotový: \(imported) transakcií")

        } catch {
            print("❌ Chyba čítania CSV:", error)
        }
    }

    // MARK: - CSV helpers
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quoted = false

        for char in line {
            if char == "\"" {
                quoted.toggle()
            } else if char == "," && !quoted {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.date(from: s)
    }

    private static func parseAmount(_ s: String, type: String) -> Double? {
        let cleaned = s
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(cleaned) else { return nil }
        return type == "Debit" ? -value : value
    }

    // MARK: - Kategorizácia
    private static func guessCategory(from text: String) -> String {
        let t = text.lowercased()

        if t.contains("salary") { return "Príjem" }
        if t.contains("rent") { return "Bývanie" }
        if t.contains("lidl") || t.contains("tesco") || t.contains("kaufland") || t.contains("billa") { return "Potraviny" }
        if t.contains("spotify") || t.contains("netflix") { return "Predplatné" }
        if t.contains("fuel") || t.contains("omv") || t.contains("shell") || t.contains("slovnaft") { return "Doprava" }
        if t.contains("restaurant") || t.contains("bistro") || t.contains("kaviare") { return "Reštaurácie" }

        return "Ostatné"
    }
}
