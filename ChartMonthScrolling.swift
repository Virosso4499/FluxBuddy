import SwiftUI
import Charts

extension Date {
    func startOfMonth(using cal: Calendar = .current) -> Date {
        let comps = cal.dateComponents([.year, .month], from: self)
        return cal.date(from: comps) ?? self
    }

    func addingMonths(_ value: Int, using cal: Calendar = .current) -> Date {
        cal.date(byAdding: .month, value: value, to: self) ?? self
    }
}

extension ClosedRange where Bound == Date {
    func clamped(_ date: Date) -> Date {
        if date < lowerBound { return lowerBound }
        if date > upperBound { return upperBound }
        return date
    }
}


struct MonthScrollableChart<Content: ChartContent>: View {
    let domain: ClosedRange<Date>
    let initialMonth: Date
    @ChartContentBuilder let content: () -> Content

    @State private var scrollX: Date = .now

    init(
        domain: ClosedRange<Date>,
        initialMonth: Date? = nil,
        @ChartContentBuilder content: @escaping () -> Content
    ) {
        self.domain = domain
        self.initialMonth = (initialMonth ?? domain.lowerBound).startOfMonth()
        self.content = content
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            Chart {
                content()
            }
            .chartXScale(domain: domain.lowerBound...domain.upperBound)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 60 * 60 * 24 * 31) // ~1 mesiac
            .chartScrollPosition(x: $scrollX)
            .onAppear { scrollX = initialMonth }
            .frame(minHeight: 220)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { jump(by: -1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(monthTitle(scrollX)).font(.headline)
            Spacer()
            Button { jump(by: 1) } label: { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private func jump(by months: Int) {
        let target = scrollX.startOfMonth().addingMonths(months)
        scrollX = (domain.lowerBound...domain.upperBound).clamped(target)
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }
}
