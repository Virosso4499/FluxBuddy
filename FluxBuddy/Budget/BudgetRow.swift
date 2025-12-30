import SwiftUI

struct BudgetRow: View {
    let category: String
    let budget: BudgetEntity?
    let spent: Double
    let onSave: (Double) -> Void

    @State private var limitText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(category).font(.headline)
                Spacer()
                Text(spent, format: .currency(code: "EUR"))
                    .foregroundStyle(spentColor)
            }

            ProgressView(value: progress)
                .tint(spentColor)

            HStack {
                TextField(
                    "Limit (EUR)",
                    text: $limitText,
                    onCommit: save
                )
#if os(iOS)
                .keyboardType(.decimalPad)
#endif
                Spacer()
                Text(limitText.isEmpty ? "—" : "\(remaining, format: .currency(code: "EUR"))")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(.vertical, 6)
        .onAppear {
            if let limit = budget?.limit {
                limitText = String(format: "%.0f", limit)
            }
        }
    }

    private var limit: Double {
        Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var remaining: Double {
        max(limit - spent, 0)
    }

    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(spent / limit, 1)
    }

    private var spentColor: Color {
        spent > limit ? .red : .green
    }

    private func save() {
        guard limit > 0 else { return }
        onSave(limit)
    }
}
