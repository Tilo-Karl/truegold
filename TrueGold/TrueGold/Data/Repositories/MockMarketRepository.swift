import Foundation

struct MockMarketRepository: MarketRepository {
    func fetchPricePerGram(kind: MetalKind, currency: String) async throws -> Double {
        switch kind {
        case .goldSpot: return 2000
        case .goldThai965: return 2200
        case .silverSpot: return 25
        }
    }
}
