import Foundation

@MainActor
final class MarketViewModel: ObservableObject {
    @Published var rows: [ValueTileModel] = []
    private let engine: PricingEngine

    init(repo: MarketRepository) {
        self.engine = PricingEngine(repo: repo)
    }

    func load(currency: String = "USD") async {
        var out: [ValueTileModel] = []
        for k in MetalKind.allCases {
            if let v = try? await engine.pricePerGram(kind: k, currency: currency) {
                out.append(.init(title: k.displayName, subtitle: "per g", currency: currency, value: v))
            }
        }
        rows = out
    }
}
