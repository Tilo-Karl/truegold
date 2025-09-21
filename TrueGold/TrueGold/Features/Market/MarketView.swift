import SwiftUI

struct MarketView: View {
    @ObservedObject var viewModel: MarketViewModel
    @State private var currency = "USD"

    var body: some View {
        NavigationStack {
            List(viewModel.rows) { ValueTile(model: $0) }
                .navigationTitle("Market")
                .overlay {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.large)
                    } else if let msg = viewModel.errorMessage, viewModel.rows.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .imageScale(.large)
                            Text(msg)
                                .multilineTextAlignment(.center)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Button("Retry") {
                                Task { await viewModel.load(currency: currency) }
                            }
                        }
                        .padding()
                    }
                }
                .task { await viewModel.load(currency: currency) }
                .refreshable { await viewModel.load(currency: currency) }
        }
    }
}
