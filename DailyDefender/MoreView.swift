import SwiftUI
import UIKit

struct MoreView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel

    // Nav flags
    @State private var goInfo = false
    @State private var goResources = false
    @State private var goStats = false
    @State private var showProfileEdit = false
    @State private var showShield = false

    // Same shield asset used in JournalHome
    private let shieldAsset = "AppShieldSquare"

    var body: some View {
        if !session.isPro {
            PaywallCardView(title: "Pro Feature")
        } else {
            NavigationStack {
                ZStack {
                    AppTheme.navy900.ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {

                            // --- Cards ---
                            MoreCardRow(title: "How To Use App", emoji: "📖") {
                                goInfo = true
                            }

                            MoreCardRow(title: "Resources", emoji: "📚") {
                                goResources = true
                            }

                            MoreCardRow(title: "Stats", emoji: "📊") {
                                goStats = true
                            }

                            Spacer(minLength: 56)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppTheme.navy900, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)

                // === Toolbar/Header ===
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showShield = true }) {
                            (UIImage(named: shieldAsset) != nil
                             ? Image(shieldAsset).resizable().scaledToFit()
                             : Image("AppShieldSquare").resizable().scaledToFit())
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                            .padding(4)
                            .offset(y: -2)
                        }
                        .accessibilityLabel("Open More shield")
                    }

                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 6) {
                            Text("More")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .padding(.bottom, 10)
                    }

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

                // === Sheets / Navs ===
                .fullScreenCover(isPresented: $showShield) {
                    ShieldPage(imageName: shieldAsset)
                }

                .sheet(isPresented: $showProfileEdit) {
                    ProfileEditView().environmentObject(store)
                }

                NavigationLink("", isActive: $goInfo) {
                    MoreInfoHowToStub()
                }.hidden()

                NavigationLink("", isActive: $goResources) {
                    MoreResourcesStub()
                }.hidden()

                NavigationLink("", isActive: $goStats) {
                    StatsView()
                        .environmentObject(store)
                        .environmentObject(session)
                }.hidden()
            }
        }
    }
}

// ==== Card identical layout to JournalCardRow ====
private struct MoreCardRow: View {
    let title: String
    var subtitle: String? = nil
    let emoji: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.appGreen.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Text(emoji)
                        .font(.system(size: 20))
                }

                HStack(spacing: 6) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote.italic())
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// ==== Simple stubs (replace later if needed) ====
private struct MoreInfoHowToStub: View {
    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()
            Text("How To Use App")
                .foregroundStyle(AppTheme.textPrimary)
        }
        .navigationTitle("How To Use App")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MoreResourcesStub: View {
    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()
            Text("Resources")
                .foregroundStyle(AppTheme.textPrimary)
        }
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
    }
}
