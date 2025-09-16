import Foundation

@MainActor
final class MarketViewModel: ObservableObject {
    @Published var rows: [ValueTileModel] = []
    private let engine: PricingEngine

    init(repo: MarketRepository) {
        self.engine = PricingEngine(repo: repo)
    }

    func load(currency: String) async {
        var out: [ValueTileModel] = []

        // Spot + silver, same as before
        for k in MetalKind.allCases where k != .goldThai965 {
            if let v = try? await engine.pricePerGram(kind: k, currency: currency) {
                out.append(.init(
                    title: k.displayName,
                    subtitle: "per g",
                    currency: currency,
                    value: v
                ))
            }
        }

        // Thai gold: show both THB and converted
        if let thbValue = try? await engine.pricePerGram(kind: .goldThai965, currency: "THB") {
            out.append(.init(
                title: "Thai Gold 96.5%",
                subtitle: "per g",
                currency: "THB",
                value: thbValue
            ))

            if currency != "THB",
               let converted = try? await engine.pricePerGram(kind: .goldThai965, currency: currency) {
                out.append(.init(
                    title: "Thai Gold 96.5%",
                    subtitle: "per g",
                    currency: currency,
                    value: converted
                ))
            }
        }

        rows = out
    }
}
