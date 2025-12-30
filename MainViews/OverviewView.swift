import SwiftUI
import SwiftData
import Charts

struct OverviewView: View {
    @Query(sort: \TransactionEntity.date, order: .reverse)
    private var items: [TransactionEntity]

    // MARK: - Period filter
    enum PeriodMode: String, CaseIterable, Identifiable {
        case month = "Mesiac"
        case days  = "Dni"
        case range = "Rozsah"
        var id: String { rawValue }
    }

    @State private var periodMode: PeriodMode = .month

    // month mode
    @State private var monthRef: Date = Date()

    // days mode (range inside days)
    @State private var daysFrom: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var daysTo: Date = Date()

    // range mode
    @State private var rangeFrom: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var rangeTo: Date = Date()

    // MARK: - Chart interaction
    @State private var tooltipVisible: Bool = false
    @State private var selectedBucketDate: Date? = nil

    // scroll position (iOS 17+ / macOS 14+)
    @State private var scrollPosition: Date = Date()

    // visible window (NO slider; auto)
    @State private var visibleDays: Int = 30
    private let defaultVisibleDays: Int = 30

    // MARK: - Buckets
    enum BucketGranularity { case day, month }

    struct Bucket: Identifiable {
        let id = UUID()
        let date: Date
        let income: Double
        let expense: Double
        var net: Double { income - expense }
    }

    private var bucketGranularity: BucketGranularity { .day }

    // MARK: - Effective interval
    private var filterInterval: (from: Date, to: Date) {
        let cal = Calendar.current
        switch periodMode {
        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: monthRef)) ?? monthRef
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
            return (start, end)

