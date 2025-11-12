import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct DailyView: View {
    @EnvironmentObject var store: HabitStore
    @EnvironmentObject var session: SessionViewModel

    // Celebration
    @State private var showConfetti = false
    @State private var audioPlayer: AVAudioPlayer?

    // Victory video
    @State private var showVictoryModal = false

    // Profile / Shields
    @State private var showFourPs = false
    @State private var goProfileEdit = false

    // Keyboard state
    @State private var keyboardVisible = false
    @State private var keyboardHeight: CGFloat = 0

    // Editor focus state (for auto headroom + scroll like Weekly)
    @State private var anyEditorFocused = false

    // yyyy-MM-dd
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

    // Celebration keys
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

    // To-Do persistence key (global)
    private let TODO_PERSIST_KEY = "focus_todo_list"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack {
                    AppTheme.navy900.ignoresSafeArea()

                    List {
                        // Progress
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

                        // Pillars
                        ForEach(Pillar.allCases, id: \.self) { pillar in
                            pillarBlock(pillar, proxy: proxy)
                        }

                        // To-Do (card includes its own title line with +)
                        Section {
                            TodoListCard(persistKey: TODO_PERSIST_KEY, todayString: todayString)
                                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(AppTheme.navy900)
                        }

                        // Small bottom spacer so you can always scroll past the last card
                        Section { Color.clear.frame(height: 24) }
                            .listRowSeparator(.hidden)
                            .listRowBackground(AppTheme.navy900)
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.interactively)
                    .scrollContentBackground(.hidden)
                    .modifier(CompactListTweaks())
                    .withKeyboardDismiss()

                    // ⬇️ Confetti overlay — always on top of the List/toolbar
                    if showConfetti {
                        ConfettiView()
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .zIndex(999)
                            .transition(.opacity)
                    }
                }
                // modest headroom so last editor stays above footer/keyboard
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: (keyboardVisible || anyEditorFocused) ? 104 : 64)
                        .allowsHitTesting(false)
                }
            }

            // Hidden push
            NavigationLink("", isActive: $goProfileEdit) {
                ProfileEditView()
                    .environmentObject(store)
                    .environmentObject(session)
            }
            .hidden()

            // Toolbar
            .toolbar {
                // LEFT — 4Ps
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showFourPs = true }) {
                        Image("four_ps")
                            .resizable().scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.textSecondary.opacity(0.4), lineWidth: 1))
                            .padding(4)
                            .offset(y: -2)
                    }
                    .accessibilityLabel("Open 4 Ps Shield")
                }

                // CENTER — title/date
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            ZStack {
                                Image(systemName: "square.fill").foregroundColor(AppTheme.appGreen)
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(width: 18, height: 18)

                            Text("Daily Defender Actions")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1).minimumScaleFactor(0.9)
                        }
                        Text("Today: \(todayString)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.bottom, 6)
                    }
                }

                // RIGHT — avatar → ProfileEdit
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
                    .offset(y: -2)
                    .onTapGesture { goProfileEdit = true }
                    .accessibilityLabel("Profile")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navy900, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)

            // Shields / video
            .fullScreenCover(isPresented: $showFourPs) { ShieldPage(imageName: "four_ps") }
            .fullScreenCover(isPresented: $showVictoryModal) {
                VictoryVideoModal(videoName: "youareamazingguy", isPresented: $showVictoryModal)
            }

            // Seed & keyboard observers
            .onAppear {
                setPrev2(completedCount >= 2)
                setPrev4(completedCount >= 4)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                keyboardVisible = true
                if let h = extractKeyboardHeight(from: note) { keyboardHeight = h }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
                keyboardHeight = 0
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                if let h = extractKeyboardHeight(from: note) { keyboardHeight = h; keyboardVisible = h > 0 }
            }

            // Celebrations
            .onChange(of: completedCount) { newValue in
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

    private func extractKeyboardHeight(from note: Notification) -> CGFloat? {
        guard
            let info = note.userInfo,
            let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return nil }
        let screen = UIScreen.main.bounds
        let overlap = max(0, screen.maxY - endFrame.minY)
        return overlap
    }

    // Smooth scroll helper (like Weekly)
    private func scrollTo(_ id: String, proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    // MARK: - Pillar block
    @ViewBuilder
    private func pillarBlock(_ pillar: Pillar, proxy: ScrollViewProxy) -> some View {
        let pid = pillarId(pillar)
        let checked = store.completed.contains(pid)
        let anchorId = "pillar-\(pid)"

        Section {
            HStack(spacing: 8) {
                SectionHeader(label: pillar.label, pillar: pillar, countText: nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                CheckSquare(checked: checked) { store.toggle(pid) }
                    .padding(.trailing, 14)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)

            Text(pillarSubtitle(forLabel: pillar.label))
                .font(.caption.italic())
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.navy900)

            // Notes card — auto-grow, wraps, paragraph spacing and focus headroom
            PlainNotesCard(
                text: persistedFocus(for: pid),
                placeholder: "Focused activity?",
                onChange: { setPersistedFocus($0, for: pid) },
                onFocusChange: { focused in
                    anyEditorFocused = focused
                    if focused { scrollTo(anchorId, proxy: proxy) }
                }
            )
            .padding(.top, 8)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.navy900)
            .id(anchorId)
        }
    }

    // Pillar focus persistence
    private func focusKey(_ pid: String) -> String { "focus_\(pid)" }
    private func persistedFocus(for pid: String) -> String {
        UserDefaults.standard.string(forKey: focusKey(pid)) ?? ""
    }
    private func setPersistedFocus(_ v: String, for pid: String) {
        UserDefaults.standard.set(v, forKey: focusKey(pid))
    }

    // Celebrations
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

