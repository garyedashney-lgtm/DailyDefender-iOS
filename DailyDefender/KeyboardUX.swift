import SwiftUI
import UIKit

/// One-liner to dismiss the keyboard from anywhere
@inline(__always)
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
}

/// ViewModifier that ONLY adds "tap background to dismiss" in a way that
/// does not consume touches or block focusing inputs.
private struct TapToDismissKeyboard: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Use simultaneousGesture so taps still flow to child views (e.g., TextField)
            .simultaneousGesture(
                TapGesture().onEnded { dismissKeyboard() }
            )
    }
}

/// Sugar: `.withKeyboardDismiss()` anywhere you have inputs.
/// Safe to stack—no duplicate toolbars, no focus stealing.
extension View {
    func withKeyboardDismiss() -> some View {
        self.modifier(TapToDismissKeyboard())
    }
}
