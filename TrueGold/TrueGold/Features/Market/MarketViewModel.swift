import Foundation

@MainActor
final class MarketViewModel: ObservableObject {
    @Published var rows: [ValueTileModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var notice: String? = nil
    private let engine: PricingEngine

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

        var out: [ValueTileModel] = []

        // Fetch spot metals (excluding Thai gold) in the requested currency
        for k in MetalKind.allCases where k != .goldThai965 {
            do {
                let v = try await engine.pricePerGram(kind: k, currency: targetCurrency)
                out.append(.init(
                    title: k.displayName,
                    subtitle: "per g",
                    currency: targetCurrency,
                    value: v
                ))
            } catch {
                if errorMessage == nil { errorMessage = error.localizedDescription }
            }
        }

        // Thai gold: show both THB and converted
        do {
            let thbValue = try await engine.pricePerGram(kind: .goldThai965, currency: "THB")
            out.append(.init(
                title: "Thai Gold 96.5%",
                subtitle: "per g",
                currency: "THB",
                value: thbValue
            ))

            if targetCurrency != "THB" {
                let converted = try await engine.pricePerGram(kind: .goldThai965, currency: targetCurrency)
                out.append(.init(
                    title: "Thai Gold 96.5%",
                    subtitle: "per g",
                    currency: targetCurrency,
                    value: converted
                ))
            }
        } catch {
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }

        if out.isEmpty, NetworkMonitor.shared.isOnline == false {
            errorMessage = "No network and no cached data."
        }
        rows = out
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
}
