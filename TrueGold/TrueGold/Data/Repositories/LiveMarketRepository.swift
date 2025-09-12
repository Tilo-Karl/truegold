import Foundation

/// Live path uses live FX (open.er-api.com) + placeholder USD/gram anchors for metals.
/// Thai local (96.5%) can be swapped to your real API later.
struct LiveMarketRepository: MarketRepository {

    // Anchors in USD per gram (quick placeholders you can tweak anytime)
    private let goldSpotUSDPerGram   = 75.0
    private let silverSpotUSDPerGram = 0.90

    func fetchPricePerGram(kind: MetalKind, currency: String) async throws -> Double {
        let usdPerGram: Double
        switch kind {
        case .goldSpot:
            usdPerGram = goldSpotUSDPerGram

        case .silverSpot:
            usdPerGram = silverSpotUSDPerGram

        case .goldThai965:
            // Approximate fineness factor vs spot until Thai API is wired
            usdPerGram = goldSpotUSDPerGram * 0.965
            // Later:
            // let thbPerGram = try await ThaiGoldClient().pricePerGramTHB()
            // return await FXAdapter.convert(thbPerGram, from: "THB", to: currency)
        }

        // Convert USD → target using live FX
        return await FXAdapter.convert(usdPerGram, from: "USD", to: currency)
    }
}
