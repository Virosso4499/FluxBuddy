import SwiftUI
import SwiftData
import Charts

struct PlanView: View {
    @Query(sort: \TransactionEntity.date, order: .reverse) private var items: [TransactionEntity]

    @AppStorage("plan_total_monthly_expense") private var plannedTotalExpense: Double = 800
    @AppStorage("plan_category_json") private var categoryJSON: String = ""

    @State private var monthOffset: Int = 0

    private var selectedMonth: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var filtered: [TransactionEntity] {
        let cal = Calendar.current
        return items.filter { cal.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var realExpense: Double {
        filtered.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }

    private var remaining: Double { plannedTotalExpense - realExpense }

    // MARK: - Planned categories
    struct PlannedCategory: Identifiable, Codable, Equatable {
        var id = UUID()
        var name: String
        var planned: Double
    }

    @State private var plannedCategories: [PlannedCategory] = [
        .init(name: "Jedlo", planned: 250),
        .init(name: "Bývanie", planned: 400),
        .init(name: "Doprava", planned: 100),
        .init(name: "Zábava", planned: 80)
    ]

    // MARK: - Real vs Planned chart points
    struct CategoryPoint: Identifiable {
        let id = UUID()
        let name: String
        let real: Double
        let planned: Double
    }

    private var categoryPoints: [CategoryPoint] {
        let expenses = filtered.filter { $0.amount < 0 }
        let realGrouped = Dictionary(grouping: expenses) { $0.category }
        let realMap: [String: Double] = realGrouped.mapValues { txs in
            txs.reduce(0) { $0 + abs($1.amount) }
        }

        let plannedMap = Dictionary(uniqueKeysWithValues: plannedCategories.map { ($0.name, $0.planned) })
        let allNames = Set(realMap.keys).union(plannedMap.keys)

        return allNames.map { name in
            CategoryPoint(
                name: name,
                real: realMap[name] ?? 0,
                planned: plannedMap[name] ?? 0
            )
        }
        .sorted { $0.real > $1.real }
    }

    var body: some View {
        NavigationStack {
            ThemedScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        totalPlanCard
                        planVsRealityChart
                        categoriesChart
                        categoriesEditor
                    }
                    .padding()
                }
            }
            .navigationTitle("Plán")
            .platformHideNavigationBarBackground()
            .onAppear { loadCategories() }
            .onChange(of: plannedCategories) { _, _ in saveCategories() }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 10) {
            Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(monthTitle(selectedMonth))
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Výdavky: \(realExpense.money)")
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

    // MARK: - Cards
    private var totalPlanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mesačný plán výdavkov")
                .font(.headline)
                .foregroundStyle(.white)

            HStack {
                Text("Plán: \(plannedTotalExpense.money)")
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Slider(value: $plannedTotalExpense, in: 0...5000, step: 10)
                    .frame(maxWidth: 260)
            }

            let text = remaining >= 0
            ? "Si v limite: \(remaining.money)"
            : "Si nad limitom: \(abs(remaining).money)"

            Text(text)
                .foregroundStyle(remaining >= 0 ? .white.opacity(0.85) : .orange)
        }
        .glassCard()
    }

    private var planVsRealityChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plán vs Realita")
                .font(.headline)
                .foregroundStyle(.white)

            Chart {
                BarMark(x: .value("Typ", "Plán"), y: .value("Suma", plannedTotalExpense))
                    .foregroundStyle(by: .value("Typ", "Plán"))

                BarMark(x: .value("Typ", "Realita"), y: .value("Suma", realExpense))
                    .foregroundStyle(by: .value("Typ", "Realita"))
            }
            .chartForegroundStyleScale([
                "Plán": AppTheme.neutralColor,
                "Realita": AppTheme.expenseColor
            ])
            .chartOnDarkBackground()
            .frame(height: 200)
            .chartLegend(.visible)
        }
        .glassCard()
    }

    private var categoriesChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kategórie: plán vs real")
                .font(.headline)
                .foregroundStyle(.white)

            if categoryPoints.isEmpty {
                Text("Zatiaľ nemáš dáta v tomto mesiaci.")
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 6)
            } else {
                Chart {
                    ForEach(categoryPoints) { p in
                        BarMark(
                            x: .value("Suma", p.real),
                            y: .value("Kategória", p.name)
                        )
                        .foregroundStyle(by: .value("Typ", "Real"))

                        BarMark(
                            x: .value("Suma", p.planned),
                            y: .value("Kategória", p.name)
                        )
                        .foregroundStyle(by: .value("Typ", "Plán"))
                        .opacity(0.55)
                    }
                }
                .chartForegroundStyleScale([
                    "Real": AppTheme.expenseColor,
                    "Plán": AppTheme.neutralColor
                ])
                .chartOnDarkBackground()
                .frame(height: 260)
                .chartLegend(.visible)
            }
        }
        .glassCard()
    }

    private var categoriesEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Upraviť plány kategórií")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    plannedCategories.append(.init(name: "Nová", planned: 50))
                } label: {
                    Label("Pridať", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.20))
                .foregroundStyle(.white)
            }

            ForEach($plannedCategories) { $c in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        TextField("Kategória", text: $c.name)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            plannedCategories.removeAll { $0.id == c.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.20))
                        .foregroundStyle(.white)
                    }

                    HStack {
                        Text("Plán: \(c.planned.money)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))

                        Spacer()

                        Slider(value: $c.planned, in: 0...3000, step: 10)
                            .frame(maxWidth: 260)
                    }
                }

                Divider().opacity(0.22)
            }
        }
        .glassCard()
    }

    // MARK: - Persistence
    private func saveCategories() {
        do {
            let data = try JSONEncoder().encode(plannedCategories)
            categoryJSON = String(data: data, encoding: .utf8) ?? ""
        } catch { }
    }

    private func loadCategories() {
        guard !categoryJSON.isEmpty,
              let data = categoryJSON.data(using: .utf8) else { return }
        do {
            plannedCategories = try JSONDecoder().decode([PlannedCategory].self, from: data)
        } catch { }
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sk_SK")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date).capitalized
    }
}
