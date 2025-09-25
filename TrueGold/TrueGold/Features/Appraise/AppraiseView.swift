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
                    metalPicker()
                }

                // Purity
                LabeledContent("Purity") {
                    Spacer() // stop truncation of picker values.
                    purityPicker()
                }
                
  /* ALTERNATIVE LAYOUT (kept for reference)
     Use this HStack variant when a Picker truncates ("…") inside Form rows.
     Why it works: the inner HStack + `.frame(maxWidth: .infinity, alignment: .trailing)`
     forces the right column to expand, so `Spacer()` actually pushes the picker and
     gives it room to render without truncation. `LabeledContent` achieves a similar
     effect automatically, so the version above is simpler when you don't need
     custom behavior.
     To activate, replace the `LabeledContent("Purity")` row with the block below.
    
   
                // Purity using HStack with expanding right column
                HStack {
                    Text("Purity")
                    HStack {
                        Spacer()
                        purityPicker()// standard Picker; spacer prevents truncation
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
   */

                // Weight + Unit — field placeholder acts as the label
                HStack(spacing: 12) {
                    TextField("Enter weight", text: $weight)
                        .keyboardType(.decimalPad)
                    // I don't know why but removing Spacer() gave me
                    // more room for Lượng (VN) (37.50g) on 2 lines instead of 3
                    //Spacer()
                    unitPicker()
                }

                // Currency
                HStack {
                    Text("Currency")
                    Spacer()
                    currencyPicker()
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
                    handleAppraiseTap()
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

    // MARK: - Actions
    private func handleAppraiseTap() {
        let sanitized = weight.replacingOccurrences(of: ",", with: ".")
        guard let input = Double(sanitized), input > 0 else {
            viewModel.errorMessage = "Invalid weight"
            viewModel.result = nil
            return
        }

        // Normalize to grams
        let grams = input * unit.gramsPerUnit

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
                Text(p.purityPickerLabel).tag(p)
            }
        }
        .labelsHidden()
    }
    
    private func unitPicker() -> some View {
        Picker(selection: $unit, label: Text(unit.unitPickerLabel)) {
            ForEach(Unit.allCases) { u in
                Text(u.unitPickerLabel).tag(u)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
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
    case gram, thaiBahtWeight, ozt, luongVN, chiVN, taelHK, tola
    var id: String { rawValue }

    /// Number of grams in one unit (used for conversion)
    var gramsPerUnit: Double {
        switch self {
        case .gram:            return 1.0
        case .thaiBahtWeight:  return 15.244
        case .ozt:             return 31.1034768
        case .luongVN:         return 37.49          // 1 lượng ≈ 37.49 g
        case .chiVN:           return 3.749          // 1 chỉ = 1/10 lượng
        case .taelHK:          return 37.799364167  // HK tael (tsin)
        case .tola:            return 11.6638038
        }
    }

    /// Label used for both the collapsed control and menu rows.
    var unitPickerLabel: String {
        switch self {
        case .gram:            return "g"
        case .thaiBahtWeight:  return "baht wt (15.24g)"
        case .ozt:             return "ozt (31.10g)"
        case .luongVN:         return "Lượng (VN) (37.49g)"
        case .chiVN:           return "Chỉ (VN) (3.749g)"
        case .taelHK:          return "Tael (HK) (37.80g)"
        case .tola:            return "Tola (11.66g)"
        }
    }
}

private enum Purity: String, CaseIterable, Identifiable {
    case k24, thai965, k22, k21, k20, k18, k14, k9

    var id: String { rawValue }

    /// Full label used inside the picker list.
    var purityPickerLabel: String {
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
