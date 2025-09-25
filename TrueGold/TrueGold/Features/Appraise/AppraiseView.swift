import SwiftUI

struct AppraiseView: View {
    @ObservedObject var viewModel: AppraiseViewModel

    // Local user inputs
    @State private var metal: Metal = .gold
    @State private var purity: Purity = .k24
    @State private var weight: String = ""
    @State private var unit: Unit = .gram
    @State private var currencyCode: String = "USD"

    var body: some View {
        Form {
            Section("Item") {
                // Metal
                HStack {
                    Text("Metal")
                    Spacer()
                    metalPicker()              // picker hides its own label
                }

                // Purity
                LabeledContent("Purity") {
                                   Spacer(minLength: 10)
                                   purityPicker()
                               }
                
                // Purity using HStack with expanding right column
                HStack {
                    Text("Purity")
                    HStack {
                        Spacer()
                        purityPicker()   // standard Picker; spacer prevents truncation
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Weight + Unit — field placeholder acts as the label
                HStack(spacing: 12) {
                    TextField("Enter weight", text: $weight)
                        .keyboardType(.decimalPad)
                    unitPicker()
                }

                // Currency
                HStack {
                    Text("Currency")
                    Spacer()
                    currencyPicker()           // picker hides its own label
                }
            }

            Section("Result") {
                if viewModel.isLoading {
                    HStack { ProgressView(); Text("Appraising…") }
                } else if let r = viewModel.result {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Per gram")
                            Spacer()
                            Text("\(r.currency) \(r.perGram.formatted(.number.precision(.fractionLength(2))))")
                                .monospacedDigit()
                        }
                        HStack {
                            Text("Total")
                            Spacer()
                            Text("\(r.currency) \(r.total.formatted(.number.precision(.fractionLength(2))))")
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                        }
                        Text(r.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let e = viewModel.errorMessage {
                    Label(e, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    Text("Enter details above, then tap Appraise.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    let sanitized = weight.replacingOccurrences(of: ",", with: ".")
                    guard let input = Double(sanitized), input > 0 else {
                        viewModel.errorMessage = "Invalid weight"
                        viewModel.result = nil
                        return
                    }

                    // Normalize to grams
                    let grams: Double
                    switch unit {
                    case .gram: grams = input
                    case .thaiBahtWeight: grams = input * 15.244
                    case .ozt: grams = input * 31.1034768
                    }

                    // Map UI selection → pricing source and factor
                    let kind: MetalKind
                    let factor: Double
                    switch metal {
                    case .gold:
                        if purity == .thai965 {
                            kind = .goldThai965
                            factor = 1.0 // baked-in 96.5% on market quote
                        } else {
                            kind = .goldSpot
                            factor = purity.factor(for: .gold)
                        }
                    case .silver:
                        kind = .silverSpot
                        factor = purity.factor(for: .silver)
                    case .platinum:
                        kind = .platinumSpot
                        factor = purity.factor(for: .platinum)
                    case .palladium:
                        kind = .palladiumSpot
                        factor = purity.factor(for: .palladium)
                    }

                    Task {
                        await viewModel.appraise(
                            kind: kind,
                            purityFactor: factor,
                            grams: grams,
                            currency: currencyCode
                        )
                    }
                } label: {
                    Label("Appraise", systemImage: "scalemass.fill")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .colorInvert() // keep readable against yellow tint
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Appraise")
    }

    // MARK: - Pickers (hide internal labels; outer labels remain in rows)

    private func metalPicker() -> some View {
        Picker("Metal", selection: $metal) {
            Text("Gold").tag(Metal.gold)
            Text("Silver").tag(Metal.silver)
            Text("Platinum").tag(Metal.platinum)
            Text("Palladium").tag(Metal.palladium)
        }
        .labelsHidden()
    }
 
    
    private func purityPicker() -> some View {
        Picker("Purity", selection: $purity) {
            ForEach(Purity.allCases) { p in
                Text(p.fullLabel).tag(p)
            }
        }
        .labelsHidden() // since you already provide "Purity" on the left
    }

  /*
    private func purityPicker() -> some View {
        Menu {
            ForEach(Purity.allCases) { p in
                Button {
                    purity = p
                } label: {
                    Text(p.fullLabel)
                }
            }
        } label: {
            Text(purity.fullLabel) // collapsed shows K + % as well
                .lineLimit(1)
        }
    }
*/
    private func unitPicker() -> some View {
        Picker("Unit", selection: $unit) {
            Text("g").tag(Unit.gram)
            Text("baht wt").tag(Unit.thaiBahtWeight)
            Text("ozt").tag(Unit.ozt)
        }
        .labelsHidden()
        .pickerStyle(.segmented) // segmented is fine here and compact
    }

    private func currencyPicker() -> some View {
        Picker("Currency", selection: $currencyCode) {
            ForEach(Currency.allCases) { c in
                Text("\(c.flagEmoji) \(c.code)").tag(c.code)
            }
        }
        .labelsHidden()
    }
}

// MARK: - Local helpers kept private to this file
private enum Metal: String, CaseIterable, Identifiable {
    case gold, silver, platinum, palladium
    var id: String { rawValue }
}

private enum Unit: String, CaseIterable, Identifiable {
    case gram, thaiBahtWeight, ozt
    var id: String { rawValue }
}

private enum Purity: String, CaseIterable, Identifiable {
    case k24, thai965, k22, k21, k20, k18, k14, k9

    var id: String { rawValue }

    /// Full label used inside the picker list.
    var fullLabel: String {
        switch self {
        case .thai965: return "23K Thai (96.5%)"
        case .k24: return "24K (99.9%)"
        case .k22: return "22K (91.7%)"
        case .k21: return "21K (87.5%)"
        case .k20: return "20K (83.3%)"
        case .k18: return "18K (75.0%)"
        case .k14: return "14K (58.5%)"
        case .k9:  return "9K (37.5%)"
        }
    }

    var shortK: String {
        switch self {
        case .thai965: return "23K Thai"
        case .k24:     return "24K"
        case .k22:     return "22K"
        case .k21:     return "21K"
        case .k20:     return "20K"
        case .k18:     return "18K"
        case .k14:     return "14K"
        case .k9:      return "9K"
        }
    }

    /// Factors when not using Thai market source (which is baked at call site).
    func factor(for metal: Metal) -> Double {
        switch metal {
        case .gold:
            switch self {
            case .thai965: return 0.965 // not applied when using Thai source
            case .k24: return 0.999
            case .k22: return 0.917
            case .k21: return 0.875
            case .k20: return 0.833
            case .k18: return 0.750
            case .k14: return 0.585
            case .k9:  return 0.375
            }
        case .silver, .platinum, .palladium:
            return 0.999
        }
    }
}
