enum MetalKind: String, CaseIterable, Identifiable {
    case goldSpot, goldThai965, silverSpot

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .goldSpot: return "Gold Spot"
        case .goldThai965: return "Thai Gold 96.5%"
        case .silverSpot: return "Silver Spot"
        }
    }
}
