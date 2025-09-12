//
//  CurrencyInfo.swift
//  TrueGold
//
//  Created by Tilo Delau on 2025-09-12.
//


import Foundation

struct CurrencyInfo {
    let code: String
    let symbol: String
    let fullName: String
}

enum Currency: String, CaseIterable, Identifiable {
    case usd, eur, thb, gbp, jpy, cny, aud, cad, chf, sek, nok, dkk, inr, krw, sgd, hkd, myr, php, idr, zar, brl, mxn
    case vnd, lak, khr

    var id: String { rawValue }

    var info: CurrencyInfo {
        switch self {
        case .usd: return .init(code: "USD", symbol: "$",  fullName: "US Dollar")
        case .eur: return .init(code: "EUR", symbol: "€",  fullName: "Euro")
        case .thb: return .init(code: "THB", symbol: "฿",  fullName: "Thai Baht")
        case .gbp: return .init(code: "GBP", symbol: "£",  fullName: "British Pound")
        case .jpy: return .init(code: "JPY", symbol: "¥",  fullName: "Japanese Yen")
        case .cny: return .init(code: "CNY", symbol: "¥",  fullName: "Chinese Yuan")
        case .aud: return .init(code: "AUD", symbol: "$",  fullName: "Australian Dollar")
        case .cad: return .init(code: "CAD", symbol: "$",  fullName: "Canadian Dollar")
        case .chf: return .init(code: "CHF", symbol: "Fr", fullName: "Swiss Franc")
        case .sek: return .init(code: "SEK", symbol: "kr", fullName: "Swedish Krona")
        case .nok: return .init(code: "NOK", symbol: "kr", fullName: "Norwegian Krone")
        case .dkk: return .init(code: "DKK", symbol: "kr", fullName: "Danish Krone")
        case .inr: return .init(code: "INR", symbol: "₹",  fullName: "Indian Rupee")
        case .krw: return .init(code: "KRW", symbol: "₩",  fullName: "South Korean Won")
        case .sgd: return .init(code: "SGD", symbol: "$",  fullName: "Singapore Dollar")
        case .hkd: return .init(code: "HKD", symbol: "$",  fullName: "Hong Kong Dollar")
        case .myr: return .init(code: "MYR", symbol: "RM", fullName: "Malaysian Ringgit")
        case .php: return .init(code: "PHP", symbol: "₱",  fullName: "Philippine Peso")
        case .idr: return .init(code: "IDR", symbol: "Rp",  fullName: "Indonesian Rupiah")
        case .zar: return .init(code: "ZAR", symbol: "R",   fullName: "South African Rand")
        case .brl: return .init(code: "BRL", symbol: "R$",  fullName: "Brazilian Real")
        case .mxn: return .init(code: "MXN", symbol: "$",   fullName: "Mexican Peso")
        case .vnd: return .init(code: "VND", symbol: "₫",   fullName: "Vietnamese Dong")
        case .lak: return .init(code: "LAK", symbol: "₭",   fullName: "Lao Kip")
        case .khr: return .init(code: "KHR", symbol: "៛",   fullName: "Cambodian Riel")
        }
    }

    var code: String { info.code }
    var symbol: String { info.symbol }
    var fullName: String { info.fullName }

    var flagEmoji: String {
        switch self {
        case .usd: return "🇺🇸"; case .eur: return "🇪🇺"; case .thb: return "🇹🇭"
        case .gbp: return "🇬🇧"; case .jpy: return "🇯🇵"; case .cny: return "🇨🇳"
        case .aud: return "🇦🇺"; case .cad: return "🇨🇦"; case .chf: return "🇨🇭"
        case .sek: return "🇸🇪"; case .nok: return "🇳🇴"; case .dkk: return "🇩🇰"
        case .inr: return "🇮🇳"; case .krw: return "🇰🇷"; case .sgd: return "🇸🇬"
        case .hkd: return "🇭🇰"; case .myr: return "🇲🇾"; case .php: return "🇵🇭"
        case .idr: return "🇮🇩"; case .zar: return "🇿🇦"; case .brl: return "🇧🇷"
        case .mxn: return "🇲🇽"; case .vnd: return "🇻🇳"; case .lak: return "🇱🇦"
        case .khr: return "🇰🇭"
        }
    }
}

// Small bridge helpers if you have String codes in view models:
extension Currency {
    static func from(code: String) -> Currency? {
        Currency.allCases.first { $0.code == code.uppercased() }
    }
}