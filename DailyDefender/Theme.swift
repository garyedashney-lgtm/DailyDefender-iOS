import SwiftUI

enum AppTheme {
    static let appGreen = Color(hex: 0x22C55E)
    static let navy900  = Color(hex: 0x0D1B2A)
    static let surface  = Color(hex: 0x1B263B)

    // ✅ Exact UIKit-backed surface color so multiple views render identical shades
    static let surfaceUI = Color(UIColor(
        red: 27/255.0,
        green: 38/255.0,
        blue: 59/255.0,
        alpha: 1.0
    ))
    // A card/background color slightly lighter than `surface`
    static let surfaceCard = Color(UIColor(
        red: 34/255.0,  // tweak to taste
        green: 47/255.0,
        blue: 69/255.0,
        alpha: 1.0
    ))
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let divider       = Color.white.opacity(0.12)
}
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b).opacity(alpha)
    }
}
