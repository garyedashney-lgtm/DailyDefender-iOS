import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct DailyView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel   // ← added

    // Celebration
    @State private var showConfetti = false
    @State private var audioPlayer: AVAudioPlayer?

    // Victory video (handled by separate VictoryVideoModal)
    @State private var showVictoryModal = false

    // Profile / Shields
    @State private var showFourPs = false
    @State private var goProfileEdit = false          // ← push navigation flag

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

    // Progress
    private let totalPossible = 4
    private var completedCount: Int {
        Pillar.allCases.filter { store.completed.contains(pillarId($0)) }.count
    }
    private var progress: Double { Double(completedCount) / Double(totalPossible) }

    // Keys for gating
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
                    // Progress bar
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

                    // 4 Pillars
                    ForEach(Pillar.allCases, id: \.self) { pillar in
                        pillarBlock(pillar)
                    }

                    // To-Do
                    todoBlock()
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
                .scrollContentBackground(.hidden)
                .padding(.bottom, 48)
                .modifier(CompactListTweaks())
                .withKeyboardDismiss()
                
                // Confetti
                if showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }

            // Hidden push link to Profile Edit (keeps footer visible)
            NavigationLink("", isActive: $goProfileEdit) {
                ProfileEditView()
                    .environmentObject(store)
                    .environmentObject(session)
            }
            .hidden()


            // Toolbar
            .toolbar {
                // LEFT — shield (4 Ps)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showFourPs = true }) {
                        Image("four_ps")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                            .padding(4)
                            .offset(y: -2) // optical center
                    }
                    .accessibilityLabel("Open 4 Ps Shield")
                }

                // CENTER — title/date
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            ZStack {
                                Image(systemName: "square.fill")
                                    .foregroundColor(AppTheme.appGreen)
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(width: 18, height: 18)

                            Text("Daily Defender Actions")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        Text("Today: \(todayString)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.bottom, 6)
                    }
                }

                // RIGHT — profile avatar → push ProfileEdit
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if let path = store.profile.photoPath, let ui = UIImage(contentsOfFile: path) {
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
                    .offset(y: -2) // optical center
                    .onTapGesture { goProfileEdit = true }   // ← push instead of sheet
                    .accessibilityLabel("Profile")
                }
            }
            

            // Keep these AFTER .toolbar
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 48) }

            // Four Ps shield (full screen)
            .fullScreenCover(isPresented: $showFourPs) {
                ShieldPage(imageName: "four_ps")
            }

            // Victory video (via standalone modal)
            .fullScreenCover(isPresented: $showVictoryModal) {
                VictoryVideoModal(
                    videoName: "youareamazingguy",
                    isPresented: $showVictoryModal
                )
            }

            // Seed gating
            .onAppear {
                setPrev2(completedCount >= 2)
                setPrev4(completedCount >= 4)
            }

            // Celebration triggers — UNCHANGED
            .onChange(of: completedCount) { newValue in
                // 2-of-4
                let nowAtLeast2 = newValue >= 2
                if !nowAtLeast2 {
                    if hasCelebrated2 { setCelebrated2(false) }
                    if prevAtLeast2   { setPrev2(false) }
                } else if !prevAtLeast2 && !hasCelebrated2 {
                    setCelebrated2(true); setPrev2(true)
                    fireConfettiAndAudio()
                } else if !prevAtLeast2 {
                    setPrev2(true)
                }

                // 4-of-4
                let nowAtLeast4 = newValue >= 4
                if !nowAtLeast4 {
                    if hasCelebrated4 { setCelebrated4(false) }
                    if prevAtLeast4   { setPrev4(false) }
                } else if !prevAtLeast4 && !hasCelebrated4 {
                    setCelebrated4(true); setPrev4(true)
                    showVictoryModal = true
                } else if !prevAtLeast4 {
                    setPrev4(true)
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
            // Header row: flush-left like Weekly
            HStack(spacing: 8) {
                SectionHeader(label: pillar.label, pillar: pillar, countText: nil)
                    .frame(maxWidth: .infinity, alignment: .leading)

                CheckSquare(checked: checked) { store.toggle(pid) }
                    .padding(.trailing, 6) // pull in a tad from screen edge
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)

            // Subtitle: flush-left, allow full wrapping
            Text(pillarSubtitle(forLabel: pillar.label))
                .font(.caption.italic())
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.navy900)

            // Full-width, centered input card
            PlainNotesCard(
                text: persistedFocus(for: pid),
                placeholder: "Focused activity?",
                onChange: { setPersistedFocus($0, for: pid) }
            )
            .listRowInsets(.init(top: 0, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)
        }
    }

    // MARK: - To-Do block
    @ViewBuilder
    private func todoBlock() -> some View {
        let todoId = "todo_list"
        let checked = store.completed.contains(todoId)

        Section {
            // Header row flush-left
            HStack(spacing: 8) {
                Text("📝 To do List")
                    .font(.body.weight(.semibold))
                Spacer()
                CheckSquare(checked: checked) { store.toggle(todoId) }
                    .padding(.trailing, 6)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)

            // Subtitle flush-left
            Text("Capture key tasks that keep the day moving...")
                .font(.caption.italic())
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.navy900)

            // Full-width input card
            PlainNotesCard(
                text: persistedTodo(),
                placeholder: "What’s the next task?",
                onChange: { setPersistedTodo($0) }
            )
            .listRowInsets(.init(top: 0, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)
        }
    }

    // MARK: - Persistence
    private func focusKey(_ pid: String) -> String { "focus_\(pid)" }
    private func persistedFocus(for pid: String) -> String {
        UserDefaults.standard.string(forKey: focusKey(pid)) ?? ""
    }
    private func setPersistedFocus(_ v: String, for pid: String) {
        UserDefaults.standard.set(v, forKey: focusKey(pid))
    }

    private func persistedTodo() -> String {
        UserDefaults.standard.string(forKey: TODO_PERSIST_KEY) ?? ""
    }
    private func setPersistedTodo(_ v: String) {
        UserDefaults.standard.set(v, forKey: TODO_PERSIST_KEY)
    }

    // MARK: - Celebrations
    private func fireConfettiAndAudio() {
        withAnimation { showConfetti = true }
        if let url = Bundle.main.url(forResource: "welldone", withExtension: "mp3")
            ?? Bundle.main.url(forResource: "welldone", withExtension: "m4a") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            showConfetti = false
        }
    }
}

