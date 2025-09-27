import Foundation

@MainActor
final class MarketViewModel: ObservableObject {
    @Published var rows: [ValueTileModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var notice: String? = nil
    
    enum MarketUnit: String, CaseIterable { case gram, ozt }
    typealias MeasurementUnit = MarketUnit
    @Published var selectedUnit: MarketUnit = .gram
    
    private let engine: PricingEngine
    private let gramsPerTroyOunce = 31.1034768
    private var rawQuotes: [(title: String, currency: String, perGram: Double)] = []

    init(repo: MarketRepository) {
        self.engine = PricingEngine(repo: repo)
        updateConnectivityNotice()
    }

    func load(currency: String? = nil) async {
        updateConnectivityNotice()
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let targetCurrency = currency ?? "USD"
        rawQuotes.removeAll()

        // Fetch spot metals (excluding Thai gold) in the requested currency
        for k in MetalKind.allCases where k != .goldThai965 {
            do {
                let v = try await engine.pricePerGram(kind: k, currency: targetCurrency)
                rawQuotes.append((title: k.displayName, currency: targetCurrency, perGram: v))
            } catch {
                if errorMessage == nil { errorMessage = error.localizedDescription }
            }
        }

        // Thai gold: only one row in the target currency
        do {
            let v = try await engine.pricePerGram(kind: .goldThai965, currency: targetCurrency)
            rawQuotes.append((title: "Thai Gold 96.5%", currency: targetCurrency, perGram: v))
        } catch {
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }

        if rawQuotes.isEmpty, NetworkMonitor.shared.isOnline == false {
            errorMessage = "No network and no cached data."
        }
        rebuildRowsFromRaw()
    }

    private func updateConnectivityNotice() {
        if NetworkMonitor.shared.isOnline == false {
            notice = "Offline — showing cached FX if available; live spot may be unavailable."
        } else {
            notice = nil
        }
    }

    // Exposed wrapper for views
    func performConnectivityNoticeUpdate() { updateConnectivityNotice() }
    
    private func rebuildRowsFromRaw() {
        let factor: Double = (selectedUnit == .gram) ? 1.0 : gramsPerTroyOunce
        rows = rawQuotes.map { item in
            .init(
                title: item.title,
                subtitle: "",
                currency: item.currency,
                value: item.perGram * factor,
                unitLabel: nil
            )
        }
    }
    
    func setUnit(_ unit: MarketUnit) async {
        await MainActor.run {
            guard self.selectedUnit != unit else { return }
            self.selectedUnit = unit
            self.rebuildRowsFromRaw()
        }
    }
}
