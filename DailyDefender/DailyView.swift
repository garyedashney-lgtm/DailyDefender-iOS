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
    @State private var itemStatusObs: NSKeyValueObservation?   // wait for readyToPlay

    // Profile / Shields
    @State private var showProfileEdit = false
    @State private var showFourPs = false

    // yyyy-MM-dd (for daily gating keys)
    private var todayString: String {
        let f = DateFormatter()
        f.calendar = .init(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // Pillar IDs (match Android)
    private func pillarId(_ p: Pillar) -> String {
        switch p {
        case .Physiology: return "pillar_phys"
        case .Piety:      return "pillar_piety"
        case .People:     return "pillar_people"
        case .Production: return "pillar_prod"
        }
    }

    // Progress (4 total: one per pillar)
    private let totalPossible = 4
    private var completedCount: Int {
        Pillar.allCases.filter { store.completed.contains(pillarId($0)) }.count
    }
    private var progress: Double { totalPossible == 0 ? 0 : Double(completedCount) / 4.0 }

    // ---- One-shot/rising-edge gating for 2-of-4 & 4-of-4 (per day) ----
    private var celebrate2Key: String { "celebrated2_\(todayString)" }
    private var prev2Key: String      { "prev2_\(todayString)" }

    private var celebrate4Key: String { "celebrated4_\(todayString)" }
    private var prev4Key: String      { "prev4_\(todayString)" }

    private var hasCelebrated2: Bool { UserDefaults.standard.bool(forKey: celebrate2Key) }
    private var prevAtLeast2: Bool   { UserDefaults.standard.bool(forKey: prev2Key) }
    private func setCelebrated2(_ v: Bool) { UserDefaults.standard.set(v, forKey: celebrate2Key) }
    private func setPrev2(_ v: Bool)       { UserDefaults.standard.set(v, forKey: prev2Key) }

    private var hasCelebrated4: Bool { UserDefaults.standard.bool(forKey: celebrate4Key) }
    private var prevAtLeast4: Bool   { UserDefaults.standard.bool(forKey: prev4Key) }
    private func setCelebrated4(_ v: Bool) { UserDefaults.standard.set(v, forKey: celebrate4Key) }
    private func setPrev4(_ v: Bool)       { UserDefaults.standard.set(v, forKey: prev4Key) }

    // To-Do persistent key (NOT day-scoped)
    private let TODO_PERSIST_KEY = "focus_todo_list"

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navy900.ignoresSafeArea()

                List {
                    // Progress bar + counts
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

                    // 4 Pillar sections
                    ForEach(Pillar.allCases, id: \.self) { pillar in
                        pillarBlock(pillar)
                    }

                    // To-Do section (does not count toward progress)
                    todoBlock()
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)       // drag to dismiss keyboard
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
            // Use simultaneousGesture so taps still reach row buttons (checkboxes)
            .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })

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

                // RIGHT: avatar -> ProfileEdit
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

            // Four Ps shield (reusable)
            .fullScreenCover(isPresented: $showFourPs) {
                ShieldPage(imageName: "four_ps")
            }

            // Victory video at 4/4 — AVPlayerViewController (aspect fill) + readyToPlay gate
            .fullScreenCover(isPresented: $showVideo, onDismiss: {
                videoPlayer?.pause()
                videoPlayer = nil
                if let token = endObserver {
                    NotificationCenter.default.removeObserver(token)
                    endObserver = nil
                }
                itemStatusObs = nil
                try? AVAudioSession.sharedInstance().setActive(false)
            }) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if let player = videoPlayer {
                        PlayerViewController(player: player, videoGravity: .resizeAspectFill) // fill screen
                            .ignoresSafeArea()
                    }
                }
            }

            // Profile sheet
            .sheet(isPresented: $showProfileEdit) {
                ProfileEditView().environmentObject(store)
            }

            // Seed daily gating on appear
            .onAppear {
                setPrev2(completedCount >= 2)
                setPrev4(completedCount >= 4)
            }

            // Celebration triggers for 2-of-4 and 4-of-4
            .onChange(of: completedCount) { newValue in
                // 2-of-4: confetti + “well done”
                let nowAtLeast2 = newValue >= 2
                if !nowAtLeast2 {
                    if hasCelebrated2 { setCelebrated2(false) }
                    if prevAtLeast2 { setPrev2(false) }
                } else {
                    if !prevAtLeast2 && !hasCelebrated2 {
                        setCelebrated2(true); setPrev2(true)
                        fireConfettiAndAudio()
                    } else if !prevAtLeast2 {
                        setPrev2(true)
                    }
                }

                // 4-of-4: victory video
                let nowAtLeast4 = newValue >= 4
                if !nowAtLeast4 {
                    if hasCelebrated4 { setCelebrated4(false) }
                    if prevAtLeast4 { setPrev4(false) }
                } else {
                    if !prevAtLeast4 && !hasCelebrated4 {
                        setCelebrated4(true); setPrev4(true)
                        fireVideo()
                    } else if !prevAtLeast4 {
                        setPrev4(true)
                    }
                }
            }
        }
    }

    // MARK: - Pillar block
    @ViewBuilder
    private func pillarBlock(_ pillar: Pillar) -> some View {
        let pid = pillarId(pillar)
        let checked = store.completed.contains(pid)

        Section {
            // Header + single checkbox (right)
            HStack(spacing: 8) {
                // Left: emoji + title + divider
                SectionHeader(label: pillar.label, pillar: pillar, countText: nil)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Right: custom square checkbox
                CheckSquare(checked: checked) {
                    store.toggle(pid)
                }
            }
            .padding(.horizontal, 2)
            .listRowInsets(.init(top: 6, leading: 12, bottom: 2, trailing: 12))
            .listRowBackground(AppTheme.navy900)

            // Small italic subtitle
            Text(pillarSubtitle(forLabel: pillar.label))
                .font(.caption)
                .italic()
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.leading, 6)
                .padding(.bottom, 4)
                .listRowBackground(AppTheme.navy900)

            // Focus text (persisted per pillar)
            FocusNotesCard(
                text: persistedFocus(for: pid),
                placeholder: "Focused activity?",
                onChange: { setPersistedFocus($0, for: pid) }
            )
            .listRowBackground(AppTheme.navy900)
        }
        .listRowBackground(AppTheme.navy900)
    }

    // MARK: - To-Do block (persistent, not day-scoped)
    @ViewBuilder
    private func todoBlock() -> some View {
        let todoId = "todo_list"
        let checked = store.completed.contains(todoId)

        Section {
            // Header row with 📝 and right checkbox
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("📝").font(.body)
                    Text("To do List")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(AppTheme.divider)

                CheckSquare(checked: checked) {
                    store.toggle(todoId)
                }
            }
            .padding(.horizontal, 2)
            .listRowInsets(.init(top: 6, leading: 12, bottom: 2, trailing: 12))
            .listRowBackground(AppTheme.navy900)

            // Optional subtitle
            Text("Capture key tasks that keep the day moving. Quick hits, reminders, errands, follow-ups, etc.")
                .font(.caption)
                .italic()
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.leading, 6)
                .padding(.bottom, 4)
                .listRowBackground(AppTheme.navy900)

            // Persistent notes (not tied to day)
            FocusNotesCard(
                text: persistedTodo(),
                placeholder: "What’s the next task?",
                onChange: { setPersistedTodo($0) }
            )
            .listRowBackground(AppTheme.navy900)
        }
        .listRowBackground(AppTheme.navy900)
    }

    // MARK: - Persisted focus helpers (per pillar)
    private func focusKey(_ pid: String) -> String { "focus_\(pid)" }
    private func persistedFocus(for pid: String) -> String {
        let raw = UserDefaults.standard.string(forKey: focusKey(pid)) ?? ""
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty || s == "-" || s.hasPrefix("- ") || s.lowercased() == "focused activity?" { return "" }
        return raw
    }
    private func setPersistedFocus(_ value: String, for pid: String) {
        UserDefaults.standard.set(value, forKey: focusKey(pid))
    }

    // MARK: - Persistent To-Do (day-independent)
    private func persistedTodo() -> String {
        let raw = UserDefaults.standard.string(forKey: TODO_PERSIST_KEY) ?? ""
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty || s == "-" || s.hasPrefix("- ") || s.lowercased() == "what’s the next task?" { return "" }
        return raw
    }
    private func setPersistedTodo(_ value: String) {
        UserDefaults.standard.set(value, forKey: TODO_PERSIST_KEY)
    }

    // MARK: - Victory / Confetti

    private func fireConfettiAndAudio() {
        withAnimation(.easeInOut(duration: 0.2)) { showConfetti = true }
        if let url = Bundle.main.url(forResource: "welldone", withExtension: "mp3")
            ?? Bundle.main.url(forResource: "welldone", withExtension: "m4a") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch { /* ignore audio failure */ }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showConfetti = false }
        }
    }

    private func fireVideo() {
        // Clean up any prior observers/players
        if let token = endObserver {
            NotificationCenter.default.removeObserver(token)
            endObserver = nil
        }
        itemStatusObs = nil

        guard let url = Bundle.main.url(forResource: "youareamazingguy", withExtension: "mp4") else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 0
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true
        player.actionAtItemEnd = .pause
        player.isMuted = false

        // Auto-dismiss when done
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            showVideo = false
        }

        videoPlayer = player

        // Wait until the item is READY, then present and play
        itemStatusObs = item.observe(\.status, options: [.initial, .new]) { _, _ in
            guard item.status == .readyToPlay else { return }
            DispatchQueue.main.async {
                itemStatusObs = nil
                showVideo = true             // present VC first
                player.seek(to: .zero)
                player.play()                // then play
            }
        }
    }
}

