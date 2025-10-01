//
//  ExchangeRateFetcher.swift
//  TrueGold
//
//  Handles ONLY fiat exchange rates (no metal logic).
//  Fallback order:
//    1) Live API (if .live or .cached)
//    2) Cached (if present)
//    3) Bundled JSON (if .bundled or live fails)
//    4) Hardcoded table (last resort / .hardcoded)
//
//  Configuration is driven by `TestPhase` for automated testing.
//
//  🔄 safeConvert(amount:from:to:) converts between any two currencies,
//     falling back to default ratios (1.0 or 2.0) if rates are missing to avoid crash.
//     This ensures the app always displays a value, even when incomplete data is present.
//
// DESIGN NOTE — Why `class` instead of `struct`?
// ExchangeRateFetcher is a shared service object with a singleton (`shared`).
// We want reference semantics so all parts of the app talk to the same instance,
// managing cache, network requests, and fallbacks centrally.
// A struct would create copies; a class ensures shared state.
//

import Foundation

class ExchangeRateFetcher {
    static let shared = ExchangeRateFetcher()

    private let baseURL = "https://open.er-api.com/v6/latest/USD"
    private let cacheKey = "ExchangeRateCache_ALL"
    private let cacheExpiryHours: Double = TestPhase.forceLiveExchangeRate ? 0 : 12

    private let userDefaults = UserDefaults.standard
    private init() {}

    func getExchangeRate(from: Currency, to: Currency, completion: @escaping (Double?) -> Void) {
        Logger.log("ExchangeRateFetcher", "getExchangeRate called: \(from.code) → \(to.code)")
        fetchRates { exchangeRate in
            let value = exchangeRate.safeConvert(amount: 1.0, from: from.code, to: to.code)
            completion(value)
        }
    }

    func getAllExchangeRates(completion: @escaping (ExchangeRate) -> Void) {
        Logger.log("ExchangeRateFetcher", "getAllExchangeRates called")
        fetchRates(completion: completion)
    }

    // MARK: - Internal Fetch Logic

    private func fetchRates(completion: @escaping (ExchangeRate) -> Void) {
        if TestPhase.useMockData {
            Logger.log("ExchangeRateFetcher", "🧪 Using hardcoded MOCK data")
            completion(Self.fallbackRates())
            return
        }

        if let cachedRate = getCachedRate(), !isCacheExpired() {
            Logger.log("ExchangeRateFetcher", "📦 Using CACHED data from UserDefaults")
            completion(cachedRate)
            return
        }

        // If offline, fail fast and use fallbacks
        if !(NetworkMonitor.shared.isOnline) {
            Logger.log("ExchangeRateFetcher", "🔌 Offline → using cache/bundled/hardcoded")
            if let cached = self.getCachedRate() {
                completion(cached)
            } else if let bundled = self.loadBundledRates() {
                completion(bundled)
            } else {
                completion(Self.fallbackRates())
            }
            return
        }

        guard let url = URL(string: baseURL) else {
            Logger.log("ExchangeRateFetcher", "⚠️ Invalid URL – using BUNDLED fallback JSON")
            completion(loadBundledRates() ?? Self.fallbackRates())
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        ShortTimeoutSession.shared.dataTask(with: request) { data, response, error in
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            Logger.log("ExchangeRateFetcher", "📡 HTTP status code: \(httpCode)")

            guard
                error == nil,
                httpCode == 200,
                let data = data,
                let result = try? JSONDecoder().decode(ERAPIResponse.self, from: data),
                !result.rates.isEmpty
            else {
                let fallbackRate: ExchangeRate
                let source: String

                if let cached = self.getCachedRate() {
                    fallbackRate = cached
                    source = "CACHED data"
                } else if let bundled = self.loadBundledRates() {
                    fallbackRate = bundled
                    source = "BUNDLED fallback JSON"
                } else {
                    fallbackRate = Self.fallbackRates()
                    source = "HARDCODED fallback"
                }

                Logger.log("ExchangeRateFetcher", "❌ API fetch failed – using \(source)")
                completion(fallbackRate)
                return
            }

            self.cache(rates: result.rates)
            Logger.log("ExchangeRateFetcher", "✅ Live exchange rates fetched from API")
            completion(ExchangeRate(rates: result.rates))
        }.resume()
    }

    // MARK: - Cache

    private func cache(rates: [String: Double]) {
        userDefaults.set(rates, forKey: cacheKey + "_rates")
        userDefaults.set(Date(), forKey: cacheKey + "_timestamp")
    }

    private func getCachedRate() -> ExchangeRate? {
        guard let rates = userDefaults.dictionary(forKey: cacheKey + "_rates") as? [String: Double] else { return nil }
        return ExchangeRate(rates: rates)
    }

    private func isCacheExpired() -> Bool {
        guard let timestamp = userDefaults.object(forKey: cacheKey + "_timestamp") as? Date else { return true }
        let expiration = timestamp.addingTimeInterval(cacheExpiryHours * 3600)
        return Date() > expiration
    }

    // MARK: - Bundled JSON fallback

    private func loadBundledRates() -> ExchangeRate? {
        guard let url = Bundle.main.url(forResource: "default_exchange_rates", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rates = try? JSONDecoder().decode([String: Double].self, from: data),
              !rates.isEmpty else {
            return nil
        }
        return ExchangeRate(rates: rates)
    }

    private static func fallbackRates() -> ExchangeRate {
        let hardcoded: [String: Double] = [
            "USD": 1.0,
            "THB": 35.0,
            "EUR": 0.91,
            "VND": 23000.0,
            "LAK": 21000.0,
            "KHR": 4100.0
        ]
        return ExchangeRate(rates: hardcoded)
    }

    // PARSING STYLE — Codable / "Swifty" approach.
    // This struct demonstrates the idiomatic Swift style of decoding JSON
    // directly into strongly typed models using Decodable.
    private struct ERAPIResponse: Decodable {
        let result: String
        let base_code: String
        let rates: [String: Double]
    }
}

// MARK: - ExchangeRate Model

struct ExchangeRate {
    let rates: [String: Double]
    static let empty = ExchangeRate(rates: [:])
    
    func safeConvert(amount: Double, from base: String, to target: String) -> Double {
        if base == target {
            Logger.log("ExchangeRate", "No conversion needed: \(amount) \(base) = \(amount) \(target)")
            return amount
        }

        guard let baseRate = rates[base],
              let targetRate = rates[target] else {
            Logger.log("ExchangeRate", "Missing exchange rate for \(base) or \(target) – cannot convert")
            return 0.0
        }

        let result = amount / baseRate * targetRate

        Logger.log("ExchangeRate", "Converted \(amount) \(base) → \(result) \(target) using USD as base")
        return result
    }
    
}
