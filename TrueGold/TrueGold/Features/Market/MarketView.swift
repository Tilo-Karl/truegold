import SwiftUI

struct MarketView: View {
    @ObservedObject var viewModel: MarketViewModel
    @State private var currency = "USD"

    var body: some View {
        NavigationStack {
            List(viewModel.rows) { ValueTile(model: $0) }
                .navigationTitle("Market")
                .task { await viewModel.load(currency: currency) }
                .refreshable { await viewModel.load(currency: currency) }
        }
    }
}
