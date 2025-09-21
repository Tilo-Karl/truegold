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

    /// Returns midpoint spot **per troy ounce** for `symbol` ("XAU", "XAG", "XPT", "XPD") quoted in `quoteCcy` (default "USD").
    static func midPerOunce(symbol: String, quoteCcy: String = "USD") async -> Double? {
        let urlStr = "\(base)/\(symbol)/\(quoteCcy)"
        guard let url = URL(string: urlStr) else {
            Logger.log("SwissSpotFetcher", "⚠️ Bad URL: \(urlStr)")
            return nil
        }

        // Short, explicit networking config per call
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 8
        cfg.timeoutIntervalForResource = 8
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        cfg.waitsForConnectivity = false
        let session = URLSession(configuration: cfg)

        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.timeoutInterval = 8

        do {
            let (data, resp) = try await session.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                Logger.log("SwissSpotFetcher", "❌ HTTP \(code) for \(symbol)/\(quoteCcy)")
                return nil
            }

            let platforms = try JSONDecoder().decode([SQPlatformQuote].self, from: data)
            guard let best = pickBest(platforms: platforms) else {
                Logger.log("SwissSpotFetcher", "❌ No spreadProfilePrices in response")
                return nil
            }

            let mid = (best.bid + best.ask) / 2.0
            return mid
        } catch {
            Logger.log("SwissSpotFetcher", "❌ fetch error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Returns **per gram** for `symbol` ("XAU", "XAG", "XPT", "XPD") quoted in `quoteCcy` (default "USD").
    static func perGram(symbol: String, quoteCcy: String = "USD") async -> Double? {
        guard let perOz = await midPerOunce(symbol: symbol, quoteCcy: quoteCcy) else { return nil }
        return perOz / gramsPerTroyOunce
    }

    // Pick the tightest spread profile: prefer elite > prime > premium > standard > first available.
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
