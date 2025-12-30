import SwiftUI
import SwiftData

@main
struct FluxBuddyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [TransactionEntity.self, BudgetEntity.self, RecurringEntity.self])
    }
}
