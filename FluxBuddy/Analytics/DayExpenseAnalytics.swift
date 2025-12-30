import Foundation

struct DayExpenseStat {
    let weekday: Int   // 1 = nedeľa ... 7 = sobota
    let average: Double
}

struct DayExpenseAnalytics {

    static func expensesByWeekday(
        transactions: [TransactionEntity]
    ) -> [DayExpenseStat] {

        let cal = Calendar.current

        let expenses = transactions.filter { $0.amount < 0 }

        let grouped = Dictionary(grouping: expenses) {
            cal.component(.weekday, from: $0.date)
        }

        return grouped.map { weekday, txs in
            let total = txs.reduce(0) { $0 + abs($1.amount) }
            let avg = total / Double(txs.count)
            return DayExpenseStat(weekday: weekday, average: avg)
        }
        .sorted { $0.weekday < $1.weekday }
    }

    static func worstDay(transactions: [TransactionEntity]) -> (date: Date, total: Double)? {
        let cal = Calendar.current

        let grouped = Dictionary(grouping: transactions.filter { $0.amount < 0 }) {
            cal.startOfDay(for: $0.date)
        }

        guard let worst = grouped.max(by: {
            $0.value.reduce(0) { $0 + abs($1.amount) } <
            $1.value.reduce(0) { $0 + abs($1.amount) }
        }) else { return nil }

        let total = worst.value.reduce(0) { $0 + abs($1.amount) }
        return (worst.key, total)
    }

    static func weekendVsWeekday(
        transactions: [TransactionEntity]
    ) -> (weekend: Double, weekday: Double) {

        let cal = Calendar.current

        let expenses = transactions.filter { $0.amount < 0 }

        let weekend = expenses.filter {
            let d = cal.component(.weekday, from: $0.date)
            return d == 1 || d == 7
        }.reduce(0) { $0 + abs($1.amount) }

        let weekday = expenses.filter {
            let d = cal.component(.weekday, from: $0.date)
            return d >= 2 && d <= 6
        }.reduce(0) { $0 + abs($1.amount) }

        return (weekend, weekday)
    }
}
