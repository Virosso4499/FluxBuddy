import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category = "Jedlo"
    @State private var amountText = ""
    @State private var date = Date()

    // callback: už nepoužívame Transaction struct, ale čisté hodnoty
    let onSave: (_ title: String, _ category: String, _ amount: Double, _ date: Date) -> Void

    private let categories = ["Jedlo", "Bývanie", "Doprava", "Zábava", "Zdravie", "Iné"]

    var body: some View {
        NavigationStack {
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

                Text("Príjem napíš kladne (napr. 1200), výdavok so znamienkom mínus (napr. -25,90).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Nová transakcia")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložiť") { save() }
                        .disabled(parseAmount() == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func parseAmount() -> Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private func save() {
        guard let amount = parseAmount() else { return }
        onSave(title, category, amount, date)
        dismiss()
    }
}
