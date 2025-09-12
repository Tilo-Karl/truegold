import Foundation

@MainActor
final class AppraiseViewModel: ObservableObject {
    private let engine: PricingEngine
    init(repo: MarketRepository) {
        self.engine = PricingEngine(repo: repo)
    }
}
