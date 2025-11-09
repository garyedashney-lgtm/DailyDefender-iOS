import SwiftUI
import UniformTypeIdentifiers
import Foundation

// MARK: - Model
struct JournalEntryIOS: Identifiable, Hashable {
    var id: Int64
    var dateMillis: Int64
    var title: String
    var content: String
    var updatedAt: Int64
}

// MARK: - String helpers
@inline(__always)
private func hasPrefixCI(_ s: String, _ prefix: String) -> Bool {
    let pat = "^\(NSRegularExpression.escapedPattern(for: prefix))"
    return s.range(of: pat, options: [.regularExpression, .caseInsensitive]) != nil
}

// MARK: - Date helpers
private func dateOnlyLabel(_ millis: Int64) -> String {
    let d = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
    let f = DateFormatter()
    f.dateFormat = "EEE, MMM d, yyyy"
    return f.string(from: d)
}
private func stampLabel(_ millis: Int64) -> String {
    let d = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.string(from: d)
}

// MARK: - Share sheet
private struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.excludedActivityTypes = [.assignToContact, .addToReadingList, .print]
        return vc
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Item-based share payload to guarantee fresh presentation each time
private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

// MARK: - Type classification (Android parity)
enum JournalTypeIOS: CaseIterable {
    case tenR, cage, gratitude, selfCare, blessingTally, free, css, dvs
}

private func pillCode(_ t: JournalTypeIOS) -> String {
    switch t {
    case .tenR: return "10R"
    case .cage: return "CTW"
    case .selfCare: return "SCW"
    case .blessingTally: return "3BT"
    case .gratitude: return "GRAT"
    case .free: return "FREE"
    case .css: return "CSS"
    case .dvs: return "DVS"
    }
}
private func displayName(_ t: JournalTypeIOS) -> String {
    switch t {
    case .tenR: return "10R Process"
    case .cage: return "Cage the Wolf"
    case .selfCare: return "Self Care Writing"
    case .blessingTally: return "Blessing Tally"
    case .gratitude: return "Gratitude"
    case .free: return "Free Flow"
    case .css: return "Current State Snapshot"
    case .dvs: return "Destiny Vision Snapshot"
    }
}
private func pillEmoji(_ t: JournalTypeIOS) -> String {
    switch t {
    case .css: return "🧭"
    case .dvs: return "🚀"
    default: return ""
    }
}

// --- Regex helpers (mirror Android heuristics) ---
private func looksLikeTenR(_ title: String, _ content: String) -> Bool {
    if hasPrefixCI(title.trimmingCharacters(in: .whitespacesAndNewlines), "10R Process") { return true }
    let pattern = #"(?m)^\s*1\s*[—-]\s*Recognize"#
    return content.range(of: pattern, options: .regularExpression) != nil
}
private func looksLikeCageTheWolf(_ content: String) -> Bool {
    let numbered = content.range(of: #"(?m)^\s*([1-6])\s*[—-]\s*(.+?)\s*$"#,
                                 options: .regularExpression) != nil
    if numbered {
        let titles = [
            "Set rules and claim a higher self",
            "Describing the Wolf",
            "Experience the conflict",
            "Caging the Wolf with refutation",
            "Connect with yourself",
            "Repeat sequences as needed"
        ]
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let l = line.trimmingCharacters(in: .whitespaces)
            if let idx = l.firstIndex(of: "—") ?? l.firstIndex(of: "-") {
                let t = l[l.index(after: idx)...].trimmingCharacters(in: .whitespaces)
                if titles.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                    return true
                }
            }
        }
    }
    if content.contains("## 1) Claiming Identity") &&
        content.contains("## 2) Identify the Wolf") &&
        content.contains("## 3) Train the Wolf") {
        return true
    }
    return false
}
private func looksLikeSelfCareWriting(_ content: String) -> Bool {
    return content.range(of: #"(?m)^\s*Self\s*Care\s*Writing\s*—"#,
                         options: .regularExpression) != nil
}
private func looksLikeCurrentStateSnapshot(_ title: String, _ content: String) -> Bool {
    let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if hasPrefixCI(t, "CSS:")
        || hasPrefixCI(t, "Current State Snapshot")
        || hasPrefixCI(t, "Current State — Snapshot")
        || t.compare("Current State", options: .caseInsensitive) == .orderedSame {
        return true
    }
    let hdr = #"(?m)^\s*🧭\s*Current State\s*—\s*Snapshot\s*\("#
    return content.range(of: hdr, options: .regularExpression) != nil
}
private func looksLikeDestinyVisionSnapshot(_ title: String, _ content: String) -> Bool {
    let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if hasPrefixCI(t, "DVS:")
        || hasPrefixCI(t, "Destiny Vision Snapshot")
        || hasPrefixCI(t, "Destiny Vision — Snapshot")
        || t.compare("Destiny Vision", options: .caseInsensitive) == .orderedSame {
        return true
    }
    let hdr = #"(?m)^\s*🚀\s*Destiny Vision\s*—\s*Snapshot\s*\("#
    return content.range(of: hdr, options: .regularExpression) != nil
}

