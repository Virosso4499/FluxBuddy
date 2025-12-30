import Foundation
import SwiftData

@Model
final class RecurringEntity {
    var title: String
    var category: String
    var amount: Double      // + príjem, - výdavok
    var dayOfMonth: Int     // 1..28 (kvôli jednoduchosti)
    var isActive: Bool

    init(title: String, category: String, amount: Double, dayOfMonth: Int, isActive: Bool = true) {
        self.title = title
        self.category = category
        self.amount = amount
        self.dayOfMonth = dayOfMonth
        self.isActive = isActive
    }
}
