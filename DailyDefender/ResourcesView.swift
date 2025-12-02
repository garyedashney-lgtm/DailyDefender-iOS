import SwiftUI
import MessageUI

/// RESOURCES — iOS version mirroring Android StartHereBody sections 1:1.
struct ResourcesView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    // Header actions (same pattern as InfoView)
    @State private var showResourcesShield = false
    @State private var showProfileEdit = false

    // Collapsible state
    @State private var expandYouTube   = false
    @State private var expandFBGroups  = false
    @State private var expandZoom      = false
    @State private var expandSFPC      = false
    @State private var expandQuadCourse = false
    @State private var expandATM       = false
    @State private var expandPrivacy  = false
    @State private var expandBookCall  = false

    // Use project’s square shield (falls back if missing)
    private let resourcesShieldAsset = "AppShieldSquare"

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {

                        // === YouTube Playlists ===
                        CollapsibleSection(title: "YouTube Playlists", isExpanded: $expandYouTube) {
                            ResourceLinkRow(
                                label: "Start Here – Advisor to Men Essentials",
                                url: "https://www.youtube.com/playlist?list=PLNQ4PqridjtFT6YCh5TYF5SFoOOazKwCX",
                                assetName: "ic_youtube",
                                subtitle: "Foundations and quick wins to get moving"
                            )
                            ResourceLinkRow(
                                label: "Masculine Maturity & Relationships",
                                url: "https://www.youtube.com/playlist?list=PLNQ4PqridjtGO6UC-reM6iIiEIn288J4Y",
                                assetName: "ic_youtube",
                                subtitle: nil
                            )
                            ResourceLinkRow(
                                label: "Addiction, Shame, & Nervous System Work",
                                url: "https://www.youtube.com/playlist?list=PLNQ4PqridjtGVxkXht4Wm3FC2rAVdpwMG",
                                assetName: "ic_youtube",
                                subtitle: nil
                            )
                            ResourceLinkRow(
                                label: "The Defender Shields - Hard Earned Wisdom",
                                url: "https://www.youtube.com/playlist?list=PLNQ4PqridjtEd_YoALAEyB3XDkg2Qv5NS",
                                assetName: "ic_youtube",
                                subtitle: nil
                            )
                            ResourceLinkRow(
                                label: "Masculine Purpose, Destiny & Legacy",
                                url: "https://www.youtube.com/playlist?list=PLNQ4PqridjtGn8vJ7LdWKotzZMCls2RnK",
                                assetName: "ic_youtube",
                                subtitle: nil
                            )
                            ResourceLinkRow(
                                label: "Nice Guy Syndrome Series",
                                url: "https://www.youtube.com/playlist?list=PLNQ4PqridjtE83q7OhoeZ5e44OJNMfFDN",
                                assetName: "ic_youtube",
                                subtitle: nil
                            )
                            // NEW: Shorts playlist
                            ResourceLinkRow(
                                label: "Advisor to Men — YouTube Shorts",
                                url: "https://www.youtube.com/@advisortomen10MM/shorts",
                                assetName: "ic_youtube",
                                subtitle: "Fast-hit shorts and clips from Wallace"
                            )
                        }

                        // === Private FB Support Groups ===
                        CollapsibleSection(title: "Private FB Support Groups", isExpanded: $expandFBGroups) {
                            ResourceLinkRow(
                                label: "Advisor to Men ™ / Men of Honour",
                                url: "https://www.facebook.com/groups/advisortomen",
                                assetName: "ic_facebook",
                                subtitle: nil
                            )
                            ResourceLinkRow(
                                label: "No More Mr Nice Guy (NMMNG)",
                                url: "https://www.facebook.com/groups/niceguyhelpmenonly",
                                assetName: "ic_facebook",
                                subtitle: nil
                            )
                        }

                        // === Weekly Men's Zoom Support Groups ===
                        CollapsibleSection(title: "Weekly Men's Zoom Support Groups", isExpanded: $expandZoom) {
                            ResourceLinkRow(
                                label: "10MM Board of Defenders",
                                url: "https://10mm.org/membership",
                                assetName: "ic_zoom",
                                subtitle: "Join live calls and accountability"
                            )
                        }

                        // === Book — Sipping Fear Pissing Confidence ===
                        CollapsibleSection(title: "Book — Sipping Fear Pissing Confidence", isExpanded: $expandSFPC) {
                            ResourceLinkRow(
                                label: "Sipping Fear Pissing Confidence (Christopher K. Wallace) — Amazon",
                                url: "https://www.amazon.com/Sipping-Fear-Pissing-Confidence-Addictions/dp/B0BV4XQJ8C",
                                assetName: "ic_courses", // use your colored courses icon here
                                subtitle: "Audiobook/Kindle/Paperback options"
                            )
                            Text("Dr. Robert Glover (No More Mr. Nice Guy) praised this as one of the best books for men and on addictions.")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textSecondary)

                            ResourceLinkRow(
                                label: "Watch: Dr. Robert Glover reviews SFPC",
                                url: "https://www.youtube.com/watch?v=mcJdlg8a1eI",
                                assetName: "ic_youtube",
                                subtitle: "Short video review of the book"
                            )
                        }

                        // === Free Quadrant Course ===
                        CollapsibleSection(title: "Free Quadrant Course", isExpanded: $expandQuadCourse) {
                            ResourceLinkRow(
                                label: "Access and Master All 6 Lessons",
                                url: "https://10mm.org/quad-course",
                                assetName: "ic_courses",
                                subtitle: "Step-by-step training and tools"
                            )
                        }

                        // === Advisor to Men — Official Website ===
                        CollapsibleSection(title: "Advisor to Men — Official Website", isExpanded: $expandATM) {
                            ResourceLinkRow(
                                label: "AdvisorToMen.com",
                                url: "https://advisortomen.com/",
                                assetName: "ic_advisortomen",
                                subtitle: "Courses, private coaching, articles & more"
                            )
                        }
                        
                        // === App Privacy Manifesto ===
                        CollapsibleSection(title: "🔒 App Privacy Manifesto", isExpanded: $expandPrivacy) {
                            NavigationLink {
                                PrivacyManifestoView()
                            } label: {
                                HStack(alignment: .center, spacing: 10) {
                                    Image(systemName: "lock.shield")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .foregroundStyle(AppTheme.appGreen)
                                        .padding(2)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("View the full App Privacy Manifesto")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(AppTheme.appGreen)
                                            .underline()

                                        Text("How your journals, goals, stats, and account data are handled.")
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        // === Book a Call with Advisor to Men™ ===
                        CollapsibleSection(title: "Book a Call with Advisor to Men™", isExpanded: $expandBookCall) {
                            ResourceLinkRow(
                                label: "Book Here",
                                url: "https://go.oncehub.com/ChristopherWallace",
                                assetName: "ic_phone",
                                subtitle: "Personal guidance on your next step"
                            )
                        }

                        Spacer(minLength: 56) // keep clear of global footer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }

            // === Toolbar (InfoView pattern; Resources title + subtitle) ===
            .toolbar {
                // Left: Shield icon → FULL SCREEN Cover to ShieldPage
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showResourcesShield = true }) {
                        (UIImage(named: resourcesShieldAsset) != nil
                         ? Image(resourcesShieldAsset).resizable().scaledToFit()
                         : Image("AppShieldSquare").resizable().scaledToFit()
                        )
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                        .padding(4)
                        .offset(y: -2) // optical centering
                    }
                    .accessibilityLabel("Open page shield")
                }

                // Center: Title + subtitle
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text("📚")
                                .font(.system(size: 18, weight: .regular))
                            Text("Resources")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Text("Helpful guides & tools")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 10)
                }

                // Right: Profile avatar → edit sheet
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

            // Full-screen shield page
            .fullScreenCover(isPresented: $showResourcesShield) {
                ShieldPage(
                    imageName: (UIImage(named: resourcesShieldAsset) != nil
                                ? resourcesShieldAsset
                                : "AppShieldSquare")
                )
            }

            // Profile sheet
            .sheet(isPresented: $showProfileEdit) {
                ProfileEditView().environmentObject(store)
            }

            // ✅ Reselect-tab listener: if user taps the active "More" tab, pop back.
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("reselectTab"))) { note in
                if let page = note.object as? IosPage, page == .more {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Collapsible Section (flat style + animated chevron + fade)
private struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isExpanded.toggle()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 6)
                        .foregroundStyle(AppTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeOut(duration: 0.18), value: isExpanded)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content — now with fade
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(.top, 6)
                .transition(
                    .opacity
                        .animation(.easeInOut(duration: 0.22))
                        .combined(with: .move(edge: .top))
                )
            }

            Divider()
                .overlay(AppTheme.textSecondary.opacity(0.15))
                .padding(.top, 8)
        }
        .background(Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Resource Link Row (flat style, no trailing arrow, no card)
private struct ResourceLinkRow: View {
    let label: String
    let url: String
    let assetName: String?   // e.g., "ic_youtube", "ic_facebook"
    let subtitle: String?

    var body: some View {
        Button(action: openURL) {
            HStack(alignment: .center, spacing: 10) {
                iconView

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.appGreen)
                        .underline()

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var iconView: some View {
        let size: CGFloat = 22
        if let name = assetName, UIImage(named: name) != nil {
            Image(name)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .padding(2)
        } else {
            Image(systemName: "link")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(AppTheme.appGreen)
                .padding(2)
        }
    }

    private func openURL() {
        if let u = URL(string: url) {
            UIApplication.shared.open(u)
        }
    }
}
