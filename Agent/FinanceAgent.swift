import Foundation

// MARK: - Agent Question Types

enum AgentQuestion: String, CaseIterable, Identifiable {

    case monthlySummary
    case compareToAverage
    case topExpenses
    case warnings
    case forecastNextMonth

    // HeatMap / časové otázky
    case worstSpendingDay
    case riskyWeekdays
    case weekendSpending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthlySummary:
            return "Ako som na tom tento mesiac?"
        case .compareToAverage:
            return "Porovnanie s priemerom"
        case .topExpenses:
            return "Najväčšie výdavky"
        case .warnings:
            return "Upozornenia a riziká"
        case .forecastNextMonth:
            return "Odhad na ďalší mesiac"
        case .worstSpendingDay:
            return "Ktorý deň som minul najviac?"
        case .riskyWeekdays:
            return "Ktoré dni v týždni sú rizikové?"
        case .weekendSpending:
            return "Ako míňam cez víkend?"
        }
    }

    var systemImage: String {
        switch self {
        case .monthlySummary:
            return "chart.bar"
        case .compareToAverage:
            return "arrow.left.arrow.right"
        case .topExpenses:
            return "list.number"
        case .warnings:
            return "exclamationmark.triangle"
        case .forecastNextMonth:
            return "calendar.badge.clock"
        case .worstSpendingDay:
            return "calendar.badge.exclamationmark"
        case .riskyWeekdays:
            return "chart.bar.xaxis"
        case .weekendSpending:
            return "sun.max"
        }
    }
}

// MARK: - Agent Response Models

enum AgentMessageType {
    case info
    case warning
    case positive
}

struct AgentBullet: Identifiable {
    let id = UUID()
    let text: String
    let type: AgentMessageType
}

struct AgentResponse {
    let title: String
    let bullets: [AgentBullet]

    static let empty = AgentResponse(
        title: "Žiadne dáta",
        bullets: [.init(text: "Zatiaľ nemáš transakcie na výpočet odpovede.", type: .info)]
    )
}

// MARK: - Finance Agent

struct FinanceAgent {

    static func answer(
        question: AgentQuestion,
        transactions: [TransactionEntity],
        referenceMonth: Date = Date()
    ) -> AgentResponse {

        // ak nemá nič, odpovedz jednotne
        if transactions.isEmpty {
            return .empty
        }

        switch question {
        case .monthlySummary:
            return monthlySummary(transactions, month: referenceMonth)

        case .compareToAverage:
            return compareToAverage(transactions, month: referenceMonth)

        case .topExpenses:
            return topExpenses(transactions, month: referenceMonth)

        case .warnings:
            return warnings(transactions, month: referenceMonth)

        case .forecastNextMonth:
            return forecast(transactions, month: referenceMonth)

        case .worstSpendingDay:
            return worstSpendingDay(transactions)

        case .riskyWeekdays:
            return riskyWeekdays(transactions)

        case .weekendSpending:
            return weekendSpending(transactions)
        }
    }

    // MARK: - Core calculations

    private static func monthlySummary(
        _ transactions: [TransactionEntity],
        month: Date
    ) -> AgentResponse {

        let tx = transactionsForMonth(transactions, month)
        if tx.isEmpty { return emptyForMonth(month) }

        let income = tx.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let expense = tx.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        let net = income - expense

        var bullets: [AgentBullet] = [
            .init(text: "Príjem: \(income.money)", type: .info),
            .init(text: "Výdavky: \(expense.money)", type: .info),
            .init(text: "Bilancia: \(net.money)", type: net >= 0 ? .positive : .warning)
        ]

        if expense == 0 && income == 0 {
            bullets = [.init(text: "V tomto mesiaci zatiaľ nemáš transakcie.", type: .info)]
        } else if net < 0 {
            bullets.append(.init(text: "Tip: pozri „Najväčšie výdavky“ a skús nájsť 1–2 položky na zníženie.", type: .warning))
        } else {
            bullets.append(.init(text: "Super – ak udržíš tempo, tento mesiac skončíš v pluse.", type: .positive))
        }

        return AgentResponse(title: "Mesačný prehľad", bullets: bullets)
    }

