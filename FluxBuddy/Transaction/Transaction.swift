import Foundation

struct Transaction: Identifiable, Codable {
    let id: UUID
    let title: String
    let category: String
    let amount: Double   // + príjem, - výdavok
    let date: Date

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        amount: Double,
        date: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.amount = amount
        self.date = date
    }
}
