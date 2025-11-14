// HabitStore+YearlyGoals.swift
import Foundation

// MARK: - Year helpers

extension HabitStore {
    /// "YYYY" for current local date (e.g., "2025").
    func yearKey(for date: Date = Date()) -> String {
        let y = Calendar.current.component(.year, from: date)
        return String(format: "%04d", y)
    }

    /// Step a "YYYY" key by ±years and return the new key.
    func stepYear(_ yearKey: String, by years: Int) -> String {
        guard let y = Int(yearKey),
              let date = Calendar.current.date(from: DateComponents(year: y, month: 1, day: 1)),
              let next = Calendar.current.date(byAdding: .year, value: years, to: date)
        else { return yearKey }
        return self.yearKey(for: next)
    }

    /// Human title for a year (currently just the same, but separated for parity/extensibility).
    func yearTitle(_ yearKey: String) -> String {
        yearKey
    }
}

// MARK: - Yearly Goals storage (UserDefaults)

private enum YearlyKeys {
    // Legacy (pre-pillar) key: one flat list per year
    static func goalsLegacy(_ yearKey: String) -> String { "yearly_goals_\(yearKey)" } // value: [String]

    // New per-pillar keys: yearly_goals_2025_phys, etc.
    static func goals(_ yearKey: String, pillarKey: String) -> String {
        "yearly_goals_\(yearKey)_\(pillarKey)"
    }
}

// We give Yearly its own pillar suffix helper so we don't depend on other files.
private extension Pillar {
    /// Suffix used in the per-pillar UserDefaults keys (matches Monthly)
    var yearlyKeySuffix: String {
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

    /// Load encoded goal lines for a year (legacy, flat list).
    func yearlyGoals(for yearKey: String) -> [String] {
        let d = UserDefaults.standard
        return d.stringArray(forKey: YearlyKeys.goalsLegacy(yearKey)) ?? []
    }

    /// Save encoded goal lines and notify observers (legacy flat API).
    func setYearlyGoals(_ lines: [String], for yearKey: String) {
        let d = UserDefaults.standard
        d.set(lines, forKey: YearlyKeys.goalsLegacy(yearKey))
        // Ensure SwiftUI updates even if no other @Published changed
        objectWillChange.send()
    }

    // MARK: New per-pillar API

    /// Load encoded goal lines for a given year + pillar.
    /// If no per-pillar data exists yet but legacy data does, we migrate
    /// that legacy list into Physiology (to avoid data loss).
    func yearlyGoals(for yearKey: String, pillar: Pillar) -> [String] {
        let d = UserDefaults.standard

        // Check if any pillar already has data for this year
        let phys   = d.stringArray(forKey: YearlyKeys.goals(yearKey, pillarKey: Pillar.Physiology.yearlyKeySuffix)) ?? []
        let piety  = d.stringArray(forKey: YearlyKeys.goals(yearKey, pillarKey: Pillar.Piety.yearlyKeySuffix)) ?? []
        let people = d.stringArray(forKey: YearlyKeys.goals(yearKey, pillarKey: Pillar.People.yearlyKeySuffix)) ?? []
        let prod   = d.stringArray(forKey: YearlyKeys.goals(yearKey, pillarKey: Pillar.Production.yearlyKeySuffix)) ?? []

        let anyPillarHasData = !phys.isEmpty || !piety.isEmpty || !people.isEmpty || !prod.isEmpty

        if !anyPillarHasData {
            // See if there is legacy data to migrate
            if let legacy = d.stringArray(forKey: YearlyKeys.goalsLegacy(yearKey)), !legacy.isEmpty {
                // 🔁 MIGRATION: ALL existing yearly goals → Physiology
                d.set(legacy, forKey: YearlyKeys.goals(yearKey, pillarKey: Pillar.Physiology.yearlyKeySuffix))
                d.removeObject(forKey: YearlyKeys.goalsLegacy(yearKey))
                objectWillChange.send()

                if pillar == .Physiology {
                    return legacy
                } else {
                    return []
                }
            }
        }

        // Normal per-pillar read
        return d.stringArray(forKey: YearlyKeys.goals(yearKey, pillarKey: pillar.yearlyKeySuffix)) ?? []
    }

    /// Save encoded goal lines for a given year + pillar.
    func setYearlyGoals(_ lines: [String], for yearKey: String, pillar: Pillar) {
        let d = UserDefaults.standard
        d.set(lines, forKey: YearlyKeys.goals(yearKey, pillarKey: pillar.yearlyKeySuffix))
        objectWillChange.send()
    }
}
