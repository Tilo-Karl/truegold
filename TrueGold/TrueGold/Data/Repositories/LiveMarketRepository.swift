import Foundation

struct LiveMarketRepository: MarketRepository {

    private let goldSpotUSDPerOunce: Double = 2400
    private let silverSpotUSDPerOunce: Double = 28
    private let gramsPerTroyOunce: Double = 31.1034768
    private let gramsPerThaiBahtWeight: Double = 15.244 // Thai “baht” gold unit

    private var goldSpotUSDPerGram: Double  { goldSpotUSDPerOunce  / gramsPerTroyOunce }
    private var silverSpotUSDPerGram: Double { silverSpotUSDPerOunce / gramsPerTroyOunce }

    func fetchPricePerGram(kind: MetalKind, currency: String) async throws -> Double {
        let basePerGram: Double     // will be in USD or THB depending on branch
        let baseCurrency: String

        switch kind {
        case .goldSpot:
            basePerGram = goldSpotUSDPerGram
            baseCurrency = "USD"

        case .silverSpot:
            basePerGram = silverSpotUSDPerGram
            baseCurrency = "USD"

        case .goldThai965:
            // Prefer live Thai quote (THB per gram). Fallback to 0.965 * spot if API fails.
            if let thbPerGram = await fetchThaiGoldPerGramTHB() {
                basePerGram = thbPerGram
                baseCurrency = "THB"
            } else {
                basePerGram = goldSpotUSDPerGram * 0.965
                baseCurrency = "USD"
            }
        }

        // Convert baseCurrency → requested currency with your TTG fetcher
        return await convert(basePerGram, from: baseCurrency, to: currency)
    }

    // MARK: - Helpers

    private func fetchThaiGoldPerGramTHB() async -> Double? {
        await withCheckedContinuation { cont in
            ThaiGoldAPIClient.shared.fetchThaiGoldQuote { quote in
                guard let q = quote else { return cont.resume(returning: nil) }
                // We use the customer-facing “sell” (what customer pays) for a buy price reference.
                let bahtWeightSellTHB = q.dblBarSell
                let perGramTHB = bahtWeightSellTHB / gramsPerThaiBahtWeight
                cont.resume(returning: perGramTHB)
            }
        }
    }

    private func convert(_ amount: Double, from base: String, to target: String) async -> Double {
        await withCheckedContinuation { cont in
            ExchangeRateFetcher.shared.getAllExchangeRates { rates in
                cont.resume(returning: rates.safeConvert(amount: amount, from: base, to: target))
            }
        }
    }
}
