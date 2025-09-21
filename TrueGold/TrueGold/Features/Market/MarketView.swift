import SwiftUI

struct MarketView: View {
    @ObservedObject var viewModel: MarketViewModel
    @State private var currency = "USD"

    var body: some View {
        NavigationStack {
            List(viewModel.rows) { ValueTile(model: $0) }
                .navigationTitle("Market")
                .safeAreaInset(edge: .top) {
                    if let note = viewModel.notice, !note.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.exclamationmark")
                                .imageScale(.medium)
                            Text(note)
                                .font(.footnote)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.yellow.opacity(0.15))
                        .overlay(
                            Rectangle().frame(height: 0.5).foregroundStyle(.yellow.opacity(0.6)), alignment: .bottom
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Notice: \(note)")
                    }
                }
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
                
                .task {
                    viewModel.performConnectivityNoticeUpdate()   // show banner immediately on first render
                    await viewModel.load(currency: currency)
                }
                .refreshable { await viewModel.load(currency: currency) }
        }
    }
}
