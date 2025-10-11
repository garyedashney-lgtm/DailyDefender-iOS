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

// MARK: - Type classification
enum JournalTypeIOS: String {
    case tenR = "10R"
    case cage = "CTW"
    case gratitude = "GRAT"
    case free = "FREE"
}

private func classifyJournalType(_ e: JournalEntryIOS) -> JournalTypeIOS {
    let title = e.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let content = e.content

    // 10R: title or first header line
    if title.lowercased().hasPrefix("10r process") ||
        content.range(of: #"(?m)^\s*1\s*[—-]\s*Recognize"#, options: .regularExpression) != nil {
        return .tenR
    }

    // CTW: numbered lines w/ CTW titles OR legacy markdown headers
    let ctwTitles = [
        "Set rules and claim a higher self",
        "Describing the Wolf",
        "Experience the conflict",
        "Caging the Wolf with refutation",
        "Connect with yourself",
        "Repeat sequences as needed"
    ]
    if content.range(of: #"(?m)^\s*([1-6])\s*[—-]\s*(.+?)\s*$"#, options: .regularExpression) != nil {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            let l = line.trimmingCharacters(in: .whitespaces)
            if let idx = l.firstIndex(of: "—") ?? l.firstIndex(of: "-") {
                let t = l[l.index(after: idx)...].trimmingCharacters(in: .whitespaces)
                if ctwTitles.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                    return .cage
                }
            }
        }
    }
    if content.contains("## 1) Claiming Identity") &&
        content.contains("## 2) Identify the Wolf") &&
        content.contains("## 3) Train the Wolf") {
        return .cage
    }

    // Gratitude
    if title.lowercased().hasPrefix("gratitude") ||
        content.trimmingCharacters(in: .whitespacesAndNewlines)
            .hasPrefix("Today, I am grateful for:") {
        return .gratitude
    }

    return .free
}

private func formatDateShort(_ millis: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
    let f = DateFormatter()
    f.dateFormat = "EEE, MMM d, yyyy"
    return f.string(from: date)
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

// MARK: - View
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

    // Search / selection state
    @State private var query: String = ""
    @State private var selected: Set<Int64> = []
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    private var filtered: [JournalEntryIOS] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return allEntriesSorted }
        return allEntriesSorted.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.content.localizedCaseInsensitiveContains(q)
        }
    }
    private var allEntriesSorted: [JournalEntryIOS] {
        allEntries.sorted { $0.dateMillis > $1.dateMillis }
    }
    private var allSelected: Bool { !filtered.isEmpty && selected.count == filtered.count }
    private var hasSelection: Bool { !selected.isEmpty }

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.textSecondary)
                    TextField("Search journals…", text: $query)
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

                // Select controls
                HStack {
                    Button {
                        filtered.forEach { selected.insert($0.id) }
                    } label: {
                        Label("Select all (\(filtered.count))", systemImage: "checkmark.circle")
                    }
                    .disabled(filtered.isEmpty || allSelected)

                    Button {
                        selected.removeAll()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .disabled(!hasSelection)

                    Spacer()

                    Text(hasSelection ? "\(selected.count) selected" : "No selection")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider().background(AppTheme.textSecondary.opacity(0.2))

                // Results list (scrollable, efficient)
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { e in
                            JournalRow(
                                entry: e,
                                checked: selected.contains(e.id),
                                onToggleCheck: { isOn in
                                    if isOn { selected.insert(e.id) } else { selected.remove(e.id) }
                                },
                                onTap: {
                                    if hasSelection {
                                        if selected.contains(e.id) { selected.remove(e.id) }
                                        else { selected.insert(e.id) }
                                    } else {
                                        onOpen(e)
                                    }
                                }
                            )
                            .padding(.horizontal, 12)
                        }

                        if hasSelection {
                            // Selection actions
                            HStack(spacing: 16) {
                                Button {
                                    // Build combined .txt
                                    let chosen = filtered.filter { selected.contains($0.id) }
                                    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
                                    var text = ""
                                    for (idx, e) in chosen.enumerated() {
                                        let d = Date(timeIntervalSince1970: TimeInterval(e.dateMillis)/1000)
                                        text += "Title: \(e.title.isEmpty ? "(Untitled)" : e.title)\n"
                                        text += "Date: \(df.string(from: d))\n\n"
                                        text += e.content
                                        if idx < chosen.count - 1 {
                                            text += "\n\n**************************************************\n\n"
                                        }
                                    }
                                    shareItems = [text]
                                    showShareSheet = true
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

                            // Helper notes
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

                        Spacer(minLength: 8)
                    }
                    .padding(.top, 10)
                }
            }
        }
        // === Toolbar ===
        .toolbar {
            // Keep the system back arrow; only provide center + trailing.
            ToolbarItem(placement: .principal) {
                Text("Journal Library")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.navy900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)

        // 🔔 Dismiss this screen when Journal tab is re-tapped
        .onReceive(NotificationCenter.default.publisher(for: .JumpToJournalHome)) { _ in
            dismiss()
        }

        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView().environmentObject(store)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }

        // Delete confirmation
        .alert("Delete selected entries?",
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
               })
    }
}

// MARK: - Row (iOS 17-safe checkbox)
private struct JournalRow: View {
    let entry: JournalEntryIOS
    let checked: Bool
    let onToggleCheck: (Bool) -> Void
    let onTap: () -> Void

    var body: some View {
        let type = classifyJournalType(entry)

        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Top: date + checkbox
                HStack {
                    Text(formatDateShort(entry.dateMillis))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Button {
                        onToggleCheck(!checked)
                    } label: {
                        Image(systemName: checked ? "checkmark.square.fill" : "square")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                checked ? .white : AppTheme.textPrimary,
                                checked ? AppTheme.appGreen : .clear
                            )
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }

                // Title + Type pill
                HStack(spacing: 8) {
                    Text(entry.title.isEmpty ? "(Untitled)" : entry.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    TypePillView(type: type)
                }

                // Content preview
                if !entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(entry.content)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceUI)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TypePillView: View {
    let type: JournalTypeIOS
    var body: some View {
        let (label, color): (String, Color) = {
            switch type {
            case .tenR: return ("10R", AppTheme.appGreen)
            case .cage: return ("CTW", .teal)
            case .gratitude: return ("GRAT", .yellow)
            case .free: return ("FREE", AppTheme.textSecondary)
            }
        }()
        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
    }
}
