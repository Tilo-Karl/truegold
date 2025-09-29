import SwiftUI

struct MarketView: View {
    @ObservedObject var viewModel: MarketViewModel
    @State private var currency = "USD"
    @State private var unit: UnitToggle = .gram

    private enum MarketPrefs {
        static let currencyKey = "Market.lastCurrencyCode"
        static let unitKey = "Market.lastUnit"
    }

    var body: some View {
        NavigationStack {
            List {
                // Controls
                Section {
                    LabeledContent("Currency") {
                        Picker("Currency", selection: $currency) {
                            ForEach(Currency.allCases) { c in
                                Text("\(c.flagEmoji) \(c.symbol) \(c.code)").tag(c.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    LabeledContent("Unit") {
                        Picker("Unit", selection: $unit) {
                            ForEach(UnitToggle.allCases) { u in
                                Text(u.label).tag(u)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize() // shrink to content size and not stretch to max
                        .frame(maxWidth: 260, alignment: .trailing) // cap width so it aligns nicely on small & large phones
                    }
                }

                ForEach(viewModel.rows) { ValueTile(model: $0) }
            }
            .navigationTitle("Market")
            .navigationBarTitleDisplayMode(.large)
            .contentMargins(.top, 12)
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .toolbarBackground(Color.appPurple, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                // Restore saved prefs (if any) before first load
                if let savedCurrency = UserDefaults.standard.string(forKey: MarketPrefs.currencyKey) {
                    currency = savedCurrency
                }
                if let savedUnitRaw = UserDefaults.standard.string(forKey: MarketPrefs.unitKey),
                   let savedUnit = UnitToggle(rawValue: savedUnitRaw) {
                    unit = savedUnit
                }
                viewModel.performConnectivityNoticeUpdate()   // show banner immediately on first render
                await viewModel.setUnit(.init(unit))
                await viewModel.load(currency: currency)
            }
            .refreshable { await viewModel.load(currency: currency) }
            .onChange(of: currency) { _ in
                UserDefaults.standard.set(currency, forKey: MarketPrefs.currencyKey)
                Task { await viewModel.load(currency: currency) }
            }
            .onChange(of: unit) { _ in
                UserDefaults.standard.set(unit.rawValue, forKey: MarketPrefs.unitKey)
                Task {
                    await viewModel.setUnit(.init(unit))
                    await viewModel.load(currency: currency)
                }
            }
        }
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
