import SwiftUI

struct PaywallCardView: View {
    var title: String = "Pro Feature"

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textPrimary)

            Image("AppShieldSquare")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

            Text("Build Your Character and Lead\nwith Power & Love in\nDefense of Meaning and Freedom")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(4)

            Link(destination: URL(string: "https://10mm.org/membership")!) {
                Text("Join Defender Boards")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(AppTheme.appGreen)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.navy900.ignoresSafeArea())
    }
}
