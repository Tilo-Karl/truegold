import Foundation

@MainActor
final class MarketViewModel: ObservableObject {
    @Published var rows: [ValueTileModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    private let engine: PricingEngine

    init(repo: MarketRepository) {
        self.engine = PricingEngine(repo: repo)
    }

    func load(currency: String) async {
        // Prevent overlapping loads but allow refresh to restart quickly
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var out: [ValueTileModel] = []

        // Fetch spot metals (excluding Thai gold) in the requested currency
        for k in MetalKind.allCases where k != .goldThai965 {
            do {
                let v = try await engine.pricePerGram(kind: k, currency: currency)
                out.append(.init(
                    title: k.displayName,
                    subtitle: "per g",
                    currency: currency,
                    value: v
                ))
            } catch {
                // Record the first error we encounter (non-fatal; continue building other rows)
                if errorMessage == nil { errorMessage = error.localizedDescription }
            }
        }

        // Thai gold: show both THB and converted
        do {
            let thbValue = try await engine.pricePerGram(kind: .goldThai965, currency: "THB")
            out.append(.init(
                title: "Thai Gold 96.5%",
                subtitle: "per g",
                currency: "THB",
                value: thbValue
            ))

            if currency != "THB" {
                let converted = try await engine.pricePerGram(kind: .goldThai965, currency: currency)
                out.append(.init(
                    title: "Thai Gold 96.5%",
                    subtitle: "per g",
                    currency: currency,
                    value: converted
                ))
            }
        } catch {
            // If THB branch fails, still show other rows; capture error once
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }

        rows = out
    }
}
