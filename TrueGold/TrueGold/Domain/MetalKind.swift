enum MetalKind: String, CaseIterable, Identifiable {
    case goldSpot, goldThai965, silverSpot, platinumSpot, palladiumSpot

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .goldSpot: return "Gold Spot"
        case .goldThai965: return "Thai Gold 96.5%"
        case .silverSpot: return "Silver Spot"
        case .platinumSpot: return "Platinum Spot"
        case .palladiumSpot: return "Palladium Spot"
        }
    }
}

// MetalKind+Swiss.swift
// Extends MetalKind with Swissquote symbol mapping

extension MetalKind {
    var swissSymbol: String? {
        switch self {
        case .goldSpot:   return "XAU"
        case .silverSpot: return "XAG"
        case .platinumSpot: return "XPT"
        case .palladiumSpot: return "XPD"
        default: return nil
        }
    }
}
