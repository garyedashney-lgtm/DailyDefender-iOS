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
    static func goals(_ ym: String) -> String { "monthly_goals_\(ym)" } // value: [String]
}

extension HabitStore {
    /// Load encoded goal lines for a year-month (may be empty).
    func monthlyGoals(for ym: String) -> [String] {
        let d = UserDefaults.standard
        return d.stringArray(forKey: MonthlyKeys.goals(ym)) ?? []
    }

    /// Save encoded goal lines and notify observers.
    func setMonthlyGoals(_ lines: [String], for ym: String) {
        let d = UserDefaults.standard
        d.set(lines, forKey: MonthlyKeys.goals(ym))
        // Ensure SwiftUI updates even if no other @Published changed
        objectWillChange.send()
    }
}
