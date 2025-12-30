import SwiftUI
import SwiftData
import Charts

struct ForecastView: View {

    @Query(sort: \TransactionEntity.date, order: .reverse)
    private var transactions: [TransactionEntity]

    @State private var didGenerate: Bool = false
    @State private var lastGeneratedAt: Date? = nil
    @State private var lastResult: ForecastResult? = nil

    var body: some View {
        NavigationStack {
            ThemedScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        header

                        // MARK: - Action
                        Button {
                            let r = ForecastCalculator.forecast(transactions: transactions)
                            lastResult = r
                            didGenerate = true
                            lastGeneratedAt = Date()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                Text("Vygenerovať predikciu")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .opacity(0.75)
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(.white.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.white.opacity(0.18), lineWidth: 1)
                            )
                        }

                        if let lastGeneratedAt, didGenerate {
                            Text("Naposledy vygenerované: \(dateTimeText(lastGeneratedAt))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.top, -6)
                        }

                        // MARK: - Result
                        if let result = lastResult {

                            // Forecast cards (adaptívne)
                            AdaptiveTwoColumn {
                                ForecastCard(
                                    title: "Odhad príjmu",
                                    value: result.avgIncome.money,
                                    systemImage: "arrow.down.circle",
                                    accent: AppTheme.incomeColor
                                )

                                ForecastCard(
                                    title: "Odhad výdavkov",
                                    value: result.avgExpense.money,
                                    systemImage: "arrow.up.circle",
                                    accent: AppTheme.expenseColor
                                )
                            }

                            ForecastCard(
                                title: "Očakávaná bilancia",
                                value: result.predictedNet.money,
                                systemImage: "equal.circle",
                                accent: result.predictedNet >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor
                            )

                            // mini graf (6 mesiacov)
                            ForecastMiniChart(monthly: result.monthly)
                                .glassCard()

                            // detail – čo bolo použité
                            ForecastDetails(result: result)
                                .glassCard()

                            ForecastExplanation(net: result.predictedNet)

                        } else {
                            Text("Stlač „Vygenerovať predikciu“ a ukážem ti, z čoho sa odhad počíta + čo presne vyšlo.")
                                .foregroundStyle(.white.opacity(0.85))
                                .glassCard()
                        }

                        Spacer(minLength: 24)
                    }
                    .padding()
                }
            }
            .navigationTitle("Forecast")
            .platformHideNavigationBarBackground()
            .onAppear {
                // prvé automatické naplnenie (aby niečo videl hneď)
                let r = ForecastCalculator.forecast(transactions: transactions)
                lastResult = r
                lastGeneratedAt = Date()
                didGenerate = true
            }
        }
    }

    // MARK: - UI
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Predikcia vývoja")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Odhad výdavkov a bilancie na základe minulých mesiacov.")
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func dateTimeText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sk_SK")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}

// MARK: - Components

private struct ForecastCard: View {
    let title: String
    let value: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.white.opacity(0.9))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)

            Text("Priemer posledných 6 mesiacov")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.70))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

private struct ForecastMiniChart: View {
    let monthly: [(month: Date, income: Double, expense: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Použité mesiace (6)")
                .font(.headline)
                .foregroundStyle(.white)

            Chart {
                ForEach(Array(monthly.enumerated()), id: \.offset) { _, m in
                    BarMark(
                        x: .value("Mesiac", m.month, unit: .month),
                        y: .value("Príjem", m.income)
                    )
                    .foregroundStyle(by: .value("Typ", "Príjem"))

                    BarMark(
                        x: .value("Mesiac", m.month, unit: .month),
                        y: .value("Výdavky", m.expense)
                    )
                    .foregroundStyle(by: .value("Typ", "Výdavky"))
                    .opacity(0.85)
                }
            }
            .chartForegroundStyleScale([
                "Príjem": AppTheme.incomeColor,
                "Výdavky": AppTheme.expenseColor
            ])
            .chartOnDarkBackground()
            .frame(height: 180)
            .chartLegend(.visible)
        }
    }
}

private struct ForecastDetails: View {
    let result: ForecastResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Čo sa vygenerovalo")
                .font(.headline)
                .foregroundStyle(.white)

            HStack {
                Text("Priemerný príjem:")
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(result.avgIncome.money)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
            }

            HStack {
                Text("Priemerné výdavky:")
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(result.avgExpense.money)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
            }

            Divider().opacity(0.22)

            HStack {
                Text("Predikované net:")
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(result.predictedNet.money)
                    .foregroundStyle(result.predictedNet >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor)
                    .fontWeight(.bold)
            }

            Text("Tip: ak chceš upraviť vstupy, choď do Cashflow a skontroluj posledné mesiace alebo si nastav limit v Plán.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

private struct ForecastExplanation: View {
    let net: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ako sa počíta predikcia")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Predikcia vychádza z priemerných príjmov a výdavkov za posledných 6 mesiacov.")
                .foregroundStyle(.white.opacity(0.85))

            if net < 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("⚠️ Očakáva sa negatívna bilancia.")
                        .foregroundStyle(AppTheme.expenseColor)
                        .fontWeight(.semibold)
                    Text("Zváž zníženie výdavkov alebo zvýšenie príjmu. Skús si nastaviť limit v záložke Plán.")
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("✅ Očakáva sa pozitívna bilancia.")
                        .foregroundStyle(AppTheme.incomeColor)
                        .fontWeight(.semibold)
                    Text("Ak zachováš aktuálne správanie, mal by si byť v pluse aj ďalší mesiac.")
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .glassCard()
    }
}

// MARK: - Layout helper (2 stĺpce keď je miesto, inak pod seba)
private struct AdaptiveTwoColumn<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { content }
            VStack(spacing: 12) { content }
        }
    }
}