/// Pillar checkbox button (bigger, easier to tap)
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
                .font(.system(size: 26, weight: .medium))
                .frame(width: 44, height: 44, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// PlainNotesCard — Weekly-style auto-growing UITextView
private struct PlainNotesCard: View {
    @State private var textInternal: String
    @State private var measuredHeight: CGFloat = 46
    let placeholder: String
    let onChange: (String) -> Void
    var onFocusChange: ((Bool) -> Void)? = nil

    init(text: String,
         placeholder: String,
         onChange: @escaping (String) -> Void,
         onFocusChange: ((Bool) -> Void)? = nil) {
        _textInternal = State(initialValue: text)
        self.placeholder = placeholder
        self.onChange = onChange
        self.onFocusChange = onFocusChange
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceUI)

            if textInternal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.callout.italic())
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }

            AutoGrowTextView(
                text: $textInternal,
                onHeightChange: { h in
                    let clamped = max(46, ceil(h))
                    if abs(clamped - measuredHeight) > 0.5 { measuredHeight = clamped }
                },
                onFocusChange: onFocusChange
            )
            .frame(height: measuredHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color.clear)
            .onChange(of: textInternal) { onChange($0) }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 0)
        .padding(.bottom, 4)
    }
}

// Auto-growing UITextView with wrapping + paragraph spacing (for pillar notes)
private struct AutoGrowTextView: UIViewRepresentable {
    @Binding var text: String
    var onHeightChange: (CGFloat) -> Void
    var onFocusChange: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.textColor = UIColor.white
        tv.tintColor = UIColor(AppTheme.appGreen)
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.isScrollEnabled = false
        tv.keyboardDismissMode = .interactive
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        tv.textContainer.widthTracksTextView = true
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.autocorrectionType = .yes
        tv.autocapitalizationType = .sentences
        tv.smartDashesType = .no
        tv.smartQuotesType = .no
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.delegate = context.coordinator

        // Paragraph spacing
        let ps = NSMutableParagraphStyle()
        ps.lineBreakMode = .byWordWrapping
        ps.paragraphSpacing = 6
        ps.lineSpacing = 2
        context.coordinator.typingParagraphStyle = ps
        tv.typingAttributes = [
            .paragraphStyle: ps,
            .foregroundColor: UIColor.white,
            .font: tv.font as Any
        ]

