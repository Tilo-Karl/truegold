import Foundation

protocol MarketRepository {
    func fetchPricePerGram(kind: MetalKind, currency: String) async throws -> Double
}
