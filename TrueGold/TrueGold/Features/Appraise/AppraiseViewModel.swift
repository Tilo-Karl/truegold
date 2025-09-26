import Foundation

@MainActor
final class AppraiseViewModel: ObservableObject {
    // Published UI state
    @Published var isLoading: Bool = false
    @Published var result: AppraisalResult?
    @Published var errorMessage: String?

    // Dependencies
    private let engine: PricingEngine

    init(repo: MarketRepository) {
        self.engine = PricingEngine(repo: repo)
    }

    struct AppraisalResult {
        let perGram: Double
        let total: Double
        let currency: String
        let note: String
    }

    /// Fetches per‑gram price for the given `MetalKind` in `currency`,
    /// applies purity factor (except for Thai 96.5% where purity is baked in),
    /// and computes the total for `grams`.
    func appraise(kind: MetalKind, purityFactor: Double, grams: Double, currency: String) async {
        isLoading = true
        errorMessage = nil
        result = nil
        //defer { isLoading = false }
        
        defer {
            // Small delay to smooth out quick flashes of the loading state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                self.isLoading = false
            }
        }

        do {
            // 1) Base per‑gram in target currency from PricingEngine/Repository
            let basePerGram = try await engine.pricePerGram(kind: kind, currency: currency)

            // 2) Apply purity (except for Thai 96.5%, which is already purity‑adjusted)
            let adjustedPerGram: Double
            let note: String

            switch kind {
            case .goldThai965:
                adjustedPerGram = basePerGram
                note = "Thai 96.5% price (per gram) in \(currency)"
            default:
                adjustedPerGram = basePerGram * purityFactor
                let pct = Int((purityFactor * 100).rounded())
                note = "Spot × purity (\(pct)%) in \(currency)"
            }

            // 3) Total for user grams
            let total = adjustedPerGram * grams

            // 4) Publish result
            self.result = .init(perGram: adjustedPerGram, total: total, currency: currency, note: note)
        } catch {
            self.errorMessage = "Couldn’t fetch prices. Try again."
        }
    }
}
