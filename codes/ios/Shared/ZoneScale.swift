import SwiftUI

/// Chart coloring only. These cutoffs are a draft for the screen.
/// They are not a medical standard, a lab test, or a training prescription.
enum TrainingZone: Int, CaseIterable, Identifiable {
    case z1 = 1
    case z2
    case z3
    case z4
    case z5

    var id: Int { rawValue }
    var title: String { "Z\(rawValue)" }
}

enum ZoneScale {
    /// Draft heart-rate bands for chart marks. Not a medical standard.
    /// Reference max heart rate is fixed at 190 bpm because this app does not collect age.
    /// Z1 < 60% (< 114 bpm)
    /// Z2 60–69% (114–132 bpm)
    /// Z3 70–79% (133–151 bpm)
    /// Z4 80–89% (152–170 bpm)
    /// Z5 ≥ 90% (≥ 171 bpm)
    static func heart(_ bpm: Double) -> TrainingZone {
        switch bpm {
        case ..<114: return .z1
        case ..<133: return .z2
        case ..<152: return .z3
        case ..<171: return .z4
        default: return .z5
        }
    }

    /// Draft cadence bands in steps per minute, for chart marks only.
    /// Z1 < 150, Z2 150–164, Z3 165–174, Z4 175–184, Z5 ≥ 185.
    static func cadence(_ stepsPerMinute: Double) -> TrainingZone {
        switch stepsPerMinute {
        case ..<150: return .z1
        case ..<165: return .z2
        case ..<175: return .z3
        case ..<185: return .z4
        default: return .z5
        }
    }

    /// Draft pace bands in seconds per kilometer. Faster pace maps to a higher zone.
    /// Z5 < 300 (faster than 5'00"), Z4 300–329, Z3 330–359, Z2 360–419, Z1 ≥ 420.
    static func pace(_ secondsPerKm: Double) -> TrainingZone {
        switch secondsPerKm {
        case ..<300: return .z5
        case ..<330: return .z4
        case ..<360: return .z3
        case ..<420: return .z2
        default: return .z1
        }
    }

    /// Draft stride bands in meters per step.
    /// Z1 < 0.80, Z2 0.80–0.99, Z3 1.00–1.19, Z4 1.20–1.39, Z5 ≥ 1.40.
    static func stride(_ meters: Double) -> TrainingZone {
        switch meters {
        case ..<0.80: return .z1
        case ..<1.00: return .z2
        case ..<1.20: return .z3
        case ..<1.40: return .z4
        default: return .z5
        }
    }

    /// Draft ground-contact bands in milliseconds. Shorter contact maps to a higher zone.
    /// Z5 < 190, Z4 190–219, Z3 220–249, Z2 250–279, Z1 ≥ 280.
    static func groundContact(_ milliseconds: Double) -> TrainingZone {
        switch milliseconds {
        case ..<190: return .z5
        case ..<220: return .z4
        case ..<250: return .z3
        case ..<280: return .z2
        default: return .z1
        }
    }

    /// Draft power bands in watts, for chart marks only.
    /// Z1 < 150, Z2 150–199, Z3 200–249, Z4 250–299, Z5 ≥ 300.
    static func power(_ watts: Double) -> TrainingZone {
        switch watts {
        case ..<150: return .z1
        case ..<200: return .z2
        case ..<250: return .z3
        case ..<300: return .z4
        default: return .z5
        }
    }

    /// Altitude is not a heart-rate zone. Split this workout's own min…max into five equal bands
    /// so the chart can still use Z1–Z5 marks. Draft display rule, not a medical standard.
    static func elevation(_ meters: Double, low: Double, high: Double) -> TrainingZone {
        let span = high - low
        guard span > 0.5 else { return .z3 }
        let t = (meters - low) / span
        switch t {
        case ..<0.2: return .z1
        case ..<0.4: return .z2
        case ..<0.6: return .z3
        case ..<0.8: return .z4
        default: return .z5
        }
    }

    static func color(_ zone: TrainingZone, heart: Bool) -> Color {
        if heart {
            switch zone {
            case .z1: return Color(red: 254 / 255, green: 202 / 255, blue: 202 / 255)
            case .z2: return Color(red: 252 / 255, green: 165 / 255, blue: 165 / 255)
            case .z3: return Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255)
            case .z4: return Color.omniCoral
            case .z5: return Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255)
            }
        }
        switch zone {
        case .z1: return Color(red: 186 / 255, green: 230 / 255, blue: 253 / 255)
        case .z2: return Color.omniIce
        case .z3: return Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255)
        case .z4: return Color.omniCobalt
        case .z5: return Color(red: 3 / 255, green: 105 / 255, blue: 161 / 255)
        }
    }
}