    private static func compareToAverage(
        _ transactions: [TransactionEntity],
        month: Date
    ) -> AgentResponse {

        let currentExpense = transactionsForMonth(transactions, month)
            .filter { $0.amount < 0 }
            .reduce(0) { $0 + abs($1.amount) }

        let pastMonths = lastNMonths(6, from: month)
        let pastExpenses = pastMonths.map {
            transactionsForMonth(transactions, $0)
                .filter { $0.amount < 0 }
                .reduce(0) { $0 + abs($1.amount) }
        }

        let avg = avgNonZero(pastExpenses)
        if currentExpense == 0 && avg == 0 {
            return AgentResponse(
                title: "Porovnanie s priemerom",
                bullets: [.init(text: "Zatiaľ nie je dosť dát na porovnanie (žiadne výdavky v aktuálnom ani minulých mesiacoch).", type: .info)]
            )
        }

        if avg == 0 {
            return AgentResponse(
                title: "Porovnanie s priemerom",
                bullets: [
                    .init(text: "Aktuálne výdavky: \(currentExpense.money)", type: .info),
                    .init(text: "Nemám z čoho spraviť priemer (minulé mesiace bez výdavkov).", type: .info)
                ]
            )
        }

        let diffPct = ((currentExpense - avg) / avg) * 100

        let type: AgentMessageType =
            diffPct > 15 ? .warning :
            diffPct < -15 ? .positive :
            .info

        let text: String
        if abs(diffPct) < 1 {
            text = "Výdavky sú približne na úrovni priemeru."
        } else if diffPct > 0 {
            text = String(format: "Výdavky sú o %.0f %% vyššie než priemer.", diffPct)
        } else {
            text = String(format: "Výdavky sú o %.0f %% nižšie než priemer.", abs(diffPct))
        }

        return AgentResponse(
            title: "Porovnanie s priemerom",
            bullets: [
                .init(text: "Aktuálne výdavky: \(currentExpense.money)", type: .info),
                .init(text: "Priemer (posledných 6 mesiacov): \(avg.money)", type: .info),
                .init(text: text, type: type)
            ]
        )
    }

    private static func topExpenses(
        _ transactions: [TransactionEntity],
        month: Date
    ) -> AgentResponse {

        let tx = transactionsForMonth(transactions, month).filter { $0.amount < 0 }
        if tx.isEmpty { return emptyForMonth(month) }

        let grouped = Dictionary(grouping: tx, by: \.category)
            .mapValues { $0.reduce(0) { $0 + abs($1.amount) } }
            .sorted { $0.value > $1.value }
            .prefix(5)

        let bullets = grouped.map {
            AgentBullet(text: "\($0.key): \($0.value.money)", type: .info)
        }

        return AgentResponse(title: "Najväčšie výdavky", bullets: bullets)
    }

    private static func warnings(
        _ transactions: [TransactionEntity],
        month: Date
    ) -> AgentResponse {

        let tx = transactionsForMonth(transactions, month)
        if tx.isEmpty { return emptyForMonth(month) }

        let income = tx.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let expense = tx.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        let net = income - expense

        var bullets: [AgentBullet] = []

        if expense > income, income > 0 {
            bullets.append(.init(text: "Výdavky presahujú príjmy – bilancia je negatívna.", type: .warning))
        }

        if income == 0, expense > 0 {
            bullets.append(.init(text: "Tento mesiac nemáš príjem, ale máš výdavky – skontroluj či nechýba import príjmov.", type: .warning))
        }

        if net < 0, abs(net) > (0.25 * max(income, 1)) {
            bullets.append(.init(text: "Negatívna bilancia je výrazná (viac než ~25% príjmu).", type: .warning))
        }

        // “najväčšia kategória” ako tip
        if expense > 0 {
            let biggest = Dictionary(grouping: tx.filter { $0.amount < 0 }, by: \.category)
                .mapValues { $0.reduce(0) { $0 + abs($1.amount) } }
                .max(by: { $0.value < $1.value })

            if let biggest {
                bullets.append(.init(text: "Najviac ťa stojí kategória „\(biggest.key)“: \(biggest.value.money).", type: .info))
            }
        }

        if bullets.isEmpty {
            bullets.append(.init(text: "Neboli zistené žiadne výrazné riziká.", type: .positive))
        }

        return AgentResponse(title: "Upozornenia", bullets: bullets)
    }

    private static func forecast(
        _ transactions: [TransactionEntity],
        month: Date
    ) -> AgentResponse {

        let pastMonths = lastNMonths(6, from: month)

        let expenses = pastMonths.map {
            transactionsForMonth(transactions, $0)
                .filter { $0.amount < 0 }
                .reduce(0) { $0 + abs($1.amount) }
        }

        let predicted = avgNonZero(expenses)

        if predicted == 0 {
            return AgentResponse(
                title: "Odhad na ďalší mesiac",
                bullets: [
                    .init(text: "Nemám dosť dát na odhad (v minulých mesiacoch nevidím výdavky).", type: .info),
                    .init(text: "Tip: naimportuj transakcie aspoň za pár mesiacov.", type: .info)
                ]
            )
        }

        return AgentResponse(
            title: "Odhad na ďalší mesiac",
            bullets: [
                .init(text: "Odhadované výdavky: \(predicted.money)", type: .info),
                .init(text: "Predikcia je priemer posledných 6 mesiacov (bez nulových mesiacov).", type: .info)
            ]
        )
    }

