import Foundation

// MARK: - CTW meta (parity with Android)
enum Ctw {
    static let title = "Cage The Wolf"

    // 6 sections total; first 5 have inputs, #6 is informational
    static let sectionCount = 6
    static let inputCount = 5

    static let titles: [String] = [
        "Set rules and claim a higher self",
        "Describing the Wolf",
        "Experience the conflict",
        "Caging the Wolf with refutation",
        "Connect with yourself",
        "Repeat sequences as needed"
    ]

    // Short prompts that appear under each header (first 5 sections)
    static let prompts: [String] = [
        "Define your non-negotiables and the identity you are choosing.",
        "What is the Wolf saying/tempting? Capture the exact script.",
        "Notice sensations, urges, thoughts. Where is the pull?",
        "Refute the Wolf’s claims. Counter with truth, facts, values.",
        "Return to breath, posture, prayer, or your chosen reconnect ritual.",
        // Section 6 is informational; no input
        ""
    ]
}

// MARK: - Build full CTW body from 6 sections (1–5 inputs, 6 informational/empty)
func buildCtwBody(_ sections: [String]) -> String {
    // Ensure exactly 6 blocks; pad if needed
    let safe = sections.count >= Ctw.sectionCount
        ? Array(sections.prefix(Ctw.sectionCount))
        : sections + Array(repeating: "", count: Ctw.sectionCount - sections.count)

    var blocks: [String] = []
    for i in 0..<Ctw.sectionCount {
        let header = "\(i + 1) — \(Ctw.titles[i])"
        let body = safe[i].trimmingCharacters(in: .whitespacesAndNewlines)
        let block = body.isEmpty ? header : "\(header)\n\(body)"
        blocks.append(block)
    }
    return blocks.joined(separator: "\n\n")
}

// MARK: - Parse CTW body → 6 sections (returns only bodies; robust to duplicated header lines)
func parseCtwBody(_ content: String) -> [String] {
    func headerLine(_ n: Int, _ title: String) -> String {
        let esc = NSRegularExpression.escapedPattern(for: title)
        return #"(?m)^\s*\#(n)\s*[—-]\s*\#(esc)\s*$"#
    }

    let headers = (0..<Ctw.sectionCount).compactMap { i -> NSRegularExpression? in
        try? NSRegularExpression(
            pattern: headerLine(i + 1, Ctw.titles[i]),
            options: [.caseInsensitive, .anchorsMatchLines]
        )
    }

    let ns = content as NSString
    var headerRanges: [NSRange?] = Array(repeating: nil, count: Ctw.sectionCount)
    for i in 0..<Ctw.sectionCount {
        headerRanges[i] = headers[i].firstMatch(in: content, options: [], range: NSRange(location: 0, length: ns.length))?.range
    }

    // Known header display lines (to strip if they accidentally appear at the top of an answer)
    let headerLines: Set<String> = {
        var s = Set<String>()
        for (i, t) in Ctw.titles.enumerated() {
            s.insert("\(i+1) — \(t)".lowercased())
            s.insert("\(i+1) - \(t)".lowercased())
        }
        return s
    }()

    func sliceBody(after headerRange: NSRange, nextStart: Int?) -> String {
        // Start right after the header match
        var bodyStart = headerRange.location + headerRange.length

        // If the next char(s) are newline(s), skip them
        while bodyStart < ns.length {
            let ch = ns.substring(with: NSRange(location: bodyStart, length: 1))
            if ch == "\n" || ch == "\r" { bodyStart += 1 } else { break }
        }

        let bodyEnd = nextStart ?? ns.length
        let raw = ns.substring(with: NSRange(location: bodyStart, length: max(0, bodyEnd - bodyStart)))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip a duplicated header line if present at the very top
        if let firstLine = raw.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first {
            let fl = firstLine.trimmingCharacters(in: .whitespaces).lowercased()
            if headerLines.contains(fl) {
                return raw.drop(while: { $0 != "\n" }).dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return raw
    }

    var out = Array(repeating: "", count: Ctw.sectionCount)
    for i in 0..<Ctw.sectionCount {
        guard let hr = headerRanges[i] ?? nil else { continue }
        let next = (i+1..<Ctw.sectionCount).compactMap { headerRanges[$0]?.location }.min()
        out[i] = sliceBody(after: hr, nextStart: next)
    }

    // Always return 6; editor will use the first 5 inputs
    return out.count == Ctw.sectionCount ? out : Array(out.prefix(Ctw.sectionCount)) + Array(repeating: "", count: max(0, Ctw.sectionCount - out.count))
}

// MARK: - Detector to route CTW from Library
func looksLikeCageTheWolfLocal(_ content: String) -> Bool {
    // Only match the exact first header line so regular numbered lists don't trigger it
    let firstHeader = #"(?m)^\s*1\s*[—-]\s*Set rules and claim a higher self\s*$"#
    return content.range(of: firstHeader, options: .regularExpression) != nil
}

