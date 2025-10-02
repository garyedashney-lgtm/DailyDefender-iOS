import SwiftUI

// Android parity colors
// - Background (Navy900)  : #19293E
// - Surface   (NavySurface): #20344D
// - Accent    (AppGreen)   : #4CAF50
// - Text (onBackground/onSurface): #FFFFFF

enum AppTheme {
    // Accent
    static let appGreen = Color(hex: 0x4CAF50)

    // Backgrounds
    static let navy900  = Color(hex: 0x19293E) // page background
    static let surface  = Color(hex: 0x20344D) // card/row surface

    // UIKit-backed variants (ensure identical rendering across views)
    static let surfaceUI = Color(UIColor(
        red: 0x20/255.0, // 32
        green: 0x34/255.0, // 52
        blue: 0x4D/255.0, // 77
        alpha: 1.0
    ))
    // For strict parity, make surfaceCard the same as surface
    static let surfaceCard = Color(UIColor(
        red: 0x20/255.0,
        green: 0x34/255.0,
        blue: 0x4D/255.0,
        alpha: 1.0
    ))

    // Text
    static let textPrimary   = Color.white            // matches Android onSurface/onBackground
    static let textSecondary = Color.white            // strict parity: Android uses white (no dim)

    // Misc
    static let divider = Color.white.opacity(0.12)
}

// Hex initializer
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b).opacity(alpha)
    }
}
