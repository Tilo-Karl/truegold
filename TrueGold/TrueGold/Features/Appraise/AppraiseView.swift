import SwiftUI

private final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0

    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handle(notification:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handle(notification:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }

    @objc private func handle(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            self.height = 0
            return
        }
        // Translate keyboard height into a bottom inset, minus safe-area so we don't double-inset
        let screen = UIScreen.main.bounds
        let overlap = max(0, screen.maxY - endFrame.minY)
        let safeBottom: CGFloat = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom }
            .first ?? 0
        let target = max(0, overlap - safeBottom)

        // Animate to match the keyboard
        if let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
           let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
            let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
            UIView.animate(withDuration: duration, delay: 0, options: options) {
                self.height = target
            }
        } else {
            self.height = target
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

private enum AppraisePrefs {
    static let currencyKey = "Appraise.lastCurrencyCode"
}

struct AppraiseView: View {
    @ObservedObject var viewModel: AppraiseViewModel

    // Local user inputs
    @State private var metal: Metal = .gold
    @State private var purity: Purity = .k24
    @State private var weight: String = ""
    @State private var unit: Unit = .gram
    @State private var currencyCode: String = "USD"
    @FocusState private var weightFocused: Bool
    @StateObject private var kb = KeyboardObserver()

    // Units allowed for the currently selected metal
    private var allowedUnits: [Unit] { Unit.allowed(for: metal) }
    private var allowedPurities: [Purity] { Purity.allowed(for: metal) }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
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
                                .focused($weightFocused)
                                
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
                        resultSection(viewModel)
                    }
                    
                    Section {
                        appraiseCTA()
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .offset(y: -kb.height / 3)
            .animation(.easeOut(duration: 0.25), value: kb.height)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onChange(of: metal) { _ in
            // If current unit isn't valid for the newly selected metal, reset to grams
            if !allowedUnits.contains(unit) { unit = .gram }
            if !allowedPurities.contains(purity) {
                switch metal {
                case .gold:      purity = .k24
                case .silver:    purity = .silver999
                case .platinum:  purity = .platinum950
                case .palladium: purity = .palladium950
                }
            }
        }
        .onChange(of: currencyCode) { newValue in
            UserDefaults.standard.set(newValue, forKey: AppraisePrefs.currencyKey)
        }
        .onAppear {
            // Restore last selected currency (if previously saved and still valid)
            if let saved = UserDefaults.standard.string(forKey: AppraisePrefs.currencyKey),
               Currency.allCases.contains(where: { $0.code == saved }) {
                currencyCode = saved
            }

            // Ensure current unit/purity are valid for the chosen metal
            if !allowedUnits.contains(unit) { unit = .gram }
            if !allowedPurities.contains(purity) {
                switch metal {
                case .gold:      purity = .k24
                case .silver:    purity = .silver999
                case .platinum:  purity = .platinum950
                case .palladium: purity = .palladium950
                }
            }
        }
        .navigationTitle("Appraise")
        .scrollDismissesKeyboard(.interactively)
        
    }

// MARK: - Reusable CTA - don't need @MainActor because SwiftUI knows button is for main thread
@ViewBuilder
private func appraiseCTA() -> some View {
    Button {
        handleAppraiseTap()
    } label: {
        Text("Appraise")
        //Label("Appraise", systemImage: "scalemass.fill")
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }
    .buttonStyle(.borderedProminent)
}

// MARK: - Actions
private func handleAppraiseTap() {
    weightFocused = false
    UIApplication.shared.endEditing()
    let sanitized = weight.replacingOccurrences(of: ",", with: ".")
    guard let input = Double(sanitized), input > 0 else {
        viewModel.errorMessage = "Please enter a valid weight"
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
            ForEach(allowedPurities) { p in
                Text(p.purityPickerLabel).tag(p)
                    .lineLimit(2)

            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        
    }
    
    private func unitPicker() -> some View {
        Picker(selection: $unit, label: Text(unit.unitPickerLabel)) {
            ForEach(allowedUnits) { u in
                Text(u.unitPickerLabel).tag(u)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu) // 2 lines because picker is retarded and won't shrink
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
        case .luongVN:         return 37.49         // 1 lượng ≈ 37.49 g
        case .chiVN:           return 3.749         // 1 chỉ = 1/10 lượng
        case .taelHK:          return 37.799364167  // HK tael (tsin)
        case .tola:            return 11.6638038
        }
    }

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

    // Units that make sense per metal
    static func allowed(for metal: Metal) -> [Unit] {
        switch metal {
        case .gold:
            return [.gram, .thaiBahtWeight, .ozt, .luongVN, .chiVN, .taelHK, .tola]
        case .silver:
            return [.gram, .ozt]
        case .platinum, .palladium:
            return [.gram, .ozt]
        }
    }
}

private enum Purity: String, CaseIterable, Identifiable {
    case k24, thai965, k22, k21, k20, k18, k14, k10, k9
    case silver999, silver925
    case platinum9995, platinum950
    case palladium9995, palladium950

    var id: String { rawValue }

    /// Label used inside the picker list (full, descriptive).
    var purityPickerLabel: String {
        switch self {
        // Gold
        case .thai965: return "23K Thai (96.5%)"
        case .k24:     return "24K (99.9%)"
        case .k22:     return "22K (91.7%)"
        case .k21:     return "21K (87.5%)"
        case .k20:     return "20K (83.3%)"
        case .k18:     return "18K (75.0%)"
        case .k14:     return "14K (58.5%)"
        case .k10:     return "10K (41.7%)"
        case .k9:      return "9K (37.5%)"
        // Silver
        case .silver999: return "Fine .999 (99.9%)"
        case .silver925: return "Sterling .925 (92.5%)"
        // Platinum
        case .platinum9995: return "Platinum 999.5 (99.95%)"
        case .platinum950:  return "Platinum 950 (95.0%)"
        // Palladium
        case .palladium9995: return "Palladium 999.5 (99.95%)"
        case .palladium950:  return "Palladium 950 (95.0%)"
        }
    }

    /// Purity factor by metal. Thai 96.5% is not applied when the Thai market source is used (handled at call site).
    func factor(for metal: Metal) -> Double {
        switch metal {
        case .gold:
            switch self {
            case .thai965: return 0.965   // note: ignored when using Thai market source
            case .k24:     return 0.999
            case .k22:     return 0.917
            case .k21:     return 0.875
            case .k20:     return 0.833
            case .k18:     return 0.750
            case .k14:     return 0.585
            case .k10:     return 0.417
            case .k9:      return 0.375
            default:       return 0.999   // not expected for gold, but keep safe default
            }
        case .silver:
            switch self {
            case .silver999: return 0.999
            case .silver925: return 0.925
            default:         return 0.999
            }
        case .platinum:
            switch self {
            case .platinum9995: return 0.9995
            case .platinum950:  return 0.950
            default:            return 0.9995
            }
        case .palladium:
            switch self {
            case .palladium9995: return 0.9995
            case .palladium950:  return 0.950
            default:             return 0.9995
            }
        }
    }

    /// Allowed purity options per metal (drives the picker list)
    static func allowed(for metal: Metal) -> [Purity] {
        switch metal {
        case .gold:
            return [.k24, .thai965, .k22, .k21, .k20, .k18, .k14, .k10, .k9]
        case .silver:
            return [.silver999, .silver925]
        case .platinum:
            return [.platinum950, .platinum9995]
        case .palladium:
            return [.palladium950, .palladium9995]
        }
    }
}

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

    // MARK: - Result Section Helper
    @MainActor // @MainActor: keep this view helper on the UI thread so it can safely read viewModel state
    @ViewBuilder
    private func resultSection(_ vm: AppraiseViewModel) -> some View {
        if vm.isLoading {
            HStack { ProgressView(); Text("Appraising…") }
        } else if let r = vm.result {
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
        } else if let e = vm.errorMessage {
            Label(e, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        } else {
            Text("Enter details above, then tap Appraise.")
                .foregroundStyle(.secondary)
        }
    }
