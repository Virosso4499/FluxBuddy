import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TransactionEntity.date, order: .reverse) private var items: [TransactionEntity]

    @State private var monthOffset: Int = 0

    @State private var showImporter = false
    @State private var importError: String?

    // MARK: - Month selection
    private var selectedMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var filtered: [TransactionEntity] {
        let cal = Calendar.current
        return items.filter { cal.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
    }

    // MARK: - KPIs
    private var income: Double {
        filtered.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var expense: Double {
        filtered.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }

    private var net: Double { income - expense }

    // MARK: - Chart data
    struct DayPoint: Identifiable {
        let id = UUID()
        let day: Date
        let net: Double
        let income: Double
        let expense: Double
    }

    private var dailyPoints: [DayPoint] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.date) }
        return grouped.map { (d, txs) in
            let inc = txs.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
            let exp = txs.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
            let n = txs.reduce(0) { $0 + $1.amount }
            return DayPoint(day: d, net: n, income: inc, expense: exp)
        }
        .sorted { $0.day < $1.day }
    }

    struct CategoryPoint: Identifiable {
        let id = UUID()
        let category: String
        let total: Double
    }

    private var expensesByCategory: [CategoryPoint] {
        let exp = filtered.filter { $0.amount < 0 }
        let grouped = Dictionary(grouping: exp) { $0.category }
        return grouped.map { (cat, txs) in
            CategoryPoint(category: cat, total: txs.reduce(0) { $0 + abs($1.amount) })
        }
        .sorted { $0.total > $1.total }
        .prefix(8)
        .map { $0 }
    }

    private var totalCategoryExpense: Double {
        expensesByCategory.reduce(0) { $0 + $1.total }
    }

    // MARK: - UI
    var body: some View {
        NavigationStack {
            ThemedScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        kpiRow
                        chartsBlock
                        listBlock
                    }
                    .padding()
                }
            }
            .navigationTitle("Cashflow")
            .platformHideNavigationBarBackground()
            .toolbar {
                ToolbarItem(placement: .platformTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                            .foregroundStyle(.white)
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    try importCSV(from: url)
                } catch {
                    importError = error.localizedDescription
                }
            }
            .alert("Import error", isPresented: .constant(importError != nil)) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(monthTitle(selectedMonth))
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("\(filtered.count) transakcií")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            Button { monthOffset = 0 } label: { Text("Dnes").font(.subheadline) }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.20))
                .foregroundStyle(.white)

            Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
        }
    }

    private var kpiRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Príjem", value: income.money, systemImage: "arrow.down.circle")
            StatCard(title: "Výdavky", value: expense.money, systemImage: "arrow.up.circle")
            StatCard(title: "Net", value: net.money, systemImage: "equal.circle")
        }
    }

    private var chartsBlock: some View {
        VStack(spacing: 12) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Net podľa dní")
                    .font(.headline)
                    .foregroundStyle(.white)

                if dailyPoints.isEmpty {
                    EmptyChartHint()
                } else {
                    Chart {
                        ForEach(dailyPoints) { p in
                            LineMark(
                                x: .value("Deň", p.day),
                                y: .value("Net", p.net)
                            )
                            .foregroundStyle(AppTheme.neutralColor)

                            PointMark(
                                x: .value("Deň", p.day),
                                y: .value("Net", p.net)
                            )
                            .foregroundStyle(AppTheme.neutralColor)
                        }
                    }
                    .chartOnDarkBackground()
                    .frame(height: 200)
                }
            }
            .glassCard()

            VStack(alignment: .leading, spacing: 8) {
                Text("Príjem vs Výdavky (dni)")
                    .font(.headline)
                    .foregroundStyle(.white)

                if dailyPoints.isEmpty {
                    EmptyChartHint()
                } else {
                    Chart {
                        ForEach(dailyPoints) { p in
                            BarMark(
                                x: .value("Deň", p.day),
                                y: .value("Suma", p.income)
                            )
                            .foregroundStyle(by: .value("Typ", "Príjem"))

                            BarMark(
                                x: .value("Deň", p.day),
                                y: .value("Suma", p.expense)
                            )
                            .foregroundStyle(by: .value("Typ", "Výdavky"))
                        }
                    }
                    .chartForegroundStyleScale([
                        "Príjem": AppTheme.incomeColor,
                        "Výdavky": AppTheme.expenseColor
                    ])
                    .chartOnDarkBackground()
                    .frame(height: 200)
                    .chartLegend(.visible)
                }
            }
            .glassCard()

            // ✅ Donut/Pie: Výdavky podľa kategórie
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Výdavky podľa kategórie")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if totalCategoryExpense > 0 {
                        Text(totalCategoryExpense.money)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                if expensesByCategory.isEmpty {
                    EmptyChartHint(text: "V tomto mesiaci nemáš žiadne výdavky.")
                } else {
                    if #available(iOS 17.0, *) {
                        Chart {
                            ForEach(expensesByCategory) { p in
                                SectorMark(
                                    angle: .value("Suma", p.total),
                                    innerRadius: .ratio(0.62),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(by: .value("Kategória", p.category))
                            }
                        }
                        // nech to nie je čierne + osy netreba
                        .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
                        .frame(height: 260)
                        .padding(.top, 2)

                        // “Top 3” text pod grafom pre čitateľnosť
                        VStack(spacing: 6) {
                            ForEach(Array(expensesByCategory.prefix(3).enumerated()), id: \.offset) { _, p in
                                HStack {
                                    Text(p.category)
                                        .foregroundStyle(.white.opacity(0.90))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(p.total.money)
                                        .foregroundStyle(.white)
                                        .fontWeight(.semibold)
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.top, 4)

                    } else {
                        // iOS 16 fallback: horizontálne bary
                        Chart {
                            ForEach(expensesByCategory) { p in
                                BarMark(
                                    x: .value("Suma", p.total),
                                    y: .value("Kategória", p.category)
                                )
                                .foregroundStyle(AppTheme.expenseColor.opacity(0.85))
                            }
                        }
                        .chartOnDarkBackground()
                        .frame(height: 240)
                    }
                }
            }
            .glassCard()
        }
    }

    private var listBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Transakcie")
                .font(.headline)
                .foregroundStyle(.white)

            if filtered.isEmpty {
                Text("Žiadne transakcie v tomto mesiaci.")
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(filtered) { t in
                        TransactionRow(t: t)
                        Divider().opacity(0.22)
                    }
                }
            }
        }
        .glassCard()
    }

    // MARK: - CSV import (simple)
    // CSV stĺpce: date,title,category,amount
    // date format: yyyy-MM-dd
    private func importCSV(from url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else { return }

        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        if lines.isEmpty { return }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let startIndex = lines[0].lowercased().contains("date") ? 1 : 0

        for line in lines[startIndex...] {
            let cols = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            guard cols.count >= 4 else { continue }

            let date = df.date(from: cols[0]) ?? Date()
            let title = cols[1]
            let category = cols[2]
            let amount = Double(cols[3].replacingOccurrences(of: " ", with: "")) ?? 0

            let tx = TransactionEntity(title: title, category: category, amount: amount, date: date)
            context.insert(tx)
        }

        try context.save()
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sk_SK")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date).capitalized
    }
}

// MARK: - UI pieces

private struct EmptyChartHint: View {
    var text: String = "Zatiaľ tu nie sú dáta na graf."
    var body: some View {
        Text(text)
            .foregroundStyle(.white.opacity(0.8))
            .padding(.top, 6)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.85))

            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct TransactionRow: View {
    let t: TransactionEntity

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)

                Text(t.category)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))

                Text(dateText(t.date))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.70))
            }

            Spacer()

            Text(t.amount.money)
                .font(.headline)
                .foregroundStyle(t.amount < 0 ? AppTheme.expenseColor : AppTheme.incomeColor)
        }
    }

    private func dateText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sk_SK")
        f.dateStyle = .medium
        return f.string(from: d)
    }
}