private func classifyJournalType(_ e: JournalEntryIOS) -> JournalTypeIOS {
    let title = e.title
    let content = e.content

    if looksLikeCurrentStateSnapshot(title, content) { return .css }
    if looksLikeDestinyVisionSnapshot(title, content) { return .dvs }
    if looksLikeTenR(title, content) { return .tenR }
    if looksLikeCageTheWolf(content) { return .cage }
    if looksLikeSelfCareWriting(content) || hasPrefixCI(title, "Self Care Writing") { return .selfCare }
    if looksLikeBlessingTally(content) { return .blessingTally }
    if hasPrefixCI(title, "Gratitude") || content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Today, I am grateful for:") {
        return .gratitude
    }
    return .free
}

// MARK: - Sort key
private enum SortKey { case updated, created, title }

// MARK: - Main View
struct JournalLibrarySearchView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) private var dismiss

    // Data source injected by parent
    var allEntries: [JournalEntryIOS] = []

    // Callbacks
    var onOpen: (JournalEntryIOS) -> Void = { _ in }
    var onDelete: (_ ids: [Int64]) -> Void = { _ in }

    // Header actions
    @State private var showProfileEdit = false

    // Search / filters / sort
    @State private var query: String = ""
    @State private var sortKey: SortKey = .updated
    @State private var sortAsc: Bool = false // default: newest first (desc)
    @State private var activeTypes: [JournalTypeIOS: Bool] =
        Dictionary(uniqueKeysWithValues: JournalTypeIOS.allCases.map { ($0, false) })
    @State private var showTypeDialog = false

    // Selection & actions
    @State private var selected: Set<Int64> = []
    @State private var showDeleteConfirm = false
    @State private var sharePayload: SharePayload? = nil   // ← item-based share

    // MARK: Derived lists (lightweight)
    private var baseSorted: [JournalEntryIOS] {
        allEntries.sorted { $0.updatedAt > $1.updatedAt }
    }
    private var filteredByQuery: [JournalEntryIOS] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return baseSorted }
        return baseSorted.filter { e in
            e.title.localizedCaseInsensitiveContains(q) || e.content.localizedCaseInsensitiveContains(q)
        }
    }
    private var filteredByType: [JournalEntryIOS] {
        let anyOn = activeTypes.values.contains(true)
        if !anyOn { return filteredByQuery }
        return filteredByQuery.filter { e in (activeTypes[classifyJournalType(e)] ?? false) }
    }
    private var workingList: [JournalEntryIOS] {
        let list = filteredByType
        let sorted: [JournalEntryIOS]
        switch sortKey {
        case .updated:
            sorted = list.sorted { $0.updatedAt < $1.updatedAt }
        case .created:
            sorted = list.sorted { $0.dateMillis < $1.dateMillis }
        case .title:
            sorted = list.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return sortAsc ? sorted : Array(sorted.reversed())
    }

    private var allSelected: Bool { !workingList.isEmpty && selected.count == workingList.count }
    private var hasSelection: Bool { !selected.isEmpty }

    // MARK: - Body
    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            GeometryReader { geo in
                // Footer height in your app + dynamic bottom safe area
                let footerH: CGFloat = 48
                let safeBottom = geo.safeAreaInsets.bottom
                // Approx height of the action bar content
                let actionBarH: CGFloat = 120

                VStack(spacing: 0) {
                    SearchBar(query: $query)

                    TypeFilterPicker(
                        label: selectedTypeLabel(),
                        activeTypes: $activeTypes
                    )
                    .padding(.top, 8)

                    SortBar(sortKey: $sortKey, sortAsc: $sortAsc)
                        .padding(.top, 6)

                    SelectionBar(
                        count: workingList.count,
                        allSelected: allSelected,
                        hasSelection: hasSelection,
                        selectedCount: selected.count,
                        selectAll: { for e in workingList { selected.insert(e.id) } },
                        clearAll: { selected.removeAll() }
                    )

                    Divider().background(AppTheme.textSecondary.opacity(0.2))

                    ResultsList(
                        items: workingList,
                        selected: $selected,
                        hasSelection: hasSelection,
                        onOpen: onOpen
                    )
                    // Ensure last cell stays visible above the overlaid action bar + footer
                    .padding(.bottom, hasSelection ? (footerH + safeBottom + actionBarH) : (footerH + safeBottom))

                    Spacer(minLength: 8)
                }
                // Fixed action bar ABOVE footer and home indicator
                .overlay(alignment: .bottom) {
                    if hasSelection {
                        VStack(spacing: 0) {
                            Divider().background(AppTheme.textSecondary.opacity(0.25))
                            SelectionActions(
                                buildShareText: { chosen in buildShareText(from: chosen) },
                                chosen: workingList.filter { selected.contains($0.id) },
                                sharePayload: $sharePayload,
                                showDeleteConfirm: $showDeleteConfirm
                            )
                            .background(AppTheme.navy900.opacity(0.98))
                        }
                        .padding(.bottom, footerH + safeBottom + 12) // ← lifted above footer
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: hasSelection)
            }
        }
        // Toolbar
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Journal Library")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.bottom, 10)
            }
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
                .onTapGesture { showProfileEdit = true }
                .accessibilityLabel("Profile")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)

        // Journal tab re-tap → dismiss
        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
            dismiss()
        }

        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView().environmentObject(store)
        }
        // Item-based share presentation
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }

        // Delete confirmation
        .alert(
            "Delete selected entries?",
            isPresented: $showDeleteConfirm,
            actions: {
                Button("Delete", role: .destructive) {
                    let ids = Array(selected)
                    onDelete(ids)
                    selected.removeAll()
                }
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text("This will permanently delete \(selected.count) entr\(selected.count == 1 ? "y" : "ies").")
            }
        )
        .onChange(of: query) { _ in pruneSelection() }
        .onChange(of: sortKey) { _ in pruneSelection() }
        .onChange(of: sortAsc) { _ in pruneSelection() }
        .onChange(of: activeTypes) { _ in pruneSelection() }
    }

    // MARK: - Helpers
    private func selectedTypeLabel() -> String {
        let on = JournalTypeIOS.allCases.filter { activeTypes[$0] == true }
        if on.isEmpty { return "All types" }
        return on.map { pillCode($0) }.joined(separator: " · ")
    }

    private func pruneSelection() {
        let visible = Set(workingList.map { $0.id })
        selected = selected.filter { visible.contains($0) }
    }
}