        case .days:
            let from = min(daysFrom, daysTo)
            let to = max(daysFrom, daysTo)
            let start = cal.startOfDay(for: from)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to)) ?? to
            return (start, end)

        case .range:
            let from = min(rangeFrom, rangeTo)
            let to = max(rangeFrom, rangeTo)
            let start = cal.startOfDay(for: from)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to)) ?? to
            return (start, end)
        }
    }

    private var domain: ClosedRange<Date> {
        filterInterval.from...filterInterval.to
    }

    private var rangeLengthInDays: Int {
        let cal = Calendar.current
        let iv = filterInterval
        let d = cal.dateComponents([.day], from: iv.from, to: iv.to).day ?? 0
        return max(d, 1)
    }

    private var filteredItems: [TransactionEntity] {
        let iv = filterInterval
        return items.filter { $0.date >= iv.from && $0.date < iv.to }
    }

    // MARK: - KPI
    private var income: Double {
        filteredItems.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var expense: Double {
        filteredItems.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }

    private var net: Double { income - expense }

    // MARK: - Buckets
    private func dayStart(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private var buckets: [Bucket] {
        let grouped = Dictionary(grouping: filteredItems) { dayStart($0.date) }
        return grouped.map { (d, txs) -> Bucket in
            let inc = txs.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
            let exp = txs.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
            return Bucket(date: d, income: inc, expense: exp)
        }
        .sorted { $0.date < $1.date }
    }

    private var effectiveSelectedBucketDate: Date? {
        selectedBucketDate ?? buckets.last?.date
    }

    private var selectedTx: [TransactionEntity] {
        guard let sel = effectiveSelectedBucketDate else { return [] }
        return filteredItems.filter { Calendar.current.isDate($0.date, inSameDayAs: sel) }
    }

    private var selectedIncome: Double {
        selectedTx.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var selectedExpense: Double {
        selectedTx.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }

    private var selectedNet: Double { selectedIncome - selectedExpense }

    // MARK: - Top categories
    struct CategoryPoint: Identifiable {
        let id = UUID()
        let category: String
        let total: Double
    }

    private var topCategories: [CategoryPoint] {
        let exp = selectedTx.filter { $0.amount < 0 }
        let grouped = Dictionary(grouping: exp) { $0.category }
        return grouped.map { (cat, txs) in
            CategoryPoint(category: cat, total: txs.reduce(0) { $0 + abs($1.amount) })
        }
        .sorted { $0.total > $1.total }
        .prefix(5)
        .map { $0 }
    }

    // MARK: - UI
    var body: some View {
        NavigationStack {
            ThemedScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {

                        header
                        periodPicker

                        HStack(spacing: 12) {
                            StatCard(title: "Príjem", value: income.money, systemImage: "arrow.down.circle")
                            StatCard(title: "Výdavky", value: expense.money, systemImage: "arrow.up.circle")
                            StatCard(title: "Bilancia", value: net.money, systemImage: "equal.circle")
                        }

                        // Chart 1
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Príjem vs Výdavky")
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                Spacer()
                                if let d = effectiveSelectedBucketDate {
                                    Chip(text: dayTitle(d))
                                }
                            }

                            if buckets.isEmpty {
                                EmptyHint()
                            } else {
                                Chart {
                                    ForEach(buckets) { b in
                                        BarMark(
                                            x: .value("Deň", b.date, unit: .day),
                                            y: .value("Suma", b.income)
                                        )
                                        .foregroundStyle(by: .value("Typ", "Príjem"))

                                        BarMark(
                                            x: .value("Deň", b.date, unit: .day),
                                            y: .value("Suma", b.expense)
                                        )
                                        .foregroundStyle(by: .value("Typ", "Výdavky"))
                                    }

                                    if let sel = effectiveSelectedBucketDate {
                                        RuleMark(x: .value("Selected", sel, unit: .day))
                                            .foregroundStyle(.black.opacity(0.35))
                                    }

                                    if tooltipVisible,
                                       let sel = effectiveSelectedBucketDate,
                                       let b = buckets.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
                                        tooltipForBucket(b)
                                    }
                                }
                                .chartForegroundStyleScale([
                                    "Príjem": AppTheme.incomeColor,
                                    "Výdavky": AppTheme.expenseColor
                                ])
                                .chartOnDarkBackground()
                                .frame(height: 240)
                                .applyHorizontalScrolling(
                                    domain: domain,
                                    visibleDays: visibleDays,
                                    scrollPosition: $scrollPosition
                                )
                                .chartOverlay { proxy in
                                    chartTapOverlay(proxy: proxy)
                                }
                            }
                        }
                        .glassCard()

                        // Chart 2
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Čistá bilancia (net)")
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                Spacer()
                                if let d = effectiveSelectedBucketDate {
                                    Chip(text: dayTitle(d))
                                }
                            }

                            if buckets.isEmpty {
                                EmptyHint()
                            } else {
                                Chart {
                                    ForEach(buckets) { b in
                                        LineMark(
                                            x: .value("Deň", b.date, unit: .day),
                                            y: .value("Net", b.net)
                                        )
                                        .foregroundStyle(AppTheme.neutralColor)

                                        PointMark(
                                            x: .value("Deň", b.date, unit: .day),
                                            y: .value("Net", b.net)
                                        )
                                        .foregroundStyle(AppTheme.neutralColor)
                                    }

                                    if let sel = effectiveSelectedBucketDate {
                                        RuleMark(x: .value("Selected", sel, unit: .day))
                                            .foregroundStyle(.black.opacity(0.35))
                                    }

                                    if tooltipVisible,
                                       let sel = effectiveSelectedBucketDate,
                                       let b = buckets.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
                                        tooltipForBucket(b)
                                    }
                                }
                                .chartOnDarkBackground()
                                .frame(height: 210)
                                .applyHorizontalScrolling(
                                    domain: domain,
                                    visibleDays: visibleDays,
                                    scrollPosition: $scrollPosition
                                )
                                .chartOverlay { proxy in
                                    chartTapOverlay(proxy: proxy)
                                }
                            }

                            if effectiveSelectedBucketDate != nil {
                                Divider().opacity(0.25)

                                HStack(spacing: 12) {
                                    SmallKPI(title: "Príjem", value: selectedIncome.money, systemImage: "arrow.down.circle")
                                    SmallKPI(title: "Výdavky", value: selectedExpense.money, systemImage: "arrow.up.circle")
                                    SmallKPI(title: "Net", value: selectedNet.money, systemImage: "equal.circle")
                                }

                                if !topCategories.isEmpty {
                                    Text("Top kategórie (výdavky)")
                                        .font(.subheadline)
                                        .foregroundStyle(.black.opacity(0.85))
                                        .padding(.top, 2)

                                    VStack(spacing: 8) {
                                        ForEach(topCategories) { c in
                                            HStack {
                                                Text(c.category)
                                                    .lineLimit(1)
                                                    .foregroundStyle(.black)
                                                Spacer()
                                                Text(c.total.money)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.black)
                                            }
                                            .font(.subheadline)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            }
                        }
                        .glassCard()

                        Spacer(minLength: 16)
                    }
                    .padding()
                }
            }
            .navigationTitle("Prehľad")
            .platformHideNavigationBarBackground()
            .onAppear { refreshWindowAndScroll() }
            .onChange(of: periodMode) { _, _ in refreshWindowAndScroll() }
            .onChange(of: monthRef) { _, _ in refreshWindowAndScroll() }
            .onChange(of: daysFrom) { _, _ in refreshWindowAndScroll() }
            .onChange(of: daysTo) { _, _ in refreshWindowAndScroll() }
            .onChange(of: rangeFrom) { _, _ in refreshWindowAndScroll() }
            .onChange(of: rangeTo) { _, _ in refreshWindowAndScroll() }
        }
    }

    private func refreshWindowAndScroll() {
        // okno len automaticky: krátky rozsah = ukáž celý, dlhý = 30 dní
        visibleDays = min(max(7, rangeLengthInDays), defaultVisibleDays)

        // ✅ scroll začína na začiatku intervalu (a zarovná na deň)
        scrollPosition = dayStart(filterInterval.from)

        // selection reset
        selectedBucketDate = nil
        tooltipVisible = false
    }

    // MARK: - Period Picker
    private var periodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $periodMode) {
                ForEach(PeriodMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch periodMode {
            case .month:
                DatePicker("Mesiac", selection: $monthRef, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .tint(.black)
                    .foregroundStyle(.black)

            case .days:
                DatePicker("Od", selection: $daysFrom, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .tint(.black)
                    .foregroundStyle(.black)

                DatePicker("Do", selection: $daysTo, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .tint(.black)
                    .foregroundStyle(.black)

            case .range:
                DatePicker("Od", selection: $rangeFrom, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .tint(.black)
                    .foregroundStyle(.black)

                DatePicker("Do", selection: $rangeTo, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .tint(.black)
                    .foregroundStyle(.black)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Tap overlay (tap to show/hide tooltip; DOES NOT BLOCK SCROLL)
    @ViewBuilder
    private func chartTapOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .simultaneousGesture(tapGesture(proxy: proxy, geo: geo))
        }
    }

    private func tapGesture(proxy: ChartProxy, geo: GeometryProxy) -> some Gesture {
        if #available(iOS 17.0, macOS 14.0, *) {
            return AnyGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleTap(location: value.location, proxy: proxy, geo: geo)
                    }
            )
        } else {
            return AnyGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        handleTap(location: value.location, proxy: proxy, geo: geo)
                    }
            )
        }
    }

    private func handleTap(location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plot: CGRect
        if #available(iOS 17.0, macOS 14.0, *) {
            guard let anchor = proxy.plotFrame else { tooltipVisible = false; return }
            plot = geo[anchor]
        } else {
            plot = geo[proxy.plotAreaFrame]
        }

        guard plot.contains(location) else {
            tooltipVisible = false
            return
        }

        let x = min(max(location.x - plot.origin.x, 0), plot.size.width)
        guard let date: Date = proxy.value(atX: x) else {
            tooltipVisible = false
            return
        }

        let tapped = dayStart(date)

        if let current = selectedBucketDate,
           Calendar.current.isDate(current, inSameDayAs: tapped) {
            tooltipVisible.toggle()
        } else {
            selectedBucketDate = tapped
            tooltipVisible = true
        }
    }

    // MARK: - Tooltip (high contrast)
    @ChartContentBuilder
    private func tooltipForBucket(_ b: Bucket) -> some ChartContent {
        PointMark(
            x: .value("A", b.date, unit: .day),
            y: .value("B", max(b.income, b.expense, abs(b.net)))
        )
        .opacity(0.001)
        .annotation(position: .top, alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dayTitle(b.date))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)

                HStack(spacing: 8) {
                    Text("Príjem").foregroundStyle(.black.opacity(0.75))
                    Spacer()
                    Text(b.income.money).foregroundStyle(.black).fontWeight(.semibold)
                }
                .font(.caption)

                HStack(spacing: 8) {
                    Text("Výdavky").foregroundStyle(.black.opacity(0.75))
                    Spacer()
                    Text(b.expense.money).foregroundStyle(.black).fontWeight(.semibold)
                }
                .font(.caption)

                HStack(spacing: 8) {
                    Text("Net").foregroundStyle(.black.opacity(0.75))
                    Spacer()
                    Text(b.net.money).foregroundStyle(.black).fontWeight(.semibold)
                }
                .font(.caption)
            }
            .padding(10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.black.opacity(0.25), lineWidth: 1)
            )
            .shadow(radius: 6)
        }
    }

    // MARK: - Helpers
    private func dayTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sk_SK")
        f.dateFormat = "d. MMM yyyy"
        return f.string(from: date).capitalized
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FluxBuddy")
                .font(.largeTitle.bold())
                .foregroundStyle(.black)

            Text("Rýchly prehľad tvojich financií.")
                .foregroundStyle(.black.opacity(0.85))
        }
    }
}

