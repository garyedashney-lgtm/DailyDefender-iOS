import SwiftUI
import UIKit

struct CurrentStateView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss   // ← needed to pop back to Goals

    @State private var showShield = false
    @State private var showProfileEdit = false
    @State private var showSavedAlert = false

    // Reuse the same page shield as Goals for brand consistency
    private let shieldAsset = "identityncrisis"

    // --- Per-keystroke persistence (device-local, fast) ---
    @AppStorage("css_physiology_text")  private var physiologyText: String  = ""
    @AppStorage("css_piety_text")       private var pietyText: String       = ""
    @AppStorage("css_people_text")      private var peopleText: String      = ""
    @AppStorage("css_production_text")  private var productionText: String  = ""

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // ===== Intro / Intent =====
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Write down the full truth:")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("""
                        In each quadrant, write down the full as-is, no-BS, truth of where you are at right now.
                        """)
                        .font(.system(size: 15, weight: .regular))
                        .italic()
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                    }
                    .padding(.bottom, 8)

                    // ===== Physiology =====
                    CurrentStateSectionHeader(label: "Physiology", emoji: "🏋")
                    Text("The body is the universal address of your existence: Breath, walk, lift, bike, hike, stretch, sleep, fast, eat clean, supplement, hydrate, etc.")
                        .font(.system(size: 13, weight: .regular))
                        .italic()
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                        .padding(.leading, 4)
                        .padding(.bottom, 6)

                    CurrentStatePillarEditor(
                        text: Binding(
                            get: { physiologyText },
                            set: { physiologyText = $0 }
                        ),
                        placeholder: "Be specific. Facts over feelings."
                    )

                    // ===== Piety =====
                    CurrentStateSectionHeader(label: "Piety", emoji: "🙏")
                    Text("Using mystery & awe as the spirit speaks for the soul: 3 blessings, waking up, end-of-day prayer, body scan & resets, the watcher, etc.")
                        .font(.system(size: 13, weight: .regular))
                        .italic()
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                        .padding(.leading, 4)
                        .padding(.bottom, 6)

                    CurrentStatePillarEditor(
                        text: Binding(
                            get: { pietyText },
                            set: { pietyText = $0 }
                        ),
                        placeholder: "Be specific. Facts over feelings."
                    )

                    // ===== People =====
                    CurrentStateSectionHeader(label: "People", emoji: "👥")
                    Text("Team Human: herd animals who exist in each other: Light people up, reverse the flow, problem solve & collaborate in Defense of Meaning and Freedom, etc.")
                        .font(.system(size: 13, weight: .regular))
                        .italic()
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                        .padding(.leading, 4)
                        .padding(.bottom, 6)

                    CurrentStatePillarEditor(
                        text: Binding(
                            get: { peopleText },
                            set: { peopleText = $0 }
                        ),
                        placeholder: "Be specific. Facts over feelings."
                    )

                    // ===== Production =====
                    CurrentStateSectionHeader(label: "Production", emoji: "💼")
                    Text("A man produces more than he consumes: Set goals, share talents, make the job the boss, track progress, Pareto Principle, no one outworks me, etc.")
                        .font(.system(size: 13, weight: .regular))
                        .italic()
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                        .padding(.leading, 4)
                        .padding(.bottom, 6)

                    CurrentStatePillarEditor(
                        text: Binding(
                            get: { productionText },
                            set: { productionText = $0 }
                        ),
                        placeholder: "Be specific. Facts over feelings."
                    )

                    // --- Save to Journal ---
                    HStack {
                        Spacer()
                        Button(action: { saveToJournal() }) {
                            Text("Save to Journal")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(AppTheme.appGreen)
                                .cornerRadius(10)
                        }
                        .accessibilityLabel("Save Current State snapshot to Journal Library")
                    }
                    .padding(.top, 10)

                    Spacer(minLength: 32) // keep clear of footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }

        // ===== Toolbar =====
        .toolbar {
            // LEFT — Shield (full-screen cover)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showShield = true }) {
                    (UIImage(named: shieldAsset) != nil
                     ? Image(shieldAsset).resizable().scaledToFit()
                     : Image("AppShieldSquare").resizable().scaledToFit()
                    )
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                    .padding(4)
                    .offset(y: -2)
                }
                .accessibilityLabel("Open page shield")
            }

            // CENTER — Title
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text("🧭")
                        .font(.system(size: 18, weight: .regular))
                    Text("Current State")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.bottom, 10)
            }

            // RIGHT — Profile avatar → ProfileEditView sheet
            ToolbarItem(placement: .navigationBarTrailing) {
                Group {
                    if let path = store.profile.photoPath,
                       let ui = UIImage(contentsOfFile: path) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else if UIImage(named: "ATMPic") != nil {
                        Image("ATMPic").resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, AppTheme.appGreen)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .offset(y: -2)
                .onTapGesture { showProfileEdit = true }
                .accessibilityLabel("Profile")
            }
        }
        

        // Hide default back chevron; rely on shield + footer Goals pop
        .navigationBarBackButtonHidden(true)

        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

        // Shield full-screen
        .fullScreenCover(isPresented: $showShield) {
            ShieldPage(
                imageName: (UIImage(named: shieldAsset) != nil ? shieldAsset : "AppShieldSquare")
            )
        }

        // Profile sheet
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView().environmentObject(store)
        }

        // Pop back to Goals when footer "Goals" is tapped (both signals supported)
        .onReceive(NotificationCenter.default.publisher(for: .goalsTabTapped)) { _ in
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("reselectTab"))) { note in
            if let page = note.object as? IosPage, page == .goals {
                dismiss()
            }
        }

        // Saved alert
        .alert("Saved to Journal ✅", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Build snapshot and save to Journal Library
    private func saveToJournal() {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateStr = formatter.string(from: date)

        func block(_ header: String, _ text: String) -> String {
            let cleaned = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { "- \($0)" }
                .joined(separator: "\n")

            return cleaned.isEmpty ? "\(header)\n" : "\(header)\n\(cleaned)\n"
        }

        let body = [
            "🧭 Current State — Snapshot (\(dateStr))",
            "",
            block("🏋 Physiology", physiologyText),
            block("🙏 Piety", pietyText),
            block("👥 People", peopleText),
            block("💼 Production", productionText)
        ].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        JournalMemoryStore.shared.addFreeFlow(
            title: "CSS: Current State Snapshot",
            body: body,
            createdAt: date
        )

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showSavedAlert = true
    }
}

// MARK: - Section Header
private struct CurrentStateSectionHeader: View {
    let label: String
    let emoji: String
    var body: some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 18))
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
        }
        .padding(.top, 6)
    }
}

// MARK: - Multiline editor
private struct CurrentStatePillarEditor: View {
    @Binding var text: String
    let placeholder: String

    private let minHeight: CGFloat = 120

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight, alignment: .topLeading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.surfaceUI)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.textSecondary.opacity(0.25), lineWidth: 1)
                )
                .foregroundStyle(Color.white)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
        }
    }
}
