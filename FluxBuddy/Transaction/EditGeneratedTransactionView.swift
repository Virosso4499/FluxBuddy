import SwiftUI

struct EditGeneratedTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    let tx: TransactionEntity

    @State private var title: String = ""
    @State private var category: String = ""
    @State private var amountText: String = ""
    @State private var date: Date = .now

    private let categories = ["Jedlo", "Bývanie", "Doprava", "Zábava", "Zdravie", "Iné", "Príjem"]

    var body: some View {
        Form {
            TextField("Názov", text: $title)

            Picker("Kategória", selection: $category) {
                ForEach(categories, id: \.self) { Text($0) }
            }

            DatePicker("Dátum", selection: $date, displayedComponents: .date)

            TextField("Suma (EUR)", text: $amountText)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif

            Button("Uložiť zmeny") {
                apply()
                dismiss()
            }
            .disabled(parseAmount() == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("Upraviť")
        .onAppear {
            title = tx.title
            category = tx.category
            amountText = String(tx.amount).replacingOccurrences(of: ".", with: ",")
            date = tx.date
        }
    }

    private func parseAmount() -> Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private func apply() {
        guard let amount = parseAmount() else { return }
        tx.title = title
        tx.category = category
        tx.amount = amount
        tx.date = date
    }
}
//
//  EditGeneratedTransactionView.swift
//  FluxBuddy
//
//  Created by Matúš Juhász on 23/12/2025.
//