// MARK: - Horizontal scrolling helper (iOS + macOS) ✅
// Toto je tá kľúčová časť – bez nej to typicky ostane “len august”.
private extension View {
    func applyHorizontalScrolling(
        domain: ClosedRange<Date>,
        visibleDays: Int,
        scrollPosition: Binding<Date>
    ) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            return AnyView(
                self
                    .chartXScale(domain: domain.lowerBound...domain.upperBound) // celý rozsah
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: TimeInterval(visibleDays) * 86_400)
                    .chartScrollPosition(x: scrollPosition)
            )
        } else {
            return AnyView(
                self.chartXScale(domain: domain.lowerBound...domain.upperBound)
            )
        }
    }
}


// MARK: - UI components

private struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(.black.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.12), lineWidth: 1))
            .foregroundStyle(.black)
    }
}

private struct EmptyHint: View {
    var body: some View {
        Text("Zatiaľ tu nie sú dáta na graf.")
            .foregroundStyle(.black.opacity(0.75))
            .padding(.top, 6)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title).font(.caption)
            }
            .foregroundStyle(.black.opacity(0.80))

            Text(value)
                .font(.headline)
                .foregroundStyle(.black)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SmallKPI: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title).font(.caption)
            }
            .foregroundStyle(.black.opacity(0.75))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.black.opacity(0.10), lineWidth: 1)
        )
    }
}
