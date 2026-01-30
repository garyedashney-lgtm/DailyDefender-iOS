import SwiftUI
import Combine
import Security

// 4 Pillars
enum Pillar: String, CaseIterable, Codable, Hashable {
    case Physiology, Piety, People, Production
    var label: String {
        switch self {
        case .Physiology: return "Physiology"
        case .Piety: return "Piety"
        case .People: return "People"
        case .Production: return "Production"
        }
    }
    var emoji: String {
        switch self {
        case .Physiology: return "🏋"
        case .Piety: return "🙏"
        case .People: return "🧑‍🤝‍🧑"
        case .Production: return "💼"
        }
    }
}

struct Habit: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let pillar: Pillar
    let isCore: Bool
}

let DefaultHabits: [Habit] = [
    Habit(id: "phys_exercise", title: "Move",
          subtitle: "Breath, walk, lift, bike, hike, stretch, etc",
          pillar: .Physiology, isCore: true),
    Habit(id: "phys_nutrition", title: "Nutrition",
          subtitle: "Sleep, fast, eat clean, supplement, hydrate, etc",
          pillar: .Physiology, isCore: true),
    Habit(id: "pray_grat", title: "Gratitude",
          subtitle: "3 blessings, waking up, end-of-day prayer, etc",
          pillar: .Piety, isCore: true),
    Habit(id: "os_upgrade", title: "Mindfulness",
          subtitle: "Body scan & resets, the watcher, etc.",
          pillar: .Piety, isCore: true),
    Habit(id: "peep_social", title: "Connection",
          subtitle: "Rapport Made Easy, Bless /light people up, reverse the flow, etc.",
          pillar: .People, isCore: true),
    Habit(id: "peep_family", title: "Power and Love",
          subtitle: "Problem solve & collaborate in Defense of Meaning and Freedom",
          pillar: .People, isCore: true),
    Habit(id: "prod_flow", title: "Work Rule #1",
          subtitle: "Set goals, share talents, make the job the boss, etc.",
          pillar: .Production, isCore: true),
    Habit(id: "prod_main", title: "Work Rule #2",
          subtitle: "Track progress, Pareto Principle, no one outworks me, etc.",
          pillar: .Production, isCore: true)
]

let HabitById: [String: Habit] =
    Dictionary(uniqueKeysWithValues: DefaultHabits.map { ($0.id, $0) })

struct UserProfile: Codable, Hashable {
    var name = ""
    var email = ""
    var photoPath: String? = nil
    var isRegistered = false
}

// MARK: - UserDefaults keys

fileprivate enum Keys {
    static let today = "today"
    static let completed = "completed_ids"
    static let currentWeek = "current_week_key"

    static func coreTotal(_ week: String) -> String { "weekly_\(week)_total_core" }
    static func optTotal(_ week: String) -> String { "weekly_\(week)_total_opt" }
    static func corePhys(_ week: String) -> String { "weekly_\(week)_core_phys" }
    static func corePiety(_ week: String) -> String { "weekly_\(week)_core_prayer" }
    static func corePeople(_ week: String) -> String { "weekly_\(week)_core_people" }
    static func coreProd(_ week: String) -> String { "weekly_\(week)_core_production" }

    static func oneThing(_ week: String) -> String { "weekly_\(week)_one_thing" }
    static func journal(_ week: String) -> String { "weekly_\(week)_journal" }
    static func wins(_ week: String) -> String { "weekly_\(week)_wins" }
    static func carryText(_ week: String) -> String { "week_carry_text_\(week)" }
    static func carryDone(_ week: String) -> String { "week_carry_done_\(week)" }

    static let profileName = "profile_name"
    static let profileEmail = "profile_email"
    static let profilePhoto = "profile_photo_path"
    static let profileRegisteredV2 = "profile_is_registered_v2"
    static let profileRegisteredLegacy = "profile_is_registered"

    // Sentinel to detect true fresh install vs. update
    static let firstLaunch = "has_launched_v1"
}

// MARK: - Keychain avatar vault

fileprivate enum AvatarVault {
    private static let service = "com.dailydefender.avatar"
    private static let account = "profile_photo"

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func save(_ data: Data) {
        clear()
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess else { return nil }
        return out as? Data
    }
}

@MainActor
final class HabitStore: ObservableObject {
    @Published var today: String
    @Published var completed: Set<String>
    @Published var profile: UserProfile

