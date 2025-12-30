import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var didBootstrap = false

    var body: some View {
        TabView {

            OverviewView()
                .tabItem {
                    Label("Prehľad", systemImage: "chart.pie")
                }

            TransactionsView()
                .tabItem {
                    Label("Cashflow", systemImage: "list.bullet")
                }

            PlanView()
                .tabItem {
                    Label("Plán", systemImage: "calendar")
                }

            AgentView()
                .tabItem {
                    Label("Asistent", systemImage: "sparkles")
                }

            ForecastView()
                .tabItem {
                    Label("Forecast", systemImage: "chart.line.uptrend.xyaxis")
                }

            HeatMapView()
                .tabItem {
                    Label("HeatMap", systemImage: "calendar")
                }
        }
        .onAppear {
            guard !didBootstrap else { return }
            didBootstrap = true

            Task { @MainActor in
                CSVLoader.refreshFromBundle(context: modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
}
