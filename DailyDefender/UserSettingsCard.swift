import SwiftUI

/// Shared settings backing store (UserDefaults)
struct CelebrationSettings {
    private static let keyConfetti = "enable_confetti"
    private static let keyAudio    = "enable_audio"
    private static let keyVideo    = "enable_video"

    static var isConfettiEnabled: Bool {
        get { UserDefaults.standard.object(forKey: keyConfetti) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: keyConfetti) }
    }

    static var isAudioEnabled: Bool {
        get { UserDefaults.standard.object(forKey: keyAudio) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: keyAudio) }
    }

    static var isVideoEnabled: Bool {
        get { UserDefaults.standard.object(forKey: keyVideo) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: keyVideo) }
    }
}

struct UserSettingsCard: View {
    @State private var expanded: Bool = false

    @State private var confettiOn: Bool = CelebrationSettings.isConfettiEnabled
    @State private var audioOn: Bool    = CelebrationSettings.isAudioEnabled
    @State private var videoOn: Bool    = CelebrationSettings.isVideoEnabled

    var body: some View {
        VStack(spacing: 10) {
            // Header row (same “card height” feel as other More cards)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.appGreen.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Text("⚙️")
                        .font(.system(size: 20))
                }

                Text("User Settings")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expanded.toggle()
                }
            }

            if expanded {
                // Subtext
                Text("Tune your Daily rewards and celebrations.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                Divider()
                    .overlay(AppTheme.divider)
                    .padding(.vertical, 4)

                // Toggles block
                VStack(spacing: 10) {
                    settingsRow(
                        title: "Confetti at 2-of-4",
                        subtitle: "Show confetti when you hit 2 pillars.",
                        isOn: $confettiOn
                    ) { newValue in
                        CelebrationSettings.isConfettiEnabled = newValue
                    }

                    settingsRow(
                        title: "“You are an amazing guy” audio",
                        subtitle: "Play the audio when you hit 2 pillars.",
                        isOn: $audioOn
                    ) { newValue in
                        CelebrationSettings.isAudioEnabled = newValue
                    }

                    settingsRow(
                        title: "Victory video at 4-of-4",
                        subtitle: "Show the video when you hit all 4 pillars.",
                        isOn: $videoOn
                    ) { newValue in
                        CelebrationSettings.isVideoEnabled = newValue
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.surfaceUI)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
        )
    }

    // MARK: - One settings row

    private func settingsRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newVal in
                    isOn.wrappedValue = newVal
                    onChange(newVal)
                }
            ))
            .labelsHidden()
            .tint(AppTheme.appGreen)
        }
    }
}
