import Foundation
import Combine

// MARK: - YearMonth helpers

extension HabitStore {
    /// "YYYY-MM" for current local date (e.g., "2025-10").
    func ymKey(for date: Date = Date()) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        let y = comps.year ?? 1970
        let m = (comps.month ?? 1)
        return String(format: "%04d-%02d", y, m)
    }

    /// Step a "YYYY-MM" key by ±months and return the new key.
    func step(_ ym: String, by months: Int) -> String {
        let parts = ym.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let date = Calendar.current.date(from: DateComponents(year: y, month: m, day: 1))
        else { return ym }

        guard let next = Calendar.current.date(byAdding: .month, value: months, to: date) else { return ym }
        return ymKey(for: next)
    }

    /// Human title "Month YYYY" (e.g., "October 2025").
    func ymTitle(_ ym: String) -> String {
        let parts = ym.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let date = Calendar.current.date(from: DateComponents(year: y, month: m, day: 1))
        else { return ym }
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f.string(from: date)
    }
}

// MARK: - Monthly Goals storage (UserDefaults)

private enum MonthlyKeys {
    // Legacy (pre-pillar) key: one flat list per month
    static func goalsLegacy(_ ym: String) -> String { "monthly_goals_\(ym)" } // value: [String]

    // New per-pillar keys
    static func goals(_ ym: String, pillarKey: String) -> String { "monthly_goals_\(ym)_\(pillarKey)" }
}

private extension Pillar {
    /// Suffix used in the per-pillar UserDefaults keys
    var monthlyKeySuffix: String {
        switch self {
        case .Physiology: return "phys"
        case .Piety:      return "piety"
        case .People:     return "people"
        case .Production: return "prod"
        }
    }
}

extension HabitStore {
    // MARK: Legacy flat list API (kept for backward compatibility / migration)

    /// Load encoded goal lines for a year-month (legacy, flat list).
    func monthlyGoals(for ym: String) -> [String] {
        let d = UserDefaults.standard
        return d.stringArray(forKey: MonthlyKeys.goalsLegacy(ym)) ?? []
    }

    /// Save encoded goal lines (legacy, flat list) and notify observers.
    func setMonthlyGoals(_ lines: [String], for ym: String) {
        let d = UserDefaults.standard
        d.set(lines, forKey: MonthlyKeys.goalsLegacy(ym))
        objectWillChange.send()
    }

    // MARK: New per-pillar API

    /// Load encoded goal lines for a given year-month + pillar.
    /// If no per-pillar data exists yet but legacy data does, we migrate
    /// that legacy list into Physiology (to avoid data loss).
    func monthlyGoals(for ym: String, pillar: Pillar) -> [String] {
        let d = UserDefaults.standard

        // Check if any pillar already has data for this month
        let phys  = d.stringArray(forKey: MonthlyKeys.goals(ym, pillarKey: Pillar.Physiology.monthlyKeySuffix)) ?? []
        let piety = d.stringArray(forKey: MonthlyKeys.goals(ym, pillarKey: Pillar.Piety.monthlyKeySuffix)) ?? []
        let people = d.stringArray(forKey: MonthlyKeys.goals(ym, pillarKey: Pillar.People.monthlyKeySuffix)) ?? []
        let prod  = d.stringArray(forKey: MonthlyKeys.goals(ym, pillarKey: Pillar.Production.monthlyKeySuffix)) ?? []

        let anyPillarHasData = !phys.isEmpty || !piety.isEmpty || !people.isEmpty || !prod.isEmpty

        if !anyPillarHasData {
            // See if there is legacy data to migrate
            if let legacy = d.stringArray(forKey: MonthlyKeys.goalsLegacy(ym)), !legacy.isEmpty {
                // Migrate ALL existing monthly goals → Physiology
                d.set(legacy, forKey: MonthlyKeys.goals(ym, pillarKey: Pillar.Physiology.monthlyKeySuffix))
                d.removeObject(forKey: MonthlyKeys.goalsLegacy(ym))

                if pillar == .Physiology {
                    return legacy
                } else {
                    return []
                }
            }
        }

        // Normal per-pillar read
        return d.stringArray(forKey: MonthlyKeys.goals(ym, pillarKey: pillar.monthlyKeySuffix)) ?? []
    }

    /// Save encoded goal lines for a given year-month + pillar.
    func setMonthlyGoals(_ lines: [String], for ym: String, pillar: Pillar) {
        let d = UserDefaults.standard
        d.set(lines, forKey: MonthlyKeys.goals(ym, pillarKey: pillar.monthlyKeySuffix))
        objectWillChange.send()
    }
}
