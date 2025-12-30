import Foundation
import SwiftData

@Model
final class BudgetEntity {
    var category: String
    var limit: Double      // mesačný limit v EUR

    init(category: String, limit: Double) {
        self.category = category
        self.limit = limit
    }
}
