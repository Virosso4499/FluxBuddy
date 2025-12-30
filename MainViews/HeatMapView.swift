import SwiftUI
import SwiftData

struct HeatMapView: View {

    @Query(sort: \TransactionEntity.date)
    private var transactions: [TransactionEntity]

    @State private var selectedDate: Date? = nil
    @State private var monthOffset: Int = 0

    private let calendar = Calendar.current

    // MARK: - Month selection
    private var selectedMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var monthStart: Date? {
        calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))
    }

    private var daysInMonth: [Date] {
        guard
            let start = monthStart,
            let range = calendar.range(of: .day, in: .month, for: start)
        else { return [] }

        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
    }

    // MARK: - Data
    private var monthlyTransactions: [TransactionEntity] {
        let cal = calendar
        return transactions.filter { cal.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var dailyExpenses: [Date: Double] {
        Dictionary(grouping: monthlyTransactions.filter { $0.amount < 0 }) {
            calendar.startOfDay(for: $0.date)
        }
        .mapValues { txs in
            txs.reduce(0) { $0 + abs($1.amount) }
        }
    }

    private var maxExpense: Double {
        dailyExpenses.values.max() ?? 0
    }

    private var selectedDayTransactions: [TransactionEntity] {
        guard let selectedDate else { return [] }
        return monthlyTransactions.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    // MARK: - UI
    var body: some View {
        NavigationStack {
            ThemedScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        header

                        monthPickerRow

                        calendarGrid
                            .glassCard()

                        if let selectedDate {
                            DayDetailCard(date: selectedDate, transactions: selectedDayTransactions)
                                .glassCard()
                        } else {
                            Text("Ťukni na deň v kalendári a zobrazím detail výdavkov.")
                                .foregroundStyle(.white.opacity(0.80))
                                .glassCard()
                        }

                        Spacer(minLength: 24)
                    }
                    .padding()
                }
            }
            .navigationTitle("HeatMap")
            .platformHideNavigationBarBackground()
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HeatMap výdavkov")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Vizualizácia dní podľa výšky výdavkov.")
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Month controls
    private var monthPickerRow: some View {
        HStack(spacing: 10) {
            Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(monthTitle(selectedMonth))
                    .font(.headline)
                    .foregroundStyle(.white)

                let total = dailyExpenses.values.reduce(0, +)
                Text("Výdavky v mesiaci: \(total.money)")
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

    // MARK: - Grid
    private var calendarGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            weekdayHeader

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 7),
                spacing: 10
            ) {
                ForEach(paddedDaysForGrid(), id: \.self) { day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear
                            .frame(height: 52)
                    }
                }
            }
        }
    }

    private var weekdayHeader: some View {
        // pondelok -> nedeľa (aby to sedelo s paddingom)
        let symbols = mondayFirstWeekdaySymbols()
        return HStack {
            ForEach(symbols.indices, id: \.self) { i in
                Text(symbols[i])
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let key = calendar.startOfDay(for: day)
        let expense = dailyExpenses[key] ?? 0
        let intensity = maxExpense == 0 ? 0 : expense / maxExpense
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedDate = day
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)

                if expense > 0 {
                    Text(expense.money)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
            }
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(heatColor(for: intensity))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    // Zarovnanie prvého dňa v mesiaci do mriežky (aby kalendár vyzeral ako kalendár)
    private func paddedDaysForGrid() -> [Date?] {
        guard let start = monthStart else { return daysInMonth.map { Optional($0) } }

        // Swift Calendar: weekday 1=Sunday...7=Saturday
        // Chceme začínať pondelkom: posun
        let weekday = calendar.component(.weekday, from: start)
        let mondayBased = (weekday + 5) % 7 // Monday=0 ... Sunday=6

        let padding = Array(repeating: Date?.none, count: mondayBased)
        return padding + daysInMonth.map { Optional($0) }
    }

    private func mondayFirstWeekdaySymbols() -> [String] {
        // pôvodne (väčšinou) začína nedeľou, my chceme pondelok
        let s = calendar.shortStandaloneWeekdaySymbols
        // s[0]=Sun ... s[6]=Sat -> posuň na Mon..Sun
        return Array(s[1...6]) + [s[0]]
    }

    private func heatColor(for intensity: Double) -> Color {
        // jemnejší heatmap look (stále čitateľné na glass)
        if intensity <= 0 {
            return Color.white.opacity(0.10)
        } else if intensity < 0.25 {
            return AppTheme.incomeColor.opacity(0.30)
        } else if intensity < 0.50 {
            return Color.yellow.opacity(0.35)
        } else if intensity < 0.75 {
            return AppTheme.expenseColor.opacity(0.55)
        } else {
            return Color.red.opacity(0.65)
        }
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sk_SK")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date).capitalized
    }
}

// MARK: - Day detail (bez vlastného backgroundu, dáme .glassCard() zvonka)
private struct DayDetailCard: View {
    let date: Date
    let transactions: [TransactionEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateTitle)
                .font(.headline)
                .foregroundStyle(.white)

            if transactions.isEmpty {
                Text("Žiadne transakcie v tento deň.")
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                VStack(spacing: 8) {
                    ForEach(transactions) { tx in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.title)
                                    .foregroundStyle(.white)
                                Text(tx.category)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            Spacer()

                            Text(tx.amount.money)
                                .foregroundStyle(tx.amount < 0
                                                 ? AppTheme.expenseColor.opacity(0.95)
                                                 : AppTheme.incomeColor.opacity(0.95)
                                )
                        }

                        if tx.id != transactions.last?.id {
                            Divider().opacity(0.22)
                        }
                    }
                }
            }
        }
    }

    private var dateTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sk_SK")
        f.dateStyle = .full
        return f.string(from: date)
    }
}
