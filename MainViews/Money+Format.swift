import Foundation

extension Double {
    var money: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
