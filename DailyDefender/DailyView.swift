import SwiftUI
import AVFoundation
import AVKit

struct DailyView: View {
    @EnvironmentObject var store: HabitStore

    // Celebration state
    @State private var showConfetti = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showVideo = false
    @State private var videoPlayer: AVPlayer?
    @State private var endObserver: Any?

    // Profile / Shields
    @State private var showProfileEdit = false
    @State private var showFourPs = false

    // Progress tracking
    @State private var lastCompletedCount: Int = 0
    private var totalPossible: Int { DefaultHabits.filter { $0.isCore }.count }
    private var completedCount: Int { store.completed.lazy.filter { HabitById[$0]?.isCore == true }.count }
    private var progress: Double { totalPossible == 0 ? 0 : Double(completedCount) / Double(totalPossible) }

    // yyyy-MM-dd string for the header
    private var todayString: String {
        let f = DateFormatter()
        f.calendar = .init(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // AVPlayerLayer-backed renderer
    private final class PlayerContainerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
    private struct PlayerLayerView: UIViewRepresentable {
        let player: AVPlayer
        func makeUIView(context: Context) -> PlayerContainerView {
            let v = PlayerContainerView()
            v.playerLayer.player = player
            v.playerLayer.videoGravity = .resizeAspect
            v.backgroundColor = .black
            return v
        }
        func updateUIView(_ uiView: PlayerContainerView, context: Context) {
            if uiView.playerLayer.player !== player {
                uiView.playerLayer.player = player
            }
        }
    }

    // ---- One-shot/rising-edge gating (per day) ----
    private var celebrate4Key: String { "celebrated4_\(todayString)" }
    private var prev4Key: String { "prev4_\(todayString)" }
    private var celebrate8Key: String { "celebrated8_\(todayString)" }
    private var prev8Key: String { "prev8_\(todayString)" }

    private var hasCelebrated4: Bool { UserDefaults.standard.bool(forKey: celebrate4Key) }
    private var prevAtLeast4: Bool { UserDefaults.standard.bool(forKey: prev4Key) }
    private func setCelebrated4(_ v: Bool) { UserDefaults.standard.set(v, forKey: celebrate4Key) }
    private func setPrev4(_ v: Bool) { UserDefaults.standard.set(v, forKey: prev4Key) }

    private var hasCelebrated8: Bool { UserDefaults.standard.bool(forKey: celebrate8Key) }
    private var prevAtLeast8: Bool { UserDefaults.standard.bool(forKey: prev8Key) }
    private func setCelebrated8(_ v: Bool) { UserDefaults.standard.set(v, forKey: celebrate8Key) }
    private func setPrev8(_ v: Bool) { UserDefaults.standard.set(v, forKey: prev8Key) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                // MAIN LIST
                List {
                    progressSection
                    ForEach(Pillar.allCases, id: \.self) { pillar in
                        let group = habits(for: pillar)
                        if !group.isEmpty {
                            pillarSection(pillar, group: group)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.bottom, 48)
                .modifier(CompactListTweaks())

                // Confetti overlay
                if showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            // Toolbar
            .toolbar {
                // LEFT: tappable 4 Ps shield
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showFourPs = true }) {
                        Image("four_ps")
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .padding(4)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Open 4 Ps Shield")
                }

                // CENTER: title + date
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            ZStack {
                                Image(systemName: "square.fill")
                                    .renderingMode(.template)
                                    .foregroundColor(AppTheme.appGreen)
                                Image(systemName: "checkmark")
                                    .renderingMode(.template)
                                    .foregroundColor(.white)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(width: 18, height: 18)

                            Text("Daily Defender Actions")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Text("Today: \(todayString)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.bottom, 6)
                    }
                }

                // RIGHT: avatar
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if let path = store.profile.photoPath,
                           let ui = UIImage(contentsOfFile: path) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                        } else if UIImage(named: "ATMPic") != nil {
                            Image("ATMPic")
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, AppTheme.appGreen)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .onTapGesture { showProfileEdit = true }
                    .accessibilityLabel("Edit Profile")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

            // Fullscreen: Four Ps shield (reusable page)
            .fullScreenCover(isPresented: $showFourPs) {
                ShieldPage(imageName: "four_ps")
            }

            // Fullscreen celebration video
            .fullScreenCover(isPresented: $showVideo, onDismiss: {
                videoPlayer?.pause()
                videoPlayer = nil
                if let token = endObserver {
                    NotificationCenter.default.removeObserver(token)
                    endObserver = nil
                }
                try? AVAudioSession.sharedInstance().setActive(false)
            }) {
                ZStack {
                    if let player = videoPlayer, let item = player.currentItem {
                        PlayerLayerView(player: player)
                            .ignoresSafeArea()
                            .onAppear {
                                if item.status == .readyToPlay {
                                    player.seek(to: .zero)
                                    player.play()
                                } else {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        player.seek(to: .zero)
                                        player.play()
                                    }
                                }
                            }
                    } else {
                        Color.black.ignoresSafeArea()
                    }
                }
            }

            // Profile sheet
            .sheet(isPresented: $showProfileEdit) {
                ProfileEditView()
                    .environmentObject(store)
            }

            // Initial state seeding
            .onAppear {
                lastCompletedCount = completedCount
                setPrev4(completedCount >= 4)
                setPrev8(totalPossible > 0 && completedCount == totalPossible)
            }

            // Celebration triggers
            .onChange(of: completedCount) { newValue in
                // 4-of-4
                let nowAtLeast4 = newValue >= 4
                if !nowAtLeast4 {
                    if hasCelebrated4 { setCelebrated4(false) }
                    if prevAtLeast4 { setPrev4(false) }
                } else {
                    if !prevAtLeast4 && !hasCelebrated4 {
                        setCelebrated4(true); setPrev4(true)
                        fireConfettiAndAudio()
                    } else if !prevAtLeast4 {
                        setPrev4(true)
                    }
                }

                // All core complete
                let nowAll = (totalPossible > 0 && newValue == totalPossible)
                if !nowAll {
                    if hasCelebrated8 { setCelebrated8(false) }
                    if prevAtLeast8 { setPrev8(false) }
                } else {
                    if !prevAtLeast8 && !hasCelebrated8 {
                        setCelebrated8(true); setPrev8(true)
                        fireVideo()
                    } else if !prevAtLeast8 {
                        setPrev8(true)
                    }
                }

                lastCompletedCount = newValue
            }
        }
    }

