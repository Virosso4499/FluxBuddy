import SwiftUI

struct GeneratedTransactionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var items: [TransactionEntity]

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    Text("Nevytvorili sa žiadne nové položky (pravdepodobne už boli vygenerované).")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { tx in
                        NavigationLink {
                            EditGeneratedTransactionView(tx: tx)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(tx.title).font(.headline)
                                    Text(tx.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(tx.date, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(tx.amount, format: .currency(code: "EUR"))
                                    .foregroundStyle(tx.amount >= 0 ? .green : .red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Vygenerované")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hotovo") { dismiss() }
                }
            }
        }
    }
}
