import Foundation

struct LiveMarketRepository: MarketRepository {

    // Fallback constants (used if Swissquote or Thai client fail)
    private let fallbackGoldUSDPerOunce: Double = 2400
    private let fallbackSilverUSDPerOunce: Double = 28
    private let fallbackPlatinumUSDPerOunce: Double = 1000
    private let fallbackPalladiumUSDPerOunce: Double = 2300
    private let gramsPerTroyOunce: Double = 31.1034768
    private let gramsPerThaiBahtWeight: Double = 15.244 // Thai “baht” gold unit

    private var fallbackGoldUSDPerGram: Double   { fallbackGoldUSDPerOunce   / gramsPerTroyOunce }
    private var fallbackSilverUSDPerGram: Double { fallbackSilverUSDPerOunce / gramsPerTroyOunce }
    private var fallbackPlatinumUSDPerGram: Double { fallbackPlatinumUSDPerOunce / gramsPerTroyOunce }
    private var fallbackPalladiumUSDPerGram: Double { fallbackPalladiumUSDPerOunce / gramsPerTroyOunce }

    func fetchPricePerGram(kind: MetalKind, currency: String) async throws -> Double {
        let basePerGram: Double   // value in baseCurrency units
        let baseCurrency: String

        switch kind {
        case .goldSpot, .silverSpot, .platinumSpot, .palladiumSpot:
            let symbol: String
            switch kind {
            case .goldSpot:      symbol = "XAU"
            case .silverSpot:    symbol = "XAG"
            case .platinumSpot:  symbol = "XPT"
            case .palladiumSpot: symbol = "XPD"
            default:
                // Unreachable due to outer case; safe fallback
                symbol = "XAU"
            }
            if let usdPerGram = await SwissSpotFetcher.perGram(symbol: symbol, quoteCcy: "USD") {
                basePerGram = usdPerGram
                baseCurrency = "USD"
            } else {
                // Fallback constants
                switch kind {
                case .goldSpot:
                    basePerGram = fallbackGoldUSDPerGram
                case .silverSpot:
                    basePerGram = fallbackSilverUSDPerGram
                case .platinumSpot:
                    basePerGram = fallbackPlatinumUSDPerGram
                case .palladiumSpot:
                    basePerGram = fallbackPalladiumUSDPerGram
                default:
                    basePerGram = 0
                }
                baseCurrency = "USD"
            }

        case .goldThai965:
            // Prefer live Thai quote (THB per gram). Fallback to ~spot*0.965 in USD.
            if let thbPerGram = await fetchThaiGoldPerGramTHB() {
                basePerGram = thbPerGram
                baseCurrency = "THB"
            } else {
                basePerGram = fallbackGoldUSDPerGram * 0.965
                baseCurrency = "USD"
            }
        }

        // Convert baseCurrency → requested currency via your TTG FX fetcher
        return await convert(basePerGram, from: baseCurrency, to: currency)
    }

    // MARK: - Helpers

    private func fetchThaiGoldPerGramTHB() async -> Double? {
        await withCheckedContinuation { cont in
            ThaiGoldAPIClient.shared.fetchThaiGoldQuote { quote in
                guard let q = quote else { return cont.resume(returning: nil) }
                // Use customer-facing “sell” per baht weight, then to per gram
                let perGramTHB = q.dblBarSell / gramsPerThaiBahtWeight
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
