//
//  ThaiGoldAPIClient.swift
//  TrueGold
//
//  Created by Tilo Delau on 2025-09-15.
//
//  Don't use rawJewelrySell, but keep it so we know the data is there.
//
// PARSING STYLE — intentionally manual here.
// We use JSONSerialization in this client to keep the raw API shape visible for reference & debugging.
// Elsewhere in the app we use Codable + structs; this file is the exception by design.
//
// Why not Codable here?
// • Transparency while the upstream payload occasionally changes (commas-as-thousands, naming quirks).
// • Easier to log/inspect exact keys/values during live debugging.
// Guarantees in this file:
// • Keys are validated before use; numeric strings are normalized ("," removed) before Double init.
// • Any schema mismatch logs a clear parse error and returns nil (no partial/undefined state).
//
// Migration note:
// If/when the API stabilizes, replace this with a Codable model in one go (don’t keep both styles in the same module).
// Canonical Codable examples live elsewhere in the project.

import Foundation

class ThaiGoldAPIClient {
    static let shared = ThaiGoldAPIClient()

    private let apiURL = "https://api.chnwt.dev/thai-gold-api/latest"

    private init() {}

    func fetchThaiGoldQuote(completion: @escaping (ThaiGoldQuote?) -> Void) {
        guard let url = URL(string: apiURL) else {
            Logger.log("ThaiGoldAPIClient", "❌ Invalid URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                Logger.log("ThaiGoldAPIClient", "❌ Network error: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            do {
                if
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let response = json["response"] as? [String: Any],
                    let price = response["price"] as? [String: Any],
                    let goldBar = price["gold_bar"] as? [String: String],
                    let barSellString = goldBar["sell"],
                    let barBuyString = goldBar["buy"],
                    let gold = price["gold"] as? [String: String],
                    let jewelrySellString = gold["sell"],
                    let jewelryBuyString = gold["buy"],
                    let rawBarSell = Double(barSellString.replacingOccurrences(of: ",", with: "")),
                    let rawBarBuy = Double(barBuyString.replacingOccurrences(of: ",", with: "")),
                    // Good to know this exists, maybe we use it one day.
                    //let rawJewelrySell = Double(jewelrySellString.replacingOccurrences(of: ",", with: "")),
                    let rawJewelryBuy = Double(jewelryBuyString.replacingOccurrences(of: ",", with: ""))
                {
                    // 🟡 IMPORTANT: The API uses reversed naming ("buy" is what shop pays, "sell" is what shop gets).
                    // We correct it here so our app always uses the correct customer-facing logic:
                    let quote = ThaiGoldQuote(
                        dblBarSell: rawBarBuy,             // ← Customer PAYS this (shop's "buy" price)
                        dblBarBuy: rawBarSell,             // ← Shop BUYS BACK at this (shop's "sell" price)
                        dblJewelrySell: rawJewelryBuy,     // ← Customer PAYS this (shop's "buy" price)
                        date: Date()
                    )

                    Logger.log("ThaiGoldAPIClient", "✅ Success – BarSell (raw buy): \(rawBarBuy), BarBuy (raw sell): \(rawBarSell), JewelrySell (raw buy): \(rawJewelryBuy)")
                    
                    if quote.dblBarBuy > quote.dblBarSell {
                        Logger.log("ThaiGoldAPIClient", "⚠️ Suspicious quote – BarBuy (\(quote.dblBarBuy)) > BarSell (\(quote.dblBarSell))")
                    }
                    DispatchQueue.main.async { completion(quote) }
                } else {
                    Logger.log("ThaiGoldAPIClient", "❌ JSON parse error: missing keys or invalid format")
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                Logger.log("ThaiGoldAPIClient", "❌ JSON decoding error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}

struct ThaiGoldQuote {
    let dblBarSell: Double          // 96.5% bar sell (customer buys)
    let dblBarBuy: Double           // 96.5% bar buy-in (customer sells)
    let dblJewelrySell: Double      // 96.5% jewelry sell (customer buys)
    let date: Date
}