// MARK: - Helpers & subviews (unchanged checkbox)
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
                .padding(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Plain (non-bullet) notes card with perfectly centered first line
private struct PlainNotesCard: View {
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceUI)

            // Placeholder overlay (unchanged look)
            if textInternal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.callout.italic())
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }

            CenteredTextView(
                text: $textInternal,
                onChanged: { onChange($0) },
                targetSingleLineHeight: 46
            )
            .frame(minHeight: 46)
            .background(Color.clear)
        }
        .padding(.horizontal, 0)
        .padding(.bottom, 4)
    }
}

// MARK: - UIKit text view that centers the baseline for single-line text (matching Weekly)
private struct CenteredTextView: UIViewRepresentable {
    @Binding var text: String
    var onChanged: (String) -> Void
    var targetSingleLineHeight: CGFloat = 46

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.textColor = UIColor.white
        tv.tintColor = UIColor(AppTheme.appGreen)
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.isScrollEnabled = false
        tv.keyboardDismissMode = .interactive
        tv.textContainer.lineFragmentPadding = 0
        tv.contentInset = .zero
        tv.delegate = context.coordinator

        applyCenteredInsets(to: tv)
        tv.text = text
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        applyCenteredInsets(to: uiView)
    }

    private func applyCenteredInsets(to tv: UITextView) {
        let font = tv.font ?? UIFont.preferredFont(forTextStyle: .body)
        let asc  = font.ascender
        let desc = abs(font.descender)
        let lead = font.leading
        let line = asc + desc + lead

        let H: CGFloat = targetSingleLineHeight
        let base = max(0, (H - line) / 2)

        // slight bottom bias to look optically centered
        let top = base.rounded(.toNearestOrEven)
        let bottom = (base + 2.0).rounded(.toNearestOrEven)

        tv.textContainerInset = UIEdgeInsets(top: top, left: 12, bottom: bottom, right: 12)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CenteredTextView
        init(_ parent: CenteredTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            parent.onChanged(parent.text)
        }
        func textViewShouldEndEditing(_ textView: UITextView) -> Bool { true }
    }
}

// Existing helpers
private struct CompactListTweaks: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .contentMargins(.vertical, 0)
                .listSectionSpacing(.compact)
                .listRowSpacing(0)
        } else { content }
    }
}

private func pillarSubtitle(forLabel label: String) -> String {
    switch label.lowercased() {
    case "physiology":
        return "The body is the universal address of your existence..."
    case "piety":
        return "Using mystery & awe as the spirit speaks for the soul..."
    case "people":
        return "Team Human: herd animals who exist in each other..."
    case "production":
        return "A man produces more than he consumes..."
    default: return ""
    }
}

// Confetti unchanged
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
