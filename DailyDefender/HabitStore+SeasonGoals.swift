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

    // Helpers
    fileprivate func parseSeasonKey(_ key: String) -> (Int, SeasonName)? {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]),
              let s = SeasonName(rawValue: String(parts[1])) else { return nil }
        return (y, s)
    }
}

// MARK: - Seasonal Goals storage (UserDefaults)

private enum SeasonKeys {
    // Legacy (pre-pillar) key: one flat list per season key
    static func goalsLegacy(_ key: String) -> String { "season_goals_\(key)" }

    // New per-pillar keys: season_goals_2025-Winter_phys, etc.
    static func goals(_ key: String, pillarKey: String) -> String {
        "season_goals_\(key)_\(pillarKey)"
    }
}

// Per-pillar key suffixes (mirror Monthly/Yearly pattern)
private extension Pillar {
    var seasonKeySuffix: String {
        switch self {
        case .Physiology: return "phys"
        case .Piety:      return "piety"
        case .People:     return "people"
        case .Production: return "prod"
        }
    }
}

extension HabitStore {
    // MARK: Legacy flat API (kept for compatibility / migration)

    /// Load encoded goal lines for a season (legacy flat list).
    func seasonGoals(for key: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: SeasonKeys.goalsLegacy(key)) ?? []
    }

    /// Save encoded goals for a season (legacy flat list).
    func setSeasonGoals(_ key: String, _ lines: [String]) {
        UserDefaults.standard.set(lines, forKey: SeasonKeys.goalsLegacy(key))
        objectWillChange.send()
    }

    // MARK: New per-pillar API

    /// Load encoded goal lines for a given season key + pillar.
    /// If no per-pillar data exists yet but legacy data does, we migrate
    /// that legacy list into Physiology for this season.
    func seasonGoals(for key: String, pillar: Pillar) -> [String] {
        let d = UserDefaults.standard

        let phys   = d.stringArray(forKey: SeasonKeys.goals(key, pillarKey: Pillar.Physiology.seasonKeySuffix)) ?? []
        let piety  = d.stringArray(forKey: SeasonKeys.goals(key, pillarKey: Pillar.Piety.seasonKeySuffix)) ?? []
        let people = d.stringArray(forKey: SeasonKeys.goals(key, pillarKey: Pillar.People.seasonKeySuffix)) ?? []
        let prod   = d.stringArray(forKey: SeasonKeys.goals(key, pillarKey: Pillar.Production.seasonKeySuffix)) ?? []

        let anyPillarHasData = !phys.isEmpty || !piety.isEmpty || !people.isEmpty || !prod.isEmpty

        if !anyPillarHasData {
            // See if there is legacy data to migrate
            if let legacy = d.stringArray(forKey: SeasonKeys.goalsLegacy(key)), !legacy.isEmpty {
                // MIGRATION: ALL existing seasonal goals → Physiology
                d.set(legacy, forKey: SeasonKeys.goals(key, pillarKey: Pillar.Physiology.seasonKeySuffix))
                d.removeObject(forKey: SeasonKeys.goalsLegacy(key))
                objectWillChange.send()

                if pillar == .Physiology {
                    return legacy
                } else {
                    return []
                }
            }
        }

        return d.stringArray(forKey: SeasonKeys.goals(key, pillarKey: pillar.seasonKeySuffix)) ?? []
    }

    /// Save encoded goal lines for a given season key + pillar.
    func setSeasonGoals(_ key: String, _ lines: [String], pillar: Pillar) {
        let d = UserDefaults.standard
        d.set(lines, forKey: SeasonKeys.goals(key, pillarKey: pillar.seasonKeySuffix))
        objectWillChange.send()
    }
}
