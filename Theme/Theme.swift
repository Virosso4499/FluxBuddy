import SwiftUI
import Charts

// MARK: - Theme (globálne farby a štýl)

enum AppTheme {
    // pozadie
    static let bgOverlayOpacity: Double = 0.26

    // karty
    static let cardCorner: CGFloat = 22
    static let cardStrokeOpacity: Double = 0.18
    static let shadowOpacity: Double = 0.22

    // texty v kartách
    static let cardTextPrimary: Color = .black
    static let cardTextSecondary: Color = .black.opacity(0.65)

    // štýl osí grafu na tmavom pozadí
    static let chartGrid: Color = .white.opacity(0.14)
    static let chartAxis: Color = .white.opacity(0.25)
    static let chartLabel: Color = .white.opacity(0.80)

    // konzistentné farby sérií (príjem/výdavok)
    static let incomeColor: Color = .green
    static let expenseColor: Color = .pink

    // neutrálna farba (net, plán a pod.)
    static let neutralColor: Color = .blue
}

// MARK: - Pozadie pre celú appku

struct ThemedBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.80),
                Color.purple.opacity(0.78),
                Color.green.opacity(0.72)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            Rectangle()
                .fill(.black.opacity(AppTheme.bgOverlayOpacity))
                .ignoresSafeArea()
        )
    }
}

// MARK: - Wrapper pre obrazovky

struct ThemedScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            ThemedBackground()
            content
        }
    }
}

// MARK: - Glass karta
// Dôležité: žiadny globálny foregroundStyle (aby grafy nečerneli)

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous)
                    .stroke(.white.opacity(AppTheme.cardStrokeOpacity), lineWidth: 1)
            )
            .shadow(color: .black.opacity(AppTheme.shadowOpacity), radius: 16, x: 0, y: 10)
            .environment(\.colorScheme, .light)
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCardStyle()) }

    func cardPrimaryText() -> some View {
        self.foregroundStyle(AppTheme.cardTextPrimary)
    }

    func cardSecondaryText() -> some View {
        self.foregroundStyle(AppTheme.cardTextSecondary)
    }

    // Použi na Chart() aby osi/grid vyzerali lepšie na tmavom pozadí
    func chartOnDarkBackground() -> some View {
        self
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(AppTheme.chartGrid)
                    AxisTick().foregroundStyle(AppTheme.chartAxis)
                    AxisValueLabel().foregroundStyle(AppTheme.chartLabel)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(AppTheme.chartGrid)
                    AxisTick().foregroundStyle(AppTheme.chartAxis)
                    AxisValueLabel().foregroundStyle(AppTheme.chartLabel)
                }
            }
            .chartLegend(.visible)
    }
}
