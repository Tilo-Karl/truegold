import SwiftUI

// Step 1: UI only (safe). We'll wire logic to the ViewModel in the next step.
struct AppraiseView: View {
    @ObservedObject var viewModel: AppraiseViewModel

    // Local user inputs (pure UI state for now)
    @State private var metal: Metal = .gold
    @State private var purity: Purity = .k24
    @State private var weight: String = ""
    @State private var unit: Unit = .gram
    @State private var currencyCode: String = "USD"

    var body: some View {
        Form {
            Section("Item") {
                metalPicker()
                VStack(alignment: .leading, spacing: 4) {
                    purityPicker()
                }
                HStack {
                    TextField("Enter weight", text: $weight)
                        .keyboardType(.decimalPad)
                    unitPicker()
                        .frame(maxWidth: 160)
                }
                currencyPicker()
            }

            Section("Result") {
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                        Text("Appraising…")
                    }
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
                    let grams = (unit == .gram) ? input : input * 15.244

                    let kind: MetalKind
                    let effectiveFactor: Double
                    switch metal {
                    case .gold:
                        if purity == .thai965 {
                            // Use Thai market source; purity baked-in so do not multiply again
                            kind = .goldThai965
                            effectiveFactor = 1.0
                        } else {
                            kind = .goldSpot
                            effectiveFactor = purity.factor(for: .gold)
                        }
                    case .silver:
                        kind = .silverSpot
                        effectiveFactor = purity.factor(for: .silver)
                    case .thai965:
                        // If user picked Thai as a separate metal, behave the same
                        kind = .goldThai965
                        effectiveFactor = 1.0
                    }

                    Task {
                        await viewModel.appraise(
                            kind: kind,
                            purityFactor: effectiveFactor,
                            grams: grams,
                            currency: currencyCode
                        )
                    }
                } label: {
                    Label("Appraise", systemImage: "scalemass")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Appraise")
    }

    // MARK: - Subviews (pickers only; layout stays in body)

    private func metalPicker() -> some View {
        Picker("Metal", selection: $metal) {
            Text("Gold").tag(Metal.gold)
            Text("Silver").tag(Metal.silver)
            Text("23K Thai (96.5%)").tag(Metal.thai965)
        }
    }

    private func purityPicker() -> some View {
        Picker("Purity", selection: $purity) {
            ForEach(Purity.allCases) { p in
                Text(p.label).tag(p)
            }
        }
    }

    private func unitPicker() -> some View {
        Picker("", selection: $unit) {
            Text("g").tag(Unit.gram)
            Text("baht wt").tag(Unit.thaiBahtWeight)
        }
        .pickerStyle(.segmented)
    }

    private func currencyPicker() -> some View {
        Picker("Currency", selection: $currencyCode) {
            ForEach(Currency.allCases) { c in
                Text("\(c.flagEmoji) \(c.code)").tag(c.code)
            }
        }
    }
}

// MARK: - Local helpers (kept private to this file)
private enum Metal: String, CaseIterable, Identifiable {
    case gold, silver, thai965
    var id: String { rawValue }
    var title: String {
        switch self {
        case .gold: return "Gold"
        case .silver: return "Silver"
        case .thai965: return "23K Thai (96.5%)"
        }
    }
}

private enum Unit: String, CaseIterable, Identifiable {
    case gram, thaiBahtWeight
    var id: String { rawValue }
}

private enum Purity: String, CaseIterable, Identifiable {
    case k24, thai965, k22, k21, k20, k18, k14, k9

    var id: String { rawValue }
    var label: String {
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

    /// Default purity factors when we are not using a special market source.
    /// For `.thai965` we typically switch to the Thai market source and set factor = 1.0 at call site.
    func factor(for metal: Metal) -> Double {
        switch metal {
        case .gold:
            switch self {
            case .thai965: return 0.965   // not used if we switch to Thai source
            case .k24: return 0.999
            case .k22: return 0.917
            case .k21: return 0.875
            case .k20: return 0.833
            case .k18: return 0.750
            case .k14: return 0.585
            case .k9:  return 0.375
            }
        case .silver:
            return 0.999
        case .thai965:
            return 0.965
        }
    }
}
