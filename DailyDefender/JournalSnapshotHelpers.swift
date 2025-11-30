import Foundation

/// CSS/DVS are immutable snapshots: open read-only.
func isSnapshotEntry(_ e: JournalEntryIOS) -> Bool {
    let t = e.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return t.hasPrefix("css:") || t.hasPrefix("dvs:") || t.hasPrefix("wcs:")
}

