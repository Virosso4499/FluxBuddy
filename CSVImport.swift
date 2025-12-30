import Foundation

enum CSVImport {
    struct Row {
        let date: Date
        let title: String
        let category: String
        let amount: Double
    }

    static func parse(_ csvText: String) -> [Row] {
        let lines = csvText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0) }

        guard !lines.isEmpty else { return [] }

        // preskočí header, ak prvý riadok obsahuje "date"
        let startIndex = lines.first?.lowercased().contains("date") == true ? 1 : 0

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return lines.dropFirst(startIndex).compactMap { line in
            let parts = splitCSVLine(line)
            guard parts.count >= 4 else { return nil }

            let dateStr = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let title = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let category = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)

            // podporí aj čiarku ako desatinný oddeľovač
            let amountStr = parts[3]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")

            guard let date = formatter.date(from: dateStr),
                  let amount = Double(amountStr),
                  !title.isEmpty,
                  !category.isEmpty
            else { return nil }

            return Row(date: date, title: title, category: category, amount: amount)
        }
    }

    // jednoduchý CSV split s podporou úvodzoviek
    private static func splitCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current)
        return result
    }
}
