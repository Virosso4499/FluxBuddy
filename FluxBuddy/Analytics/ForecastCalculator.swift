import Foundation

struct ForecastResult {
    let avgIncome: Double
    let avgExpense: Double
    let predictedNet: Double

    /// posledných N mesiacov, z ktorých sa rátal priemer (na graf + výpis)
    let monthly: [(month: Date, income: Double, expense: Double)]
}

struct ForecastCalculator {

    static func forecast(
        transactions: [TransactionEntity],
        referenceDate: Date = Date(),
        months: Int = 6
    ) -> ForecastResult {

        let cal = Calendar.current

        // posledných N mesiacov (bez aktuálneho mesiaca)
        let pastMonths: [Date] = (1...months).compactMap {
            cal.date(byAdding: .month, value: -$0, to: referenceDate)
        }
        .map { monthStart($0, cal: cal) }
        .sorted()

        // detail po mesiacoch (vždy vraciame N položiek)
        let monthly: [(month: Date, income: Double, expense: Double)] = pastMonths.map { month in
            let inMonth = transactions.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }

            let income = inMonth
                .filter { $0.amount > 0 }
                .reduce(0) { $0 + $1.amount }

            let expense = inMonth
                .filter { $0.amount < 0 }
                .reduce(0) { $0 + abs($1.amount) }

            return (month: month, income: income, expense: expense)
        }

        // priemer len z mesiacov, kde niečo reálne bolo
        let incomes = monthly.map(\.income).filter { $0 > 0 }
        let expenses = monthly.map(\.expense).filter { $0 > 0 }

        let avgIncome = incomes.isEmpty ? 0 : incomes.reduce(0, +) / Double(incomes.count)
        let avgExpense = expenses.isEmpty ? 0 : expenses.reduce(0, +) / Double(expenses.count)

        return ForecastResult(
            avgIncome: avgIncome,
            avgExpense: avgExpense,
            predictedNet: avgIncome - avgExpense,
            monthly: monthly
        )
    }

    private static func monthStart(_ date: Date, cal: Calendar) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }
}
