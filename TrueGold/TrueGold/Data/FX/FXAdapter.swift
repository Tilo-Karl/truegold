//
//  FXAdapter.swift
//  TrueGold
//
//  Created by Tilo Delau on 2025-09-12.
//


import Foundation

enum FXAdapter {
    static func convert(_ amount: Double, from base: String, to target: String) async -> Double {
        await withCheckedContinuation { cont in
            ExchangeRateFetcher.shared.getAllExchangeRates { rates in
                cont.resume(returning: rates.safeConvert(amount: amount, from: base, to: target))
            }
        }
    }
}