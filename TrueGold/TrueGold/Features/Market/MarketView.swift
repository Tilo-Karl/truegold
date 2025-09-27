import SwiftUI

struct MarketView: View {
    @ObservedObject var viewModel: MarketViewModel
    @State private var currency = "USD"
    @State private var unit: UnitToggle = .gram

    var body: some View {
        NavigationStack {
            List {
                // Controls
                Section {
                    // Currency picker (all currencies)
                    LabeledContent("Currency") {
                        Picker("Currency", selection: $currency) {
                            ForEach(Currency.allCases) { c in
                                Text("\(c.flagEmoji) \(c.symbol) \(c.code)").tag(c.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    // Unit toggle (g / ozt) — wiring into tiles comes next step
                    LabeledContent("Unit") {
                        Picker("Unit", selection: $unit) {
                            ForEach(UnitToggle.allCases) { u in
                                Text(u.label).tag(u)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize()                       // keeps the segmented control from stretching full width
                        .frame(maxWidth: 260, alignment: .trailing) // cap width so it aligns nicely on small & large phones
                    }
                }

                // Data rows
                ForEach(viewModel.rows) { ValueTile(model: $0) }
            }
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
                await viewModel.setUnit(.init(unit))
                await viewModel.load(currency: currency)
            }
            .refreshable { await viewModel.load(currency: currency) }
            .onChange(of: currency) { _ in
                Task { await viewModel.load(currency: currency) }
            }
            .onChange(of: unit) { _ in
                Task {
                    await viewModel.setUnit(.init(unit))
                    await viewModel.load(currency: currency)
                }
            }
            
        }
        .tint(.appPurple)
    }
}

private enum UnitToggle: String, CaseIterable, Identifiable {
    case gram, ozt
    var id: String { rawValue }
    var label: String { self == .gram ? "g" : "ozt" }
}

private extension MarketViewModel.MeasurementUnit {
    init(_ toggle: UnitToggle) { self = (toggle == .gram) ? .gram : .ozt }
}
