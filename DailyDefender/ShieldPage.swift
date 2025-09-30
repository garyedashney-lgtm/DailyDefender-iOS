import SwiftUI

struct ShieldPage: View {
    @Environment(\.dismiss) private var dismiss
    let imageName: String
    
    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()
            
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)
                    
                    // Shield full width (rotates, scrollable)
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width)
                        .padding(.horizontal, 12)
                    
                    // Back button
                    Button(action: { dismiss() }) {
                        Text("Back")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(AppTheme.appGreen)
                            .cornerRadius(12)
                    }
                    .padding(.top, 16)
                    
                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .interactiveDismissDisabled() // force using the Back button
    }
}
