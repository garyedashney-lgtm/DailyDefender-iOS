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
    static func goals(_ yearKey: String) -> String { "yearly_goals_\(yearKey)" } // value: [String]
}

extension HabitStore {
    /// Load encoded goal lines for a year (may be empty).
    func yearlyGoals(for yearKey: String) -> [String] {
        let d = UserDefaults.standard
        return d.stringArray(forKey: YearlyKeys.goals(yearKey)) ?? []
    }

    /// Save encoded goal lines and notify observers.
    func setYearlyGoals(_ lines: [String], for yearKey: String) {
        let d = UserDefaults.standard
        d.set(lines, forKey: YearlyKeys.goals(yearKey))
        // Ensure SwiftUI updates even if no other @Published changed
        objectWillChange.send()
    }
}
