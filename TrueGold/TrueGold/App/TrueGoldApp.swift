import SwiftUI

@main
struct TrueGoldApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabs()
        }
    }
}

struct RootTabs: View {
    @StateObject private var marketVM = MarketViewModel(repo: DI.marketRepo)
    @StateObject private var appraiseVM = AppraiseViewModel(repo: DI.marketRepo)
    
    var body: some View {
        TabView {
            MarketView(viewModel: marketVM)
                .tabItem { Label("Market", systemImage: "chart.line.uptrend.xyaxis") }
            AppraiseView(viewModel: appraiseVM)
                .tabItem { Label("Appraise", systemImage: "scalemass") }
        }
        .tint(.appPurple)
    }
}
