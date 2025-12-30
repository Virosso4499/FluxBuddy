import Foundation
import SwiftData

@Model
final class TransactionEntity {
    var title: String
    var category: String
    var amount: Double      // + príjem, - výdavok
    var date: Date

    init(title: String, category: String, amount: Double, date: Date = .now) {
        self.title = title
        self.category = category
        self.amount = amount
        self.date = date
    }
}