    // MARK: - Helpers

    private func habits(for pillar: Pillar) -> [Habit] {
        DefaultHabits.filter { $0.pillar == pillar }
    }

    // MARK: - Sections

    private var progressSection: some View {
        Section {
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .tint(AppTheme.appGreen)
                Text("\(completedCount) / \(totalPossible) completed today")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
        }
        .listRowBackground(AppTheme.surface)
    }

    @ViewBuilder
    private func pillarSection(_ pillar: Pillar, group: [Habit]) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                SectionHeader(label: pillar.label, pillar: pillar, countText: nil)
                    .padding(.top, 6)
                Text(pillarSubtitle(forLabel: pillar.label))
                    .font(.caption)
                    .italic()
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.leading, 8)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)

            ForEach(Array(group.enumerated()), id: \.element.id) { _, habit in
                HabitRow(
                    habit: habit,
                    checked: store.completed.contains(habit.id),
                    onToggle: { store.toggle(habit.id) }
                )
                .listRowInsets(.init())
                .padding(.vertical, 2)
            }
        }
        .listRowBackground(AppTheme.navy900)
    }

    // MARK: - Celebrations

    private func fireConfettiAndAudio() {
        withAnimation(.easeInOut(duration: 0.2)) { showConfetti = true }
        if let url = Bundle.main.url(forResource: "welldone", withExtension: "mp3") ??
                     Bundle.main.url(forResource: "welldone", withExtension: "m4a") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch { }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showConfetti = false }
        }
    }

    private func fireVideo() {
        if let token = endObserver {
            NotificationCenter.default.removeObserver(token)
            endObserver = nil
        }

        guard let url = Bundle.main.url(forResource: "youareamazingguy", withExtension: "mp4") else {
            showVideo = true
            videoPlayer = nil
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        player.actionAtItemEnd = .pause

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            showVideo = false
        }

        videoPlayer = player
        showVideo = true
        player.seek(to: .zero)
        player.play()
    }
}

// MARK: - Compact List Tweaks
private struct CompactListTweaks: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .contentMargins(.vertical, 0)
                .listSectionSpacing(.compact)
                .listRowSpacing(0)
        } else {
            content
        }
    }
}

// MARK: - Subtitles
private func pillarSubtitle(forLabel label: String) -> String {
    switch label.lowercased() {
    case "physiology": return "The body is the universal address of your existence"
    case "piety":      return "Using mystery & awe as the spirit speaks for the soul"
    case "people":     return "Team Human: herd animals who exist in each other"
    case "production": return "A man produces more than he consumes"
    default:           return ""
    }
}

// MARK: - Confetti
private struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.midX, y: -10)
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)

        let imageSize: CGFloat = 10
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))
        let whiteCircle = renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: imageSize, height: imageSize)).fill()
        }.cgImage

        func cell(_ color: UIColor) -> CAEmitterCell {
            let c = CAEmitterCell()
            c.contents = whiteCircle
            c.color = color.cgColor
            c.birthRate = 16
            c.lifetime = 2.4
            c.velocity = 180
            c.velocityRange = 80
            c.emissionLongitude = .pi
            c.emissionRange = .pi / 8
            c.spin = 3
            c.spinRange = 4
            c.scale = 0.6
            c.scaleRange = 0.3
            return c
        }

        emitter.emitterCells = [
            cell(.systemGreen), cell(.systemBlue), cell(.systemPink),
            cell(.systemOrange), cell(.systemYellow), cell(.systemPurple)
        ]

        view.layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { emitter.birthRate = 0 }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
