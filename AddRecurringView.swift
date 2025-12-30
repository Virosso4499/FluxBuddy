import SwiftUI

struct AddRecurringView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category = "Bývanie"
    @State private var amountText = ""
    @State private var dayOfMonth = 1

    let onSave: (_ title: String, _ category: String, _ amount: Double, _ dayOfMonth: Int) -> Void

    private let categories = ["Jedlo", "Bývanie", "Doprava", "Zábava", "Zdravie", "Iné", "Príjem"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Názov", text: $title)

                Picker("Kategória", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0) }
                }

                Stepper("Deň v mesiaci: \(dayOfMonth)", value: $dayOfMonth, in: 1...28)

                TextField("Suma (EUR)", text: $amountText)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif

                Text("Príjem kladne (napr. 1200), výdavok so znamienkom mínus (napr. -450).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Opakovaná položka")
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
        onSave(title, category, amount, dayOfMonth)
        dismiss()
    }
}