        tv.text = text
        DispatchQueue.main.async { self.remeasure(tv) }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        var attrs = uiView.typingAttributes
        attrs[.paragraphStyle] = context.coordinator.typingParagraphStyle
        attrs[.foregroundColor] = UIColor.white
        attrs[.font] = uiView.font as Any
        uiView.typingAttributes = attrs

        DispatchQueue.main.async { self.remeasure(uiView) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoGrowTextView
        var typingParagraphStyle: NSParagraphStyle?
        init(_ parent: AutoGrowTextView) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChange?(true)
            parent.remeasure(textView)
        }
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChange?(false)
            parent.remeasure(textView)
        }
        func textViewDidChange(_ textView: UITextView) {
            if let ps = typingParagraphStyle {
                var attrs = textView.typingAttributes
                attrs[.paragraphStyle] = ps
                attrs[.foregroundColor] = UIColor.white
                attrs[.font] = textView.font as Any
                textView.typingAttributes = attrs
            }
            parent.text = textView.text ?? ""
            parent.remeasure(textView)
        }
    }

    fileprivate func remeasure(_ tv: UITextView) {
        var targetWidth = tv.bounds.width
        if targetWidth <= 0 {
            targetWidth = UIScreen.main.bounds.width - 32
        }
        let size = tv.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
        onHeightChange(size.height)
    }
}

// ===== To-Do List (wrapping + id-based mutation, Done closes KB, + button on title line) =====
private struct TodoListCard: View {
    let persistKey: String
    let todayString: String

    private let CONTROL: Character = "\u{0001}"
    private let SEP: Character = "|"
    private let ITEM_SEP: Character = "\u{0002}"

    struct TodoItem: Identifiable, Equatable {
        var id: UUID
        var text: String
        var done: Bool
        var checkedOn: String
    }

    @State private var items: [TodoItem] = []
    @State private var focusedId: UUID?
    @State private var caretToEndId: UUID?

