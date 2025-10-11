import Foundation
import Combine

/// Temporary journal store with simple JSON-on-disk persistence.
/// Lives in Documents/journal_entries.json so entries survive app relaunch.
final class JournalMemoryStore: ObservableObject {
    static let shared = JournalMemoryStore()

    @Published private(set) var entries: [JournalEntryIOS] = []

    private let fileURL: URL

    private init() {
        // File location
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent("journal_entries.json")

        // Load existing entries from disk (if present)
        self.entries = Self.load(from: fileURL)
    }

    // MARK: - Public API

    /// Add a Free Flow entry (newest first)
    func addFreeFlow(title: String, body: String, createdAt: Date) {
        let nowMs = Self.nowMs()
        let e = JournalEntryIOS(
            id: nowMs, // simple unique id
            dateMillis: Int64(createdAt.timeIntervalSince1970 * 1000.0),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: body,
            updatedAt: nowMs
        )
        entries.insert(e, at: 0)
        save()
    }

    /// Update an existing entry in place by id
    func updateEntry(id: Int64, title: String, body: String, createdAt: Date) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        let nowMs = Self.nowMs()
        entries[idx] = JournalEntryIOS(
            id: id,
            dateMillis: Int64(createdAt.timeIntervalSince1970 * 1000.0),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: body,
            updatedAt: nowMs
        )
        entries.sort { $0.dateMillis > $1.dateMillis }
        save()
    }

    /// Bulk delete by ids
    func delete(ids: [Int64]) {
        let set = Set(ids)
        entries.removeAll { set.contains($0.id) }
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let payload = entries.map { PersistedJournalEntry(from: $0) }
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("JournalMemoryStore save error:", error)
            #endif
        }
    }

    private static func load(from url: URL) -> [JournalEntryIOS] {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([PersistedJournalEntry].self, from: data)
            let mapped = decoded.map { $0.asModel() }
            return mapped.sorted { $0.dateMillis > $1.dateMillis }
        } catch {
            // First run or decode error → start fresh
            #if DEBUG
            if (error as NSError).code != NSFileReadNoSuchFileError {
                print("JournalMemoryStore load error:", error)
            }
            #endif
            return []
        }
    }

    private static func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000.0)
    }
}

/// Codable representation for persistence, to avoid touching JournalEntryIOS conformance.
private struct PersistedJournalEntry: Codable {
    let id: Int64
    let dateMillis: Int64
    let title: String
    let content: String
    let updatedAt: Int64

    init(from model: JournalEntryIOS) {
        self.id = model.id
        self.dateMillis = model.dateMillis
        self.title = model.title
        self.content = model.content
        self.updatedAt = model.updatedAt
    }

    func asModel() -> JournalEntryIOS {
        JournalEntryIOS(
            id: id,
            dateMillis: dateMillis,
            title: title,
            content: content,
            updatedAt: updatedAt
        )
    }
}