//
// MARK: - Helpers & subviews
//

/// Simple square checkbox that works on iOS 16+ (no .toggleStyle(.checkbox) needed)
private struct CheckSquare: View {
    let checked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    checked ? .white : AppTheme.textPrimary,
                    checked ? AppTheme.appGreen : .clear
                )
                .font(.title3)
                .padding(6)                    // bigger tap target
                .contentShape(Rectangle())
                .accessibilityLabel(checked ? "Uncheck" : "Check")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FocusNotesCard (multiline notes card with placeholder + keyboard Done)
private struct FocusNotesCard: View {
    @State private var textInternal: String
    @FocusState private var isFocused: Bool

    let placeholder: String
    let onChange: (String) -> Void

    init(text: String, placeholder: String, onChange: @escaping (String) -> Void) {
        _textInternal = State(initialValue: text)
        self.placeholder = placeholder
        self.onChange = onChange
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if textInternal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.callout.italic())
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $textInternal)
                .focused($isFocused)
                .frame(minHeight: 44)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .onChange(of: textInternal) { onChange($0) }
                .toolbar { // keyboard accessory
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isFocused = false }
                    }
                }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }
}

/// Keep List tighter on iOS 17+, noop on iOS 16.
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

// MARK: - Pillar subtitles
private func pillarSubtitle(forLabel label: String) -> String {
    switch label.lowercased() {
    case "physiology":
        return "The body is the universal address of your existence: Breath, walk, lift, bike, hike, stretch, sleep, fast, eat clean, supplement, hydrate, etc."
    case "piety":
        return "Using mystery & awe as the spirit speaks for the soul: 3 blessings, waking up, end-of-day prayer, body scan & resets, the watcher, etc."
    case "people":
        return "Team Human: herd animals who exist in each other: Light people up, reverse the flow, problem solve & collaborate in Defense of Meaning and Freedom, etc."
    case "production":
        return "A man produces more than he consumes: Set goals, share talents, make the job the boss, track progress, Pareto Principle, no one outworks me, etc."
    default:
        return ""
    }
}

// MARK: - Confetti overlay
private struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.midX, y: -10)
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)

        // Tiny white circle bitmap so CAEmitterCell.color tints properly
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
    func updateUIView(_ uiView: UIView, context: Context) { }
}

// MARK: - AVPlayerViewController wrapper (full-screen video, aspect fill)
private struct PlayerViewController: UIViewControllerRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        vc.entersFullScreenWhenPlaybackBegins = false
        vc.exitsFullScreenWhenPlaybackEnds = false
        vc.videoGravity = videoGravity
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player {
            vc.player = player
        }
        if vc.videoGravity != videoGravity {
            vc.videoGravity = videoGravity
        }
    }
}