    // MARK: - HeatMap analytics

    private static func worstSpendingDay(
        _ transactions: [TransactionEntity]
    ) -> AgentResponse {

        let cal = Calendar.current

        let grouped = Dictionary(grouping: transactions.filter { $0.amount < 0 }) {
            cal.startOfDay(for: $0.date)
        }

        guard let worst = grouped.max(by: {
            $0.value.reduce(0) { $0 + abs($1.amount) } <
            $1.value.reduce(0) { $0 + abs($1.amount) }
        }) else {
            return .empty
        }

        let total = worst.value.reduce(0) { $0 + abs($1.amount) }

        let f = DateFormatter()
        f.locale = Locale(identifier: "sk_SK")
        f.dateStyle = .full

        return AgentResponse(
            title: "Najhorší deň",
            bullets: [
                .init(text: "Najviac si minul \(total.money) dňa \(f.string(from: worst.key)).", type: .warning)
            ]
        )
    }

    private static func riskyWeekdays(
        _ transactions: [TransactionEntity]
    ) -> AgentResponse {

        let cal = Calendar.current

        let grouped = Dictionary(grouping: transactions.filter { $0.amount < 0 }) {
            cal.component(.weekday, from: $0.date)
        }

        let averages = grouped.map { weekday, txs in
            (weekday, txs.reduce(0) { $0 + abs($1.amount) } / Double(txs.count))
        }

        guard let worst = averages.max(by: { $0.1 < $1.1 }) else {
            return .empty
        }

        let weekdayName = cal.weekdaySymbols[worst.0 - 1]

        return AgentResponse(
            title: "Rizikové dni",
            bullets: [
                .init(text: "Najviac míňaš v deň: \(weekdayName).", type: .warning),
                .init(text: "Priemerný výdavok v tento deň: \(worst.1.money).", type: .info)
            ]
        )
    }

    private static func weekendSpending(
        _ transactions: [TransactionEntity]
    ) -> AgentResponse {

        let cal = Calendar.current

        let weekend = transactions.filter {
            $0.amount < 0 &&
            (cal.component(.weekday, from: $0.date) == 1 ||
             cal.component(.weekday, from: $0.date) == 7)
        }.reduce(0) { $0 + abs($1.amount) }

        let weekday = transactions.filter {
            $0.amount < 0 &&
            (2...6).contains(cal.component(.weekday, from: $0.date))
        }.reduce(0) { $0 + abs($1.amount) }

        if weekend == 0 && weekday == 0 {
            return AgentResponse(
                title: "Víkendové výdavky",
                bullets: [.init(text: "Nemám dosť dát na porovnanie (žiadne výdavky).", type: .info)]
            )
        }

        let type: AgentMessageType = weekend > weekday ? .warning : .positive

        return AgentResponse(
            title: "Víkendové výdavky",
            bullets: [
                .init(text: "Víkend: \(weekend.money)", type: type),
                .init(text: "Pracovné dni: \(weekday.money)", type: .info),
                .init(text: weekend > weekday ? "Tip: cez víkend si skús nastaviť pevný limit na zábavu/jedlo." : "Dobré – cez víkend nemíňaš viac než cez týždeň.", type: type)
            ]
        )
    }

    // MARK: - Helpers

    private static func transactionsForMonth(
        _ transactions: [TransactionEntity],
        _ month: Date
    ) -> [TransactionEntity] {
        let cal = Calendar.current
        return transactions.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    private static func lastNMonths(
        _ n: Int,
        from date: Date
    ) -> [Date] {
        let cal = Calendar.current
        return (1...n).compactMap { cal.date(byAdding: .month, value: -$0, to: date) }
    }

    private static func emptyForMonth(_ month: Date) -> AgentResponse {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sk_SK")
        f.dateFormat = "LLLL yyyy"
        let m = f.string(from: month).capitalized
        return AgentResponse(
            title: "Žiadne dáta",
            bullets: [.init(text: "V mesiaci \(m) nemáš žiadne transakcie.", type: .info)]
        )
    }

    private static func avgNonZero(_ values: [Double]) -> Double {
        let nz = values.filter { $0 > 0 }
        guard !nz.isEmpty else { return 0 }
        return nz.reduce(0, +) / Double(nz.count)
    }
}