// MARK: - Subviews (small & compiler-friendly)

private struct SearchBar: View {
    @Binding var query: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.textSecondary)
            TextField("Search by word…", text: $query)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceUI)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

private struct TypeFilterField: View {
    let label: String
    @Binding var showDialog: Bool
    var body: some View {
        Button { showDialog = true } label: {
            HStack {
                Text(label)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.surfaceUI)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
    }
}

private struct SortBar: View {
    @Binding var sortKey: SortKey
    @Binding var sortAsc: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("Sort By:")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.leading, 16)

            SortChip(title: "Updated", isOn: sortKey == .updated) { sortKey = .updated }
            SortChip(title: "Created", isOn: sortKey == .created) { sortKey = .created }
            SortChip(title: "Title",   isOn: sortKey == .title)   { sortKey = .title }

            Spacer(minLength: 8)

            Button { sortAsc.toggle() } label: {
                Image(systemName: sortAsc ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.appGreen)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppTheme.surfaceUI)
                            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .padding(.vertical, 4)
    }
}

private struct SelectionBar: View {
    let count: Int
    let allSelected: Bool
    let hasSelection: Bool
    let selectedCount: Int
    let selectAll: () -> Void
    let clearAll: () -> Void
    var body: some View {
        HStack {
            Button(action: selectAll) {
                Label("Select all (\(count))", systemImage: "checkmark.circle")
            }
            .disabled(count == 0 || allSelected)

            Button(action: clearAll) {
                Label("Clear", systemImage: "xmark.circle")
            }
            .disabled(!hasSelection)

            Spacer()

            Text(hasSelection ? "\(selectedCount) selected" : "No selection")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct ResultsList: View {
    let items: [JournalEntryIOS]
    @Binding var selected: Set<Int64>
    let hasSelection: Bool
    var onOpen: (JournalEntryIOS) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) { // tighter row spacing
                ForEach(items) { e in
                    JournalRow(
                        entry: e,
                        checked: selected.contains(e.id),
                        onToggleCheck: { isOn in
                            if isOn { selected.insert(e.id) } else { selected.remove(e.id) }
                        },
                        onTap: {
                            if hasSelection {
                                if selected.contains(e.id) { selected.remove(e.id) } else { selected.insert(e.id) }
                            } else {
                                onOpen(e)
                            }
                        }
                    )
                    .padding(.horizontal, 12)
                }
            }
            .padding(.top, 10)
        }
    }
}

