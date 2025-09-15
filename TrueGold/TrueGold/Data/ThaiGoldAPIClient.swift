//
//  ThaiGoldAPIClient.swift
//  TrueGold
//
//  Created by Tilo Delau on 2025-09-15.
//
//  Don't use rawJewelrySell, but keep it so we know the data is there.

import Foundation

class ThaiGoldAPIClient {
    static let shared = ThaiGoldAPIClient()

    private let apiURL = "https://api.chnwt.dev/thai-gold-api/latest"

    private init() {}

    func fetchThaiGoldQuote(completion: @escaping (ThaiGoldQuote?) -> Void) {
        guard let url = URL(string: apiURL) else {
            print("❌ Invalid ThaiGoldAPIClient URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                print("❌ ThaiGoldAPIClient network error: \(error?.localizedDescription ?? "Unknown error")")
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
                    let rawJewelrySell = Double(jewelrySellString.replacingOccurrences(of: ",", with: "")),
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

                    print("✅ ThaiGoldAPIClient Success – BarSell (raw buy): \(rawBarBuy), BarBuy (raw sell): \(rawBarSell), JewelrySell (raw buy): \(rawJewelryBuy)")
                    
                    if quote.dblBarBuy > quote.dblBarSell {
                        Logger.log("ThaiGoldAPIClient", "⚠️ Suspicious quote – BarBuy (\(quote.dblBarBuy)) > BarSell (\(quote.dblBarSell))")
                    }
                    DispatchQueue.main.async { completion(quote) }
                } else {
                    print("❌ ThaiGoldAPIClient JSON parse error: missing keys or invalid format")
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                print("❌ ThaiGoldAPIClient JSON decoding error: \(error.localizedDescription)")
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
