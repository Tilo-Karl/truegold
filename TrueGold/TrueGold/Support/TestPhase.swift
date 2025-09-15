//  TestPhase.swift
//  tilogold
//
//  Created by Tilo Delau on 2025-06-14.
//
//  🔬 TestPhase Instructions – Set `currentPhase` to simulate different fallbacks:
//  -------------------------------------------------------------------------
//  ✅ Phase 1: LIVE API DATA
//     - TestPhase.currentPhase = .live
//     - Internet: ON (real API call)
//     - Cache: Automatically cleared
//     - JSON: Ignored
//     → Expect: ✅ "Live exchange rates fetched from API"
//
//  ✅ Phase 2: CACHED DATA
//     - TestPhase.currentPhase = .cached
//     - Internet: ON or OFF
//     - Cache: Must already exist (from earlier run)
//     - Cache will NOT be cleared
//     → Expect: 📦 "Using CACHED data from UserDefaults"
//
//  ✅ Phase 3: BUNDLED JSON FALLBACK
//     - TestPhase.currentPhase = .bundled
//     - Internet: OFF or API must fail
//     - Cache: Automatically cleared
//     - JSON: Must contain valid JSON
//     → Expect: ❌ "API fetch failed – using BUNDLED fallback JSON"
//
//  ✅ Phase 4: HARDCODED MOCK FALLBACK
//     - TestPhase.currentPhase = .hardcoded
//     - Internet: OFF
//     - Cache: Automatically cleared
//     - JSON: Must be empty `{}` or invalid
//     → Expect: ❌ "API fetch failed – using HARDCODED fallback"
//
//  💡 Notes:
//     - All phases (except `.cached`) will clear cache on launch.
//     - Do not commit `.hardcoded` as the active phase.
//     - Set `.live` or `.cached` for normal development mode.
//     - URLSession is very sneaky and uses cache sometimes when no wifi and pretends it has fetch live data
//     - Completetly over engineered.
//       This is why we don't lose exchange rates in a cave.
//

import Foundation

enum TestPhase {
    case live       // Phase 1 - Release should be set to this, live
    case cached     // Phase 2
    case bundled    // Phase 3
    case hardcoded  // Phase 4

    static let currentPhase: TestPhase = .live // ⬅️ Change this to simulate a phase

    // These computed values configure AppConfig appropriately
    static var useMockData: Bool {
        switch currentPhase {
        case .hardcoded: return false
        case .live, .cached, .bundled: return false
        }
    }

    static var forceLiveExchangeRate: Bool {
        switch currentPhase {
        case .live, .bundled, .hardcoded: return true
        case .cached: return false
        }
    }

    static var clearCache: Bool {
        switch currentPhase {
        case .cached: return false
        default: return true
        }
    }

    // Utility function called in GoldPriceViewModel init
    static func clearUserDefaultsIfNeeded() {
        guard clearCache else { return }
        print("🧹 Clearing cached exchange rates from UserDefaults [TestPhase: \(currentPhase)]")
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "ExchangeRateCache_ALL_rates")
        defaults.removeObject(forKey: "ExchangeRateCache_ALL_timestamp")
    }
}