private struct SelectionActions: View {
    var buildShareText: ([JournalEntryIOS]) -> String
    let chosen: [JournalEntryIOS]
    @Binding var sharePayload: SharePayload?
    @Binding var showDeleteConfirm: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button {
                    let text = buildShareText(chosen)
                    // Create a brand-new payload each time for reliable presentation
                    sharePayload = SharePayload(items: [text])
                } label: {
                    Label("Share selected", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete selected", systemImage: "trash")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Combines into a single .txt file and opens the share sheet.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Deletes permanently after confirmation.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Share text (Created + Updated, Android parity)
private func buildShareText(from entries: [JournalEntryIOS]) -> String {
    var blocks: [String] = []
    for e in entries {
        let t = e.title.isEmpty ? "(Untitled)" : e.title
        let created = stampLabel(e.dateMillis)
        let updated = stampLabel(e.updatedAt)
        let body = e.content

        let block = """
        Title: \(t)
        Date: \(created)
        Updated: \(updated)

        \(body)
        """
        blocks.append(block)
    }
    return blocks.joined(separator: "\n\n**************************************************\n\n")
}

// MARK: - Row
private struct JournalRow: View {
    let entry: JournalEntryIOS
    let checked: Bool
    let onToggleCheck: (Bool) -> Void
    let onTap: () -> Void

    var body: some View {
        let type = classifyJournalType(entry)

        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) { // tighter vertical spacing
                // Top: Type pill + checkbox
                HStack {
                    TypePillView(type: type)
                    Spacer()
                    Button {
                        onToggleCheck(!checked)
                    } label: {
                        Image(systemName: checked ? "checkmark.square.fill" : "square")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                checked ? .white : AppTheme.textSecondary, // lighter outline
                                checked ? AppTheme.appGreen : .clear
                            )
                            .font(.system(size: 24, weight: .medium)) // slimmer icon
                            .frame(width: 34, height: 34)              // smaller tap box
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Title
                Text(entry.title.isEmpty ? "(Untitled)" : entry.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                // Meta: Created • Updated
                Text("Created \(dateOnlyLabel(entry.dateMillis)) • Updated \(dateOnlyLabel(entry.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                // Snippet
                if !entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(entry.content)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 8)   // tighter card padding
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1) // softer shadow
            )
        }
        .buttonStyle(.plain)
    }
}

// Uniform, subdued pill color for ALL types (FREE style parity)
private struct TypePillView: View {
    let type: JournalTypeIOS
    var body: some View {
        let color: Color = AppTheme.textSecondary
        let label = pillCode(type)
        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(0.28), lineWidth: 1)
            )
    }
}

// MARK: - Sort chip
private struct SortChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isOn ? AppTheme.appGreen : AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isOn ? AppTheme.appGreen : AppTheme.textSecondary.opacity(0.4), lineWidth: isOn ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct TypeFilterPicker: View {
    let label: String
    @Binding var activeTypes: [JournalTypeIOS: Bool]

    @State private var showPopover = false

    var body: some View {
        Button { showPopover = true } label: {
            HStack {
                Text(label)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.surfaceUI)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .popover(isPresented: $showPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text("Filter by type")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Done") { showPopover = false }
                        .font(.callout.weight(.semibold))
                        .tint(AppTheme.appGreen)
                }
                .padding(.bottom, 4)

                // Select/Clear
                HStack(spacing: 10) {
                    Button {
                        JournalTypeIOS.allCases.forEach { activeTypes[$0] = true }
                    } label: {
                        Text("Select all")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.appGreen)

                    Button {
                        JournalTypeIOS.allCases.forEach { activeTypes[$0] = false }
                    } label: {
                        Text("Clear all")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    Spacer(minLength: 0)
                }

                // List of types (compact)
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(JournalTypeIOS.allCases, id: \.self) { t in
                            let isOn = activeTypes[t] == true
                            Button {
                                activeTypes[t] = !(activeTypes[t] ?? false)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(isOn ? .white : AppTheme.textPrimary,
                                                         isOn ? AppTheme.appGreen : .clear)
                                        .font(.title3)

                                    Text("\(pillCode(t)) — \(displayName(t))")
                                        .foregroundStyle(.white)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(AppTheme.navy900.opacity(0.6))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(minHeight: 160, maxHeight: 260) // keeps it compact
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.navy900) // blue-ish background per app
            )
            .presentationCompactAdaptation(.popover) // avoid full-screen sheet look
        }
    }
}
