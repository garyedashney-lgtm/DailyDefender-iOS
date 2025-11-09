import Foundation

/// Create a human-readable Q→A block for storage in a journal entry body.
/// - Note: We render 10 headers (1…10). Inputs exist for 1…9; step 10 is informational.
func buildTenRBody(_ answers: [String]) -> String {
    var lines: [String] = []
    for i in 0..<TenR.sectionCount {
        let step = i + 1
        let title = TenR.titles[i]
        // For steps 1…9, pull user text; step 10 has no input
        let ans = (i < TenR.inputCount ? (answers.indices.contains(i) ? answers[i] : "") : "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Header
        lines.append("\(step) — \(title)")
        // Keep a placeholder line even if blank (helps older parsers and consistent layout)
        lines.append(ans.isEmpty ? " " : ans)

        // Blank line between sections (except after the last)
        if i < TenR.sectionCount - 1 { lines.append("") }
    }
    // Trim trailing newlines safely
    while lines.last == "" { _ = lines.popLast() }
    return lines.joined(separator: "\n")
}

/// Parse a stored TenR body back into 10 section payloads (indices 0…8 carry answers; 9 is informational).
/// - Returns: Array of length `TenR.sectionCount` (10). Editor will use only the first 9.
func parseTenRBody(_ body: String?) -> [String] {
    guard let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return Array(repeating: "", count: TenR.sectionCount)
    }

    // Build strict, per-header regexes so numbered lists inside answers won’t trigger.
    func headerPattern(step: Int, title: String) -> String {
        let esc = NSRegularExpression.escapedPattern(for: title)
        // exactly: ^\s*<n>\s*[—-]\s*<title>\s*$
        return #"(?m)^\s*\#(step)\s*[—-]\s*\#(esc)\s*$"#
    }

    let headerRegexes: [NSRegularExpression] = TenR.titles.enumerated().map { idx, t in
        let pat = headerPattern(step: idx + 1, title: t)
        // anchorsMatchLines so ^ and $ operate per-line
        return try! NSRegularExpression(pattern: pat, options: [.caseInsensitive, .anchorsMatchLines])
    }

    let ns = body as NSString
    // Find the start location of every header (or nil if not present)
    var headerStarts: [Int?] = Array(repeating: nil, count: TenR.sectionCount)
    for i in 0..<TenR.sectionCount {
        if let m = headerRegexes[i].firstMatch(in: body, options: [], range: NSRange(location: 0, length: ns.length)) {
            headerStarts[i] = m.range.location
        }
    }

    // Slice from just after header line i until next header (or EOF)
    func sliceAnswer(from headerStart: Int, to nextHeaderStart: Int?) -> String {
        // first newline after the header
        let nl = ns.range(of: "\n", options: [], range: NSRange(location: headerStart, length: ns.length - headerStart))
        let bodyStart = (nl.location != NSNotFound) ? nl.location + 1 : ns.length
        let bodyEnd = nextHeaderStart ?? ns.length
        let sliceLen = max(0, bodyEnd - bodyStart)
        let raw = ns.substring(with: NSRange(location: bodyStart, length: sliceLen))
        // Trim but keep internal newlines intact
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Normalized compare that ignores extra whitespace and trailing punctuation.
    func norm(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let noPunct = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ".?"))
        let collapsed = noPunct.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return collapsed.lowercased()
    }

    // Remove a duplicated header line at the top of an answer, if present.
    func stripDuplicateHeader(from text: String, step: Int) -> String {
        guard !text.isEmpty else { return "" }
        let expectedTitle = TenR.titles[step - 1].trimmingCharacters(in: .whitespacesAndNewlines)

        let firstLine = text.split(separator: "\n", omittingEmptySubsequences: false)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let h1 = "\(step) — \(expectedTitle)"
        let h2 = "\(step) - \(expectedTitle)"

        if norm(firstLine) == norm(h1) || norm(firstLine) == norm(h2) {
            if let nlRange = text.range(of: "\n") {
                let remainder = String(text[nlRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return remainder
            } else {
                return ""
            }
        }
        return text
    }

    var out = Array(repeating: "", count: TenR.sectionCount)
    for i in 0..<TenR.sectionCount {
        guard let start = headerStarts[i] else { continue }
        // next existing header (the minimal start > current)
        let next = (i+1..<TenR.sectionCount).compactMap { headerStarts[$0] }.min()
        let sliced = sliceAnswer(from: start, to: next)
        out[i] = stripDuplicateHeader(from: sliced, step: i + 1)
    }

    // Guarantee fixed length
    if out.count > TenR.sectionCount { out = Array(out.prefix(TenR.sectionCount)) }
    else if out.count < TenR.sectionCount { out += Array(repeating: "", count: TenR.sectionCount - out.count) }

    return out
}