    // ✅ One-shot brand splash trigger (NO replay like @Published Bool)
    let brandSplashTrigger = PassthroughSubject<Void, Never>()

    private var midnightCancellable: AnyCancellable?

    // Helper to build yyyyMMdd key for stats snapshots
    private func statsDayKey(for localDate: Date) -> String {
        let f = DateFormatter()
        f.calendar = .init(identifier: .gregorian)
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyyMMdd"
        return f.string(from: localDate)
    }

    init() {
        let d = UserDefaults.standard

        self.today = d.string(forKey: Keys.today) ?? Self.localDateString(Date())
        if let arr = d.array(forKey: Keys.completed) as? [String] {
            self.completed = Set(arr)
        } else {
            self.completed = []
        }

        let registered = d.object(forKey: Keys.profileRegisteredV2) as? Bool
            ?? ((d.string(forKey: Keys.profileRegisteredLegacy) ?? "false") == "true")

        self.profile = UserProfile(
            name: d.string(forKey: Keys.profileName) ?? "",
            email: d.string(forKey: Keys.profileEmail) ?? "",
            photoPath: d.string(forKey: Keys.profilePhoto),
            isRegistered: registered
        )

        let isFirstLaunch = (d.object(forKey: Keys.firstLaunch) == nil)
        if isFirstLaunch {
            d.set(true, forKey: Keys.firstLaunch)
            AvatarVault.clear()
        } else {
            if let path = profile.photoPath, !FileManager.default.fileExists(atPath: path) {
                if let data = AvatarVault.load() {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("profile_restored.jpg")
                    if (try? data.write(to: url, options: .atomic)) != nil {
                        profile.photoPath = url.path
                        d.set(url.path, forKey: Keys.profilePhoto)
                    }
                }
            } else if profile.photoPath == nil {
                if let data = AvatarVault.load() {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("profile_restored.jpg")
                    if (try? data.write(to: url, options: .atomic)) != nil {
                        profile.photoPath = url.path
                        d.set(url.path, forKey: Keys.profilePhoto)
                    }
                }
            }
        }

        rollDailyIntoWeekIfNeeded()
        rolloverWeekIfNeeded(currentWeekKey())
        scheduleMidnightTick()
    }

    deinit { midnightCancellable?.cancel() }

    func toggle(_ habitId: String) {
        if completed.contains(habitId) { completed.remove(habitId) } else { completed.insert(habitId) }
        persistTodayState()
    }

    private func persistTodayState() {
        let d = UserDefaults.standard
        d.set(today, forKey: Keys.today)
        d.set(Array(completed), forKey: Keys.completed)
    }

    func rollDailyIntoWeekIfNeeded(now: Date = Date()) {
        let d = UserDefaults.standard
        let storedDayStr = d.string(forKey: Keys.today)
        let storedDay = Self.parseLocalDate(storedDayStr)
        let todayStr = Self.localDateString(now)

        // First run or missing date → just seed today + empty completed
        guard let stored = storedDay else {
            d.set(todayStr, forKey: Keys.today)
            if d.array(forKey: Keys.completed) == nil { d.set([], forKey: Keys.completed) }
            return
        }

        let todayDate = Self.parseLocalDate(todayStr)!
        if stored != todayDate {
            // 🔹 Snapshot previous day's completions for rolling stats (Stats/Leaderboard/Weekly)
            let prevDayKey = statsDayKey(for: stored) // e.g. "20251130"
            d.set(Array(completed), forKey: "daily_completed_\(prevDayKey)")

            // Existing week-bucket rollup
            let prevWeek = isoWeekKey(from: stored)
            let baseCore = d.integer(forKey: Keys.coreTotal(prevWeek))
            let dayCore = completed.count
            let newTotal = min(max(baseCore + dayCore, 0), 56)
            d.set(newTotal, forKey: Keys.coreTotal(prevWeek))

            // Reset to new day
            d.set(todayStr, forKey: Keys.today)
            d.set([], forKey: Keys.completed)
            self.today = todayStr
            self.completed = []
        }
    }

    func rolloverWeekIfNeeded(_ currentWeek: String) {
        let d = UserDefaults.standard
        let storedWeek = d.string(forKey: Keys.currentWeek)
        if storedWeek != currentWeek {
            d.set(currentWeek, forKey: Keys.currentWeek)
            d.set(0, forKey: Keys.coreTotal(currentWeek))
            d.set(0, forKey: Keys.optTotal(currentWeek))
            d.set("", forKey: Keys.oneThing(currentWeek))
            d.set("", forKey: Keys.journal(currentWeek))
            d.set("", forKey: Keys.wins(currentWeek))
        }
    }

