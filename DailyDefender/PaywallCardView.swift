import SwiftUI

struct PaywallCardView: View {
    var title: String = "Pro Feature"

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)

            // App logo; replace "AppIcon" if you have a specific shield asset
            Image("AppShieldSquare")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .clipShape(Circle())

            Text("Build Your Character and Lead\nwith Power & Love in\nDefense of Meaning and Freedom")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Link(destination: URL(string: "https://10mm.org/membership")!) {
                Text("Join Defender Boards")
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

