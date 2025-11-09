import Foundation

// MARK: - SCW constants (iOS mirror of Android Scw)
enum Scw {
    static let title = "Self Care Writing"

    static let titles: [String] = [
        "What, Why, How",
        "Rewrite",
        "Insight",
        "Revision",
        "Decide",
        "Congratulations"
    ]

    static let prompts: [String] = [
        // 1
        "Write freely by dumping raw unfiltered facts and feelings about the event; include what and why it happened to the best of your understanding.",
        // 2
        "Clarify details while connecting missed effects, patterns, even possible lessons.",
        // 3
        "Write about how this experience may have made you stronger. If unable, imagine how it might in the future if you were to consider that possibility.",
        // 4
        "Write a new meaningful story which includes your nobility in transcending the event.",
        // 5
        "Contrast “the why” and lessons learned with the precious power and wisdom gained from the event, perhaps emerging ennobled enough to share with a trusted person. Alternatively, consider using a ritual such as burning the document in a fireplace or placing it in an envelope to mail yourself to let go of its power over your history.",
        // 6 (informational only)
        "You have made your suffering pay. Now let it go… even if just a bit."
    ]

    /// Number of sections with input fields (1..5).
    static let inputCount: Int = 5

    /// Total section count (1..6).
    static let sectionCount: Int = titles.count
}

// MARK: - Build SCW body (same spacing as Android)
func buildScwBody(_ sections: [String]) -> String {
    var lines: [String] = []

    for i in 0..<Scw.sectionCount {
        let step = i + 1
        let title = Scw.titles[i]

        if i > 0 { lines.append("") }                  // blank line before each section (except first)
        lines.append("\(step) — \(title)")             // header line

        if i < Scw.inputCount {
            // keep a placeholder line even if blank (prevents collapse in shares/exports)
            let ans = (i < sections.count ? sections[i] : "").trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append(ans.isEmpty ? " " : ans)
        } else {
            // section 6: informational text persisted read-only
            lines.append(Scw.prompts[5])
        }

        if i < Scw.sectionCount - 1 { lines.append("") } // blank line after (except last)
    }

    // Trim any trailing empties
    while lines.last == "" { _ = lines.popLast() }
    return lines.joined(separator: "\n")
}

// MARK: - Parse SCW body → 6 sections (strict, titles never leak into answers)
func parseScwBody(_ body: String?) -> [String] {
    guard let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return Array(repeating: "", count: Scw.sectionCount)
    }

    // Build strict, per-title regexes: ^\s*N\s*[—–-]\s*<title>\s*$
    // (hyphen, en dash, em dash; anchored per line)
    func headerPattern(step: Int, title: String) -> String {
        let esc = NSRegularExpression.escapedPattern(for: title)
        return #"(?m)^\s*\#(step)\s*[—–-]\s*\#(esc)\s*$"#
    }

    let headerRegexes: [NSRegularExpression] = Scw.titles.enumerated().map { idx, title in
        let pat = headerPattern(step: idx + 1, title: title)
        return try! NSRegularExpression(pattern: pat, options: [.caseInsensitive, .anchorsMatchLines])
    }

    let ns = body as NSString

    // Locate each header's starting location
    var headerStarts: [Int?] = Array(repeating: nil, count: Scw.sectionCount)
    for i in 0..<Scw.sectionCount {
        if let m = headerRegexes[i].firstMatch(in: body, options: [], range: NSRange(location: 0, length: ns.length)) {
            headerStarts[i] = m.range.location
        }
    }

    // Slice from the FIRST newline AFTER header i to just before the next header (or EOF)
    func sliceAnswer(from headerStart: Int, to nextHeaderStart: Int?) -> String {
        // find first newline after header line
        let nl = ns.range(of: "\n", options: [], range: NSRange(location: headerStart, length: ns.length - headerStart))
        let bodyStart = (nl.location != NSNotFound) ? nl.location + 1 : ns.length
        let bodyEnd = nextHeaderStart ?? ns.length
        let length = max(0, bodyEnd - bodyStart)
        let raw = ns.substring(with: NSRange(location: bodyStart, length: length))

        // Trim outer whitespace/newlines, but keep inner content intact
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extra safety: if a header line somehow slipped into the slice, strip it
        // (handles malformed bodies with double headers).
        if let firstLine = trimmed.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first {
            // Match N — Title on the first line
            let candidates = [
                "\(firstLine)".trimmingCharacters(in: .whitespaces),
                "\(firstLine)".replacingOccurrences(of: "–", with: "—")
            ]
            // Build all header strings to compare
            let headerStrings: [String] = (1...Scw.sectionCount).map { n in "\(n) — \(Scw.titles[n-1])" }

            if candidates.contains(where: { cand in headerStrings.contains { $0.caseInsensitiveCompare(cand) == .orderedSame } }) {
                // drop the first line and return the remainder
                let parts = trimmed.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                trimmed = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
            }
        }

        return trimmed
    }

    var sections = Array(repeating: "", count: Scw.sectionCount)
    for i in 0..<Scw.sectionCount {
        guard let start = headerStarts[i] else { continue }
        let next = (i+1..<Scw.sectionCount).compactMap { headerStarts[$0] }.min()
        sections[i] = sliceAnswer(from: start, to: next)
    }

    // Guarantee fixed length
    if sections.count > Scw.sectionCount { sections = Array(sections.prefix(Scw.sectionCount)) }
    else if sections.count < Scw.sectionCount { sections += Array(repeating: "", count: Scw.sectionCount - sections.count) }

    return sections
}

// MARK: - Strong content-based identifier (rename to avoid collisions with routing helper)
func looksLikeSelfCareWritingStrict(_ content: String?) -> Bool {
    let c = content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if c.isEmpty { return false }

    // Accept any dash variant; require at least one numbered header that matches a known SCW title
    let numbered = try! NSRegularExpression(pattern: #"(?m)^\s*([1-6])\s*[—–-]\s*(.+?)\s*$"#,
                                            options: [.anchorsMatchLines])
    let ns = c as NSString
    let matches = numbered.matches(in: c, range: NSRange(location: 0, length: ns.length))

    for m in matches {
        guard m.numberOfRanges >= 3 else { continue }
        let title = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
        if Scw.titles.contains(where: { $0.caseInsensitiveCompare(title) == .orderedSame }) {
            return true
        }
    }
    return false
}