    func ensureCarryoverSeeded(current: String, previous: String) {
        let d = UserDefaults.standard
        let curText = d.string(forKey: Keys.carryText(current)) ?? ""
        if curText.isEmpty {
            let prev = d.string(forKey: Keys.oneThing(previous)) ?? ""
            if !prev.isEmpty {
                d.set(prev, forKey: Keys.carryText(current))
                d.set(false, forKey: Keys.carryDone(current))
            }
        }
    }

    // Persist profile + mark registered
    func saveProfile(
        name: String,
        email: String,
        photoPath: String?,
        isRegistered: Bool? = nil
    ) {
        let d = UserDefaults.standard
        let newEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        let wasRegistered = self.profile.isRegistered

        var p = self.profile
        p.name = name
        p.email = newEmail
        p.photoPath = photoPath
        if let isRegistered { p.isRegistered = isRegistered }
        self.profile = p

        d.set(name, forKey: Keys.profileName)
        d.set(newEmail, forKey: Keys.profileEmail)
        if let path = photoPath {
            d.set(path, forKey: Keys.profilePhoto)
        } else {
            d.removeObject(forKey: Keys.profilePhoto)
        }

        if let path = photoPath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            AvatarVault.save(data)
        } else {
            AvatarVault.clear()
        }

        // If caller indicates registration, persist it.
        if p.isRegistered {
            d.set(true, forKey: Keys.profileRegisteredV2)
            d.set("true", forKey: Keys.profileRegisteredLegacy)
        }

        // ✅ Trigger brand splash ONLY on the transition false -> true (registration just happened)
        if !wasRegistered && p.isRegistered {
            brandSplashTrigger.send(())
        }
    }

    private func scheduleMidnightTick() {
        midnightCancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.rollDailyIntoWeekIfNeeded()
                self.rolloverWeekIfNeeded(currentWeekKey())
            }
    }

    static func localDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = .init(identifier: .gregorian)
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func parseLocalDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = DateFormatter()
        f.calendar = .init(identifier: .gregorian)
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}

// MARK: - Week helpers
func currentWeekKey(from date: Date = Date()) -> String {
    let cal = Calendar(identifier: .iso8601)
    let week = cal.component(.weekOfYear, from: date)
    let year = cal.component(.yearForWeekOfYear, from: date)
    return String(format: "%04d-W%02d", year, week)
}
func prevWeekKey(from date: Date = Date()) -> String {
    let prior = Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date
    return currentWeekKey(from: prior)
}
func isoWeekKey(from date: Date) -> String { currentWeekKey(from: date) }

// MARK: - Daily store
final class DailyStore: ObservableObject {
    static let shared = DailyStore()
    @Published var checks: [Bool] = Array(repeating: false, count: 8)
    @Published var lastActiveDate: Date = Date()

    private let checksKey = "daily.checks.v1"
    private let dateKey   = "daily.lastActiveDate.v1"
    private var cancellables = Set<AnyCancellable>()

    private init() {
        load()
        $checks.sink { [weak self] _ in self?.save() }.store(in: &cancellables)
        $lastActiveDate.sink { [weak self] _ in self?.save() }.store(in: &cancellables)
    }

    func toggle(_ index: Int) {
        guard checks.indices.contains(index) else { return }
        checks[index].toggle()
        lastActiveDate = Date()
    }

    func rolloverIfNeeded(now: Date = Date()) {
        if !Calendar.current.isDate(now, inSameDayAs: lastActiveDate) {
            checks = Array(repeating: false, count: 8)
            lastActiveDate = now
        }
    }

    private func load() {
        let ud = UserDefaults.standard
        if let data = ud.data(forKey: checksKey),
           let arr = try? JSONDecoder().decode([Bool].self, from: data),
           arr.count == 8 {
            self.checks = arr
        }
        if let d = ud.object(forKey: dateKey) as? Date {
            self.lastActiveDate = d
        }
    }

    private func save() {
        let ud = UserDefaults.standard
        if let data = try? JSONEncoder().encode(checks) {
            ud.set(data, forKey: checksKey)
        }
        ud.set(lastActiveDate, forKey: dateKey)
    }
}
