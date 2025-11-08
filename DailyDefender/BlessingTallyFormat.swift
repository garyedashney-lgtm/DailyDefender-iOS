import Foundation

/// iOS parity for Android BlessingTally.kt
enum BlessingTally {
    static let title = "3 Blessings"
    static let sections: [String] = [
        "1 — What are three things from today that went well.",
        "2 — Why are these important to me?",
        "3 — How can I get more of them?"
    ]
}

/// Build the saved body: strict header + answer, separated by blank lines.
func buildBlessingTallyBody(_ responses: [String]) -> String {
    let safe = responses.count >= 3 ? Array(responses.prefix(3))
                                    : responses + Array(repeating: "", count: 3 - responses.count)
    return zip(BlessingTally.sections, safe).map { header, body in
        "\(header)\n\(body.trimmingCharacters(in: .whitespacesAndNewlines))".trimmingCharacters(in: .whitespacesAndNewlines)
    }
    .joined(separator: "\n\n")
}

/// Parse the body back into 3 answers. Allows em-dash or hyphen and optional trailing punctuation.
func parseBlessingTallyBody(_ content: String) -> [String] {
    // Exact texts from sections, but regex allows — or - and optional . / ?
    let q1 = #"1\s*[—-]\s*What are three things from today that went well\.?"#
    let q2 = #"2\s*[—-]\s*Why are these important to me\??"#
    let q3 = #"3\s*[—-]\s*How can I get more of them\??"#

    func findStart(_ regex: String) -> Int? {
        let r = try! NSRegularExpression(pattern: "(?m)^\\s*(\(regex))\\s*$", options: [])
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        return r.firstMatch(in: content, options: [], range: range).map { $0.range.location }
    }

    let h1 = findStart(q1)
    let h2 = findStart(q2)
    let h3 = findStart(q3)

    func sliceAnswer(from startIdx: Int?, to nextIdx: Int?) -> String {
        guard let start = startIdx else { return "" }
        // first newline after the header line
        let scalarView = content
        let afterHeaderIdx = scalarView[scalarView.index(scalarView.startIndex, offsetBy: start)...]
            .firstIndex(of: "\n")?.samePosition(in: content)
        let bodyStart = afterHeaderIdx.map { content.index(after: $0) } ?? content.endIndex
        let bodyEnd = nextIdx.map { content.index(content.startIndex, offsetBy: $0) } ?? content.endIndex
        let raw = String(content[bodyStart..<bodyEnd]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Clean up: if the first line is itself a duplicated header, drop it.
        let firstLine = raw.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let dupHeaders = [
            "1 — What are three things from today that went well.",
            "1 - What are three things from today that went well.",
            "2 — Why are these important to me?",
            "2 - Why are these important to me?",
            "3 — How can I get more of them?",
            "3 - How can I get more of them?"
        ]
        if dupHeaders.contains(where: { $0.caseInsensitiveCompare(firstLine) == .orderedSame }) {
            return raw.drop(while: { $0 != "\n" }).dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
    }

    // Determine slice ranges in order
    let a1 = sliceAnswer(from: h1, to: h2 ?? h3)
    let a2 = sliceAnswer(from: h2, to: h3)
    let a3 = sliceAnswer(from: h3, to: nil)
    return [a1, a2, a3]
}

/// Heuristic detector used by the Library classifier.
func looksLikeBlessingTally(_ content: String) -> Bool {
    let pattern = #"(?m)^\s*1\s*[—-]\s*What are three things from today that went well\.?"#
    return content.range(of: pattern, options: .regularExpression) != nil
}

