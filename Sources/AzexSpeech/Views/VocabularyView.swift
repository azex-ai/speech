import SwiftUI

struct VocabularyView: View {
    enum VocabTab: String, CaseIterable {
        case personal = "Personal"
        case crypto = "Crypto"
        case ai = "AI"
    }

    @State private var selectedTab: VocabTab = .personal
    @State private var searchText = ""
    @State private var entries: [(id: UUID, source: String, correction: String)] = []
    @State private var editingID: UUID?
    @State private var editSource = ""
    @State private var editCorrection = ""
    @State private var sortAscending = true

    private let vocabManager = VocabManager()

    private var isReadOnly: Bool {
        selectedTab != .personal
    }

    private var filteredEntries: [(id: UUID, source: String, correction: String)] {
        let sorted = entries.sorted { a, b in
            sortAscending ? a.source.localizedCaseInsensitiveCompare(b.source) == .orderedAscending
                : a.source.localizedCaseInsensitiveCompare(b.source) == .orderedDescending
        }
        if searchText.isEmpty { return sorted }
        let query = searchText.lowercased()
        return sorted.filter {
            $0.source.lowercased().contains(query) || $0.correction.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Vocabulary")
                .font(.title2.bold())
                .foregroundStyle(AzexTheme.textPrimary)

            // Tab switcher
            Picker("", selection: $selectedTab) {
                ForEach(VocabTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTab) { _, _ in
                loadEntries()
            }

            // Search + actions bar
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AzexTheme.textSecondary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(AzexTheme.textPrimary)
                }
                .padding(6)
                .background(AzexTheme.bgInput)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(AzexTheme.border, lineWidth: 1)
                )

                if !isReadOnly {
                    Button(action: addEntry) {
                        Image(systemName: "plus")
                            .foregroundStyle(AzexTheme.accent)
                    }
                    .buttonStyle(.borderless)
                    .help("Add new entry")
                }
            }

            // Table header
            HStack(spacing: 0) {
                Button(action: { sortAscending.toggle() }) {
                    HStack(spacing: 4) {
                        Text("Source")
                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AzexTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Correction")
                    .foregroundStyle(AzexTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !isReadOnly {
                    // Tag + delete column space
                    Text("Tag")
                        .foregroundStyle(AzexTheme.textTertiary)
                        .frame(width: 80, alignment: .leading)

                    Spacer().frame(width: 32)
                }
            }
            .font(.caption)
            .padding(.horizontal, 8)

            // Entry list or empty state
            if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "book")
                        .font(.system(size: 36))
                        .foregroundStyle(AzexTheme.textTertiary)
                    Text(searchText.isEmpty ? "还没有词汇" : "没有匹配 \"\(searchText)\" 的结果")
                        .font(.callout)
                        .foregroundStyle(AzexTheme.textSecondary)
                    if searchText.isEmpty && !isReadOnly {
                        Text("点击 + 手动添加，或使用语音输入后编辑自动学习")
                            .font(.caption)
                            .foregroundStyle(AzexTheme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                            entryRow(entry)
                                .background(index.isMultiple(of: 2) ? AzexTheme.bgCard : AzexTheme.bg)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(AzexTheme.border, lineWidth: 1)
                    )
                }
            }

            // Footer
            HStack {
                Text("\(filteredEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(AzexTheme.textTertiary)

                if isReadOnly {
                    Spacer()
                    Text("只读")
                        .font(.caption2)
                        .foregroundStyle(AzexTheme.textTertiary)
                }
            }
        }
        .padding(20)
        .background(AzexTheme.bg)
        .onAppear { loadEntries() }
        .onReceive(NotificationCenter.default.publisher(for: .vocabDidUpdate)) { _ in
            loadEntries()
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: (id: UUID, source: String, correction: String)) -> some View {
        let isEditing = editingID == entry.id

        HStack(spacing: 0) {
            if isEditing && !isReadOnly {
                TextField("source", text: $editSource)
                    .textFieldStyle(.plain)
                    .padding(4)
                    .background(AzexTheme.bgInput)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("correction", text: $editCorrection)
                    .textFieldStyle(.plain)
                    .padding(4)
                    .background(AzexTheme.bgInput)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Save") {
                    saveEdit(entry.id)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AzexTheme.accent)
                .frame(width: 80)

                Button(action: { editingID = nil }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(AzexTheme.textSecondary)
                }
                .buttonStyle(.borderless)
                .frame(width: 32)
            } else {
                Text(entry.source)
                    .foregroundStyle(AzexTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(entry.correction)
                    .foregroundStyle(AzexTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !isReadOnly {
                    Text("learned")
                        .font(.caption2)
                        .foregroundStyle(AzexTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AzexTheme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .frame(width: 80, alignment: .leading)

                    Button(action: { deleteEntry(entry.id) }) {
                        Image(systemName: "trash")
                            .foregroundStyle(AzexTheme.error.opacity(0.7))
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 32)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(editingID == entry.id ? AzexTheme.bgCardHover : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReadOnly && editingID != entry.id {
                editingID = entry.id
                editSource = entry.source
                editCorrection = entry.correction
            }
        }
    }

    private func loadEntries() {
        vocabManager.loadAll()
        editingID = nil

        let corrections: [String: String]
        switch selectedTab {
        case .personal:
            corrections = vocabManager.personalVocab.corrections
        case .crypto:
            corrections = vocabManager.domainCryptoVocab.corrections
        case .ai:
            corrections = vocabManager.domainAIVocab.corrections
        }

        entries = corrections.map { (id: UUID(), source: $0.key, correction: $0.value) }
    }

    private func addEntry() {
        let newEntry = (id: UUID(), source: "", correction: "")
        entries.insert(newEntry, at: 0)
        editingID = newEntry.id
        editSource = ""
        editCorrection = ""
    }

    private func saveEdit(_ id: UUID) {
        let trimmedSource = editSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCorrection = editCorrection.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSource.isEmpty, !trimmedCorrection.isEmpty else {
            // Remove empty entries
            entries.removeAll { $0.id == id }
            editingID = nil
            return
        }

        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx] = (id: id, source: trimmedSource, correction: trimmedCorrection)
        }

        // Rebuild and persist the full corrections dict from entries
        persistAllEntries()
        editingID = nil
    }

    private func deleteEntry(_ id: UUID) {
        entries.removeAll { $0.id == id }
        persistAllEntries()
    }

    /// Rebuild personal vocab from current entries and write to disk
    private func persistAllEntries() {
        var corrections: [String: String] = [:]
        for entry in entries where !entry.source.isEmpty && !entry.correction.isEmpty {
            corrections[entry.source] = entry.correction
        }

        var vocab = vocabManager.personalVocab
        vocab.corrections = corrections

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let path = base.appendingPathComponent("AzexSpeech/my-vocab.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(vocab) {
            try? data.write(to: path, options: .atomic)
        }
        NotificationCenter.default.post(name: .vocabDidUpdate, object: nil)
    }
}
