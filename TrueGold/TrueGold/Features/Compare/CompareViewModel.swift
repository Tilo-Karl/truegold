import Foundation

@MainActor
final class CompareViewModel: ObservableObject {
    private let engine: PricingEngine
    init(repo: MarketRepository) {
        self.engine = PricingEngine(repo: repo)
    }
}
