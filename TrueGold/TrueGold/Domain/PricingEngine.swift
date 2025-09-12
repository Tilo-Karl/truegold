import Foundation

struct PricingEngine {
    let repo: MarketRepository

    func pricePerGram(kind: MetalKind, currency: String) async throws -> Double {
        try await repo.fetchPricePerGram(kind: kind, currency: currency)
    }
}
