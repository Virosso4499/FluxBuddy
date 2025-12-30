import SwiftUI
import SwiftData

struct AgentView: View {

    @Query(sort: \TransactionEntity.date, order: .reverse)
    private var transactions: [TransactionEntity]

    @State private var selectedQuestion: AgentQuestion?
    @State private var response: AgentResponse?

    @State private var didGenerate: Bool = false
    @State private var lastGeneratedAt: Date? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ThemedScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        header

                        if didGenerate, let lastGeneratedAt {
                            generatedBanner(date: lastGeneratedAt)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if let selectedQuestion {
                            selectedRow(selectedQuestion)
                                .transition(.opacity)
                        }

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(AgentQuestion.allCases) { question in
                                QuestionCard(
                                    question: question,
                                    isSelected: question.id == selectedQuestion?.id
                                ) {
                                    answer(question)
                                }
                            }
                        }

                        if let response {
                            ResponseCard(response: response)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer(minLength: 24)
                    }
                    .padding()
                }
            }
            .navigationTitle("Asistent")
            .iosHideNavigationBarBackround()
        }
    }

    // MARK: - Actions

    private func answer(_ question: AgentQuestion) {
        let r = FinanceAgent.answer(
            question: question,
            transactions: transactions,
            referenceMonth: Date()
        )

        withAnimation(.easeInOut(duration: 0.25)) {
            selectedQuestion = question
            response = r
            didGenerate = true
            lastGeneratedAt = Date()
        }
    }

    private func clear() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedQuestion = nil
            response = nil
            didGenerate = false
            lastGeneratedAt = nil
        }
    }

    // MARK: - UI

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Finančný asistent")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Vyber otázku a získaj prehľad o svojich financiách.")
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func generatedBanner(date: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.white.opacity(0.95))

            VStack(alignment: .leading, spacing: 2) {
                Text("Odpoveď vygenerovaná")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(dateTimeText(date))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            Button {
                clear()
            } label: {
                Label("Vymazať", systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func selectedRow(_ q: AgentQuestion) -> some View {
        HStack(spacing: 10) {
            Text("Vybrané:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            Text(q.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Button {
                clear()
            } label: {
                Label("Vymazať", systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func dateTimeText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sk_SK")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}

// MARK: - Question Card

private struct QuestionCard: View {
    let question: AgentQuestion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: question.systemImage)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.95))

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.incomeColor)
                    }
                }

                Text(question.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Text("Tapni pre odpoveď")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.45) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Response Card

private struct ResponseCard: View {
    let response: AgentResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(response.title)
                .font(.headline)
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                ForEach(response.bullets) { bullet in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon(for: bullet.type))
                            .foregroundStyle(color(for: bullet.type))
                            .padding(.top, 2)

                        Text(bullet.text)
                            .foregroundStyle(.white)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }

                    if bullet.id != response.bullets.last?.id {
                        Divider().opacity(0.22)
                    }
                }
            }
        }
        .glassCard()
    }

    private func icon(for type: AgentMessageType) -> String {
        switch type {
        case .info:
            return "info.circle"
        case .positive:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    private func color(for type: AgentMessageType) -> Color {
        switch type {
        case .info:
            return .white.opacity(0.9)
        case .positive:
            return AppTheme.incomeColor
        case .warning:
            return AppTheme.expenseColor
        }
    }
}
