import Foundation

struct MonthBucket: Identifiable {
    let id = UUID()
    let month: Date
    let income: Double
    let expense: Double
    var net: Double { income - expense }
}

func monthStart(_ date: Date) -> Date {
    Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
}
