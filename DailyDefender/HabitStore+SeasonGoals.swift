import Foundation

// Simple season enum (matches Android naming)
enum SeasonName: String, CaseIterable {
    case Winter, Spring, Summer, Fall
}

extension HabitStore {
    // “2025-Winter” for today
    func seasonKeyForToday(_ date: Date = Date()) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        let m = comps.month ?? 1
        let y = comps.year ?? 1970
        // Winter spans Dec–Mar; Dec belongs to Winter of the same calendar year
        let season: SeasonName
        var year = y
        switch m {
        case 12: season = .Winter
        case 1,2: season = .Winter; year = y - 1 // Jan/Feb are Winter of previous year span
        case 3...5: season = .Spring
        case 6...8: season = .Summer
        default: season = .Fall
        }
        return String(format: "%04d-%@", year, season.rawValue)
    }

    // MARK: - Season stepping logic (meteorological calendar)
    //
    // Meteorological seasons are fixed 3-month blocks aligned to the calendar:
    //   • Spring  = Mar–May
    //   • Summer  = Jun–Aug
    //   • Fall    = Sep–Nov
    //   • Winter  = Dec–Feb  (bridges years)
    //
    // Anchor rule: "Winter 2025" = Dec 2025 → Feb 2026
    //   → The anchor year (2025) is the December year.
    //
    // Stepping rules:
    //   • Fall Y   → Winter Y        (same anchor year)
    //   • Winter Y → Spring Y+1      (crosses into new year)
    //   • Spring Y → Summer Y
    //   • Summer Y → Fall Y
    //
    // Backwards stepping mirrors this:
    //   • Spring Y → Winter Y-1
    //   • Winter Y → Fall Y
    //   • Fall Y   → Summer Y
    //   • Summer Y → Spring Y
    //
    // This ensures Winter always bridges years correctly and
    // labels remain intuitive (e.g., "Winter 2025" covers Dec ’25 – Feb ’26).
    
    // Step ±1 season from a key like "2025-Winter"
    func stepSeason(_ key: String, by delta: Int) -> String {
        guard let (startYear, season) = parseSeasonKey(key) else { return key }
        let order: [SeasonName] = [.Winter, .Spring, .Summer, .Fall]
        var idx = order.firstIndex(of: season) ?? 0
        var year = startYear
        var steps = delta

        if steps > 0 {
            while steps > 0 {
                // moving forward: leaving Winter bumps the anchor year
                if order[idx] == .Winter { year += 1 }
                idx = (idx + 1) % order.count
                steps -= 1
            }
        } else if steps < 0 {
            while steps < 0 {
                // moving backward: entering Winter bumps anchor year down
                let nextIdx = (idx - 1 + order.count) % order.count
                if order[nextIdx] == .Winter { year -= 1 }
                idx = nextIdx
                steps += 1
            }
        }

        return String(format: "%04d-%@", year, order[idx].rawValue)
    }

    // Human title parts for center header & selector
    func seasonTitleParts(_ key: String) -> (name: String, year: Int) {
        guard let (y, s) = parseSeasonKey(key) else { return (key, 0) }
        return (s.rawValue, y)
    }

    // Emoji for the selector
    func seasonEmoji(_ name: String) -> String {
        switch name {
        case "Winter": return "❄️"
        case "Spring": return "🌸"
        case "Summer": return "☀️"
        default:       return "🍂"
        }
    }

    // Span text like "Dec ’24 – Mar ’25"
    func seasonSpan(_ key: String) -> String {
        guard let (y, s) = parseSeasonKey(key) else { return "" }
        func y2(_ v: Int) -> String { "’" + String(format: "%02d", v % 100) }
        switch s {
        case .Fall:   return "Sep \(y2(y)) – Dec \(y2(y))"
        case .Winter: return "Dec \(y2(y)) – Mar \(y2(y + 1))"
        case .Spring: return "Mar \(y2(y)) – Jun \(y2(y))"
        case .Summer: return "Jun \(y2(y)) – Sep \(y2(y))"
        }
    }

    // Storage
    private enum SeasonKeys {
        static func goals(_ key: String) -> String { "season_goals_\(key)" }
    }

    func seasonGoals(for key: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: SeasonKeys.goals(key)) ?? []
    }

    func setSeasonGoals(_ key: String, _ lines: [String]) {
        UserDefaults.standard.set(lines, forKey: SeasonKeys.goals(key))
        objectWillChange.send()
    }

    // Helpers
    private func parseSeasonKey(_ key: String) -> (Int, SeasonName)? {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]),
              let s = SeasonName(rawValue: String(parts[1])) else { return nil }
        return (y, s)
    }
}
