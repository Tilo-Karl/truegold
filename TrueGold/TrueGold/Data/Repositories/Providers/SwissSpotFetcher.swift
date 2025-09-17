//
//  SwissSpotFetcher.swift
//  TrueGold
//
//  Fetches public spot quotes (bid/ask) from Swissquote and returns midpoint.
//  No API key required. Use for showcase/dev; check terms before shipping commercially.
//

import Foundation

// MARK: - Models (match Swissquote JSON)

private struct SQPlatformQuote: Decodable {
    struct Topo: Decodable { let platform: String; let server: String }
    struct SpreadProfilePrice: Decodable {
        let spreadProfile: String
        let bidSpread: Double
        let askSpread: Double
        let bid: Double
        let ask: Double
    }
    let topo: Topo
    let spreadProfilePrices: [SpreadProfilePrice]
    let ts: Int64
}

// MARK: - Fetcher

enum SwissSpotFetcher {
    private static let base = "https://forex-data-feed.swissquote.com/public-quotes/bboquotes/instrument"
    private static let gramsPerTroyOunce = 31.1034768

    /// Returns midpoint spot **USD per troy ounce** for the given metal symbol ("XAU", "XAG", …)
    static func midUSDPerOunce(symbol: String) async -> Double? {
        let urlStr = "\(base)/\(symbol)/USD"
        guard let url = URL(string: urlStr) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            let platforms = try JSONDecoder().decode([SQPlatformQuote].self, from: data)
            guard let best = pickBest(platforms: platforms) else { return nil }

            let mid = (best.bid + best.ask) / 2.0
            return mid
        } catch {
            print("SwissquoteSpotFetcher error:", error.localizedDescription)
            return nil
        }
    }

    /// Convenience: **USD per gram** for gold (XAU)
    static func goldUSDPerGram() async -> Double? {
        guard let perOz = await midUSDPerOunce(symbol: "XAU") else { return nil }
        return perOz / gramsPerTroyOunce
    }

    /// Convenience: **USD per gram** for silver (XAG)
    static func silverUSDPerGram() async -> Double? {
        guard let perOz = await midUSDPerOunce(symbol: "XAG") else { return nil }
        return perOz / gramsPerTroyOunce
    }

    // Pick the tightest spread profile: prefer elite > prime > premium > standard > first.
    private static func pickBest(platforms: [SQPlatformQuote]) -> SQPlatformQuote.SpreadProfilePrice? {
        let preference = ["elite", "prime", "premium", "standard"]
        for p in preference {
            if let match = platforms
                .flatMap({ $0.spreadProfilePrices })
                .first(where: { $0.spreadProfile.lowercased() == p }) {
                return match
            }
        }
        return platforms.first?.spreadProfilePrices.first
    }
}
