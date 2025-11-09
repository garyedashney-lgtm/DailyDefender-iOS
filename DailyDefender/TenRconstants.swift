import Foundation

/// iOS counterpart to Android `TenR` object.
/// - We render **10** headers (1…10).
/// - Inputs exist for **1…9**; step 10 is informational (no text field).
enum TenR {
    static let titles: [String] = [
        "Recognize triggering negative emotions.",                                   // 1
        "Realize INS (ego: see below) is trained by experience ",                    // 2
        "Reconnect with YS (Younger Self)",                                          // 3
        "Reveal facts, feelings & beliefs of old YS story",                          // 4
        "Reassure YS with commitment & competence",                                  // 5
        "Release old INS concepts (messages, rules, beliefs)",                       // 6
        "Reparent with adult wisdom & form an adaption plan",                        // 7
        "Reboot when triggered using new thoughts, feelings & behaviours to update your INS O/S (operating system)", // 8
        "Reintegrate Better Being into Body Mind",                                   // 9
        "Repeat 6-7-8-9 until trigger fully neutralized"                             // 10 (info-only)
    ]

    /// Short, action-focused prompts matching Android.
    static let prompts: [String] = [
        "If no real threat, ask: why do I feel this way?.",
        "INS/EGO (Integrated Nervous System): denies, distorts, represses, inner and/or outer reality to lessen anxiety & depression. Ask: Where do I feel this in my body & when else have I felt like this?",
        "Body trace to earlier (then earliest) recollected experience with similar feelings.",
        "Ask: What would I have to believe to make these facts & feelings true?",
        "Brag about your ability; Place YS under your protection",
        "Accept expedient but flawed nature of the old operating system",
        "Fearlessly propose a new model of the world idea for future coping",
        "Act differently in response to being triggered to install improved nervous system concepts",
        "Integrate YS into heart and soul with competence and reassurance.",
        "Triggers remain until updated"
    ]

    /// Total headers we print (1…10).
    static let sectionCount: Int = 10

    /// Number of **inputs** we collect (1…9). Step 10 is informational only.
    static let inputCount: Int = 9
}