    var body: some View {
        VStack(spacing: 8) {
            // Title line with + aligned with the trailing column (like section checkboxes)
            HStack(spacing: 8) {
                Text("📝 To-Do List")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer(minLength: 0)

                Button {
                    addNewAndFocus()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundStyle(AppTheme.appGreen)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)   // align with trailing column
                .padding(.top, 2)
                .accessibilityLabel("Add to-do")
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            // Subtitle
            Text("Checked items clear at midnight.")
                .font(.caption.italic())
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .fixedSize(horizontal: false, vertical: true)

            // Rows
            VStack(spacing: 0) {
                if items.isEmpty {
                    Button {
                        addNewAndFocus()
                    } label: {
                        HStack(alignment: .center, spacing: 6) {
                            Image(systemName: "square")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(AppTheme.textPrimary, .clear)
                                .font(.title3)
                            Text("Add first to-do…")
                                .font(.callout.italic())
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }

                ForEach(items) { item in
                    TodoRowView(
                        item: item,
                        isFocused: focusedId == item.id,
                        moveCaretToEnd: caretToEndId == item.id,
                        onBeginEditing: { focusedId = item.id },

                        onChange: { newText in
                            guard let i = index(for: item.id) else { return }
                            items[i].text = newText
                            save()
                        },

                        onDone: {
                            resignFirstResponder()
                        },

                        onBackspaceAtStart: {
                            // Merge with previous item (focus previous, caret to end)
                            resignFirstResponder()
                            guard let i = index(for: item.id), i > 0 else { return }
                            let prevId = items[i - 1].id
                            items.remove(at: i)
                            save()
                            focusedId = prevId
                            caretToEndId = prevId
                        },

                        onBlurEmpty: {
                            // Remove empty row if still present
                            guard let i = index(for: item.id) else { return }
                            if items[i].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               !items[i].done {
                                items.remove(at: i)
                                save()
                            }
                        },

                        onToggleDone: {
                            // ⬅️ prevent keyboard on toggle and avoid re-focus
                            focusedId = nil
                            caretToEndId = nil
                            resignFirstResponder()

                            guard let i = index(for: item.id) else { return }
                            items[i].done.toggle()
                            items[i].checkedOn = items[i].done ? todayString : ""
                            save()
                        },

                        onDelete: {
                            resignFirstResponder()
                            guard let i = index(for: item.id) else { return }
                            items.remove(at: i)
                            save()
                        }
                    )
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            )
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 4)
        .onAppear {
            items = load()
            pruneCheckedFromPriorDays()
            pruneEmptyRows()
            save()
        }
    }

    // MARK: - Helpers

    private func addNewAndFocus() {
        let new = TodoItem(id: UUID(), text: "", done: false, checkedOn: "")
        items.append(new)
        save()
        focusedId = new.id
        caretToEndId = new.id
    }

    private func index(for id: UUID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    private func resignFirstResponder() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }

    // Cleanup & persistence
    private func pruneCheckedFromPriorDays() {
        items.removeAll { $0.done && !$0.checkedOn.isEmpty && $0.checkedOn != todayString }
    }
    private func pruneEmptyRows() {
        items.removeAll { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.done }
    }

    private func load() -> [TodoItem] {
        let blob = UserDefaults.standard.string(forKey: persistKey) ?? ""
        guard !blob.isEmpty else { return [] }
        let parts = blob.split(separator: ITEM_SEP, omittingEmptySubsequences: true)
        var out: [TodoItem] = []
        for p in parts {
            let s = String(p)
            if let item = decodeOne(s) { out.append(item) }
        }
        // give each item a fresh UUID on load
        return out.map { TodoItem(id: UUID(), text: $0.text, done: $0.done, checkedOn: $0.checkedOn) }
    }

    private func save() {
        let payload = items
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.done }
            .map { encodeOne($0) }
            .joined(separator: String(ITEM_SEP))
        UserDefaults.standard.set(payload, forKey: persistKey)
    }

    private func encodeOne(_ item: TodoItem) -> String {
        let flag = item.done ? "1" : "0"
        let safeText = item.text.replacingOccurrences(of: String(ITEM_SEP), with: " ")
        return "\(CONTROL)\(flag)\(SEP)\(item.checkedOn)\(SEP)\(safeText)"
    }

    private func decodeOne(_ raw: String) -> TodoItem? {
        guard !raw.isEmpty else { return nil }
        var rest = raw
        guard rest.first == CONTROL else {
            return TodoItem(id: UUID(), text: raw, done: false, checkedOn: "")
        }
        rest.removeFirst()
        guard let i1 = rest.firstIndex(of: SEP) else { return nil }
        let flag = String(rest[..<i1]) == "1"
        let r1 = rest[rest.index(after: i1)...]
        guard let i2 = r1.firstIndex(of: SEP) else { return nil }
        let checked = String(r1[..<i2])
        let text = String(r1[r1.index(after: i2)...])
        return TodoItem(id: UUID(), text: text, done: flag, checkedOn: checked)
    }
}

// One row with auto-growing editor + trailing trash outside input area
private struct TodoRowView: View {
    var item: TodoListCard.TodoItem
    var isFocused: Bool
    var moveCaretToEnd: Bool
    var onBeginEditing: () -> Void
    var onChange: (String) -> Void
    var onDone: () -> Void
    var onBackspaceAtStart: () -> Void
    var onBlurEmpty: () -> Void
    var onToggleDone: () -> Void
    var onDelete: () -> Void

    @State private var textInternal: String = ""
    @State private var measuredHeight: CGFloat = 22

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Checkbox (fixed) — explicitly dismiss KB before toggling
            Button(action: {
                #if canImport(UIKit)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
                #endif
                onToggleDone()
            }) {
                Image(systemName: item.done ? "checkmark.square.fill" : "square")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(item.done ? .white : AppTheme.textPrimary,
                                     item.done ? AppTheme.appGreen : .clear)
                    .font(.system(size: 26, weight: .medium))
                    .frame(width: 36, height: 36, alignment: .center)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .padding(.leading, -6)

            // Editor column (flexible, wraps)
            VStack(spacing: 0) {
                AutoGrowRowTextView(
                    text: textInternal,
                    isFocused: isFocused,
                    moveCaretToEnd: moveCaretToEnd,
                    onBeginEditing: onBeginEditing,
                    onChange: { newText in
                        textInternal = newText
                        onChange(newText)
                    },
                    onDone: onDone,
                    onBackspaceAtStart: onBackspaceAtStart,
                    onBlurEmpty: onBlurEmpty,
                    onHeightChange: { h in
                        let hClamped = max(22, ceil(h))
                        if abs(hClamped - measuredHeight) > 0.5 { measuredHeight = hClamped }
                    }
                )
                .frame(height: measuredHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            }

            // Trash (fixed, outside input area)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                    .opacity(textInternal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 0.9)
                    .frame(width: 28, height: 28, alignment: .center)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .onAppear { textInternal = item.text }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// Auto-grow UITextView specialized for To-Do rows (wraps, measures height, Return=Done)
private struct AutoGrowRowTextView: UIViewRepresentable {
    var text: String
    var isFocused: Bool
    var moveCaretToEnd: Bool
    var onBeginEditing: () -> Void
    var onChange: (String) -> Void
    var onDone: () -> Void
    var onBackspaceAtStart: () -> Void
    var onBlurEmpty: () -> Void
    var onHeightChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.textColor = UIColor.white
        tv.tintColor = UIColor(AppTheme.appGreen)
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.isScrollEnabled = false
        tv.keyboardDismissMode = .interactive
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainerInset = UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        tv.textContainer.widthTracksTextView = true
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.autocorrectionType = .yes
        tv.autocapitalizationType = .sentences
        tv.smartDashesType = .no
        tv.smartQuotesType = .no
        tv.returnKeyType = .done            // show Done
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.delegate = context.coordinator
        tv.text = text

        DispatchQueue.main.async { self.remeasure(tv) }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }

        if isFocused, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
            if moveCaretToEnd {
                let ns = uiView.text as NSString
                uiView.selectedRange = NSRange(location: ns.length, length: 0)
            }
        }
        DispatchQueue.main.async { self.remeasure(uiView) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoGrowRowTextView
        init(_ parent: AutoGrowRowTextView) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onBeginEditing()
            parent.remeasure(textView)
        }

        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            if text == "\n" {
                // Done: dismiss keyboard, do not insert newline
                textView.resignFirstResponder()
                parent.onDone()
                parent.remeasure(textView)
                return false
            }
            if text.isEmpty && range.length == 1 && range.location == 0 {
                if let sel = textView.selectedTextRange,
                   textView.offset(from: textView.beginningOfDocument, to: sel.start) == 0,
                   textView.offset(from: sel.start, to: sel.end) == 0 {
                    parent.onBackspaceAtStart()
                    return false
                }
            }
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.onChange(textView.text ?? "")
            parent.remeasure(textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            let txt = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if txt.isEmpty { parent.onBlurEmpty() }
            parent.remeasure(textView)
        }
    }

    fileprivate func remeasure(_ tv: UITextView) {
        var targetWidth = tv.bounds.width
        if targetWidth <= 0 {
            // leave room for checkbox (28 + spacing) and trash (28 + spacing) and card padding
            targetWidth = UIScreen.main.bounds.width - 32 - 28 - 8 - 28 - 12
        }
        let size = tv.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
        onHeightChange(size.height)
    }
}

// Compact list tweaks (needed on iOS 17+ to tighten spacing)
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

// Full pillar subtitles
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

// Confetti
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
