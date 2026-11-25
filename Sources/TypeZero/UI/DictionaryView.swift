import SwiftUI
import AppKit

// MARK: - Personal Dictionary View (List-First + Modal Import & Quick Add)

struct DictionaryView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var lexiconStore: PersonalLexiconStore

    @State private var searchFilter: String = ""
    @State private var selectedCategoryFilter: LexiconCategory? = nil
    @State private var hoveredID: UUID? = nil

    @State private var showAddSheet: Bool = false
    @State private var showImportSheet: Bool = false

    @State private var editingID: UUID? = nil
    @State private var editTerm: String = ""
    @State private var editAliases: String = ""
    @State private var editCategory: LexiconCategory = .person
    @State private var editPinnedCore: Bool = false

    @State private var isBatchMode: Bool = false
    @State private var selectedIDs: Set<UUID> = []

    private var filteredEntries: [LexiconEntry] {
        lexiconStore.entries.filter { entry in
            if let cat = selectedCategoryFilter, entry.category != cat {
                return false
            }
            let q = searchFilter.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return true }
            return entry.term.localizedCaseInsensitiveContains(q)
                || entry.phoneticKey.localizedCaseInsensitiveContains(q)
                || entry.aliases.contains(where: { $0.localizedCaseInsensitiveContains(q) })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBar
            filterToolbar
            entriesTableCard
        }
        .sheet(isPresented: $showAddSheet) {
            AddLexiconEntrySheet(
                onAdd: { term, aliases, category, isCore in
                    lexiconStore.upsert(
                        term: term,
                        aliases: aliases,
                        category: category,
                        weight: isCore ? 10 : 8
                    )
                    appState.statusBanner = "已添加词条「\(term)」"
                    showAddSheet = false
                },
                onCancel: { showAddSheet = false }
            )
            .preferredColorScheme(appState.llmConfig.appearance.colorScheme)
        }
        .sheet(isPresented: $showImportSheet) {
            SmartCorpusImportSheet(
                appState: appState,
                lexiconStore: lexiconStore,
                onDismiss: { showImportSheet = false }
            )
            .preferredColorScheme(appState.llmConfig.appearance.colorScheme)
        }
    }

    // MARK: Header Bar (Search + Import + Add Term)

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("词库")
                    .font(TZFont.title(24))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text("\(lexiconStore.entries.count)")
                    .font(TZFont.mono(12, weight: .semibold))
                    .foregroundStyle(TZTheme.inkMuted)
            }

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(TZTheme.inkMuted)
                TextField("搜索词条、误听词、拼音…", text: $searchFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(TZTheme.inkPrimary)
                if !searchFilter.isEmpty {
                    Button { searchFilter = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(TZTheme.inkMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 215)
            .background(TZTheme.recessedWell)
            .clipShape(RoundedRectangle(cornerRadius: 9.5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9.5, style: .continuous).strokeBorder(TZTheme.hairline, lineWidth: 1))

            Button {
                showImportSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                    Text("智能导入")
                }
            }
            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("添加词条")
                }
            }
            .buttonStyle(TZPrimaryButtonStyle(compact: true, capsule: true))
        }
    }

    // MARK: Category Filter Pills & Batch Action

    private var filterToolbar: some View {
        HStack(spacing: 7) {
            categoryPill(title: "全部", count: lexiconStore.entries.count, active: selectedCategoryFilter == nil) {
                selectedCategoryFilter = nil
            }

            ForEach(LexiconCategory.allCases) { cat in
                let cnt = lexiconStore.entries.filter { $0.category == cat }.count
                if cnt > 0 || selectedCategoryFilter == cat {
                    categoryPill(title: shortCategoryName(cat), count: cnt, active: selectedCategoryFilter == cat) {
                        selectedCategoryFilter = (selectedCategoryFilter == cat) ? nil : cat
                    }
                }
            }

            Spacer()

            if isBatchMode && !selectedIDs.isEmpty {
                Button {
                    let count = selectedIDs.count
                    lexiconStore.removeBatch(ids: selectedIDs)
                    selectedIDs.removeAll()
                    appState.statusBanner = "已删除 \(count) 个词条"
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill").font(.system(size: 10.5))
                        Text("删除 (\(selectedIDs.count))")
                    }
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, destructive: true, capsule: true))
            }

            Button(isBatchMode ? "完成" : "批量管理") {
                isBatchMode.toggle()
                if !isBatchMode { selectedIDs.removeAll() }
            }
            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
        }
    }

    private func categoryPill(title: String, count: Int, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4.5) {
                Text(title)
                    .font(.system(size: 11.5, weight: active ? .semibold : .medium))
                Text("\(count)")
                    .font(TZFont.mono(10, weight: .semibold))
                    .opacity(active ? 0.85 : 0.65)
            }
            .foregroundStyle(active ? Color.white : TZTheme.inkSecondary)
            .padding(.horizontal, 10.5)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(active ? TZTheme.accent : TZTheme.cardBg)
            )
            .overlay(
                Capsule()
                    .strokeBorder(active ? Color.clear : TZTheme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Entries List Card

    private var entriesTableCard: some View {
        TZGroupedSection(title: "本地热词索引 · 0.5ms 模糊近音召回") {
            Text("仅存于本机")
                .font(TZFont.mono(10.5))
                .foregroundStyle(TZTheme.inkMuted)
        } content: {
            if filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 20))
                        .foregroundStyle(TZTheme.inkMuted)
                    Text(searchFilter.isEmpty ? "词库暂无词条" : "未找到匹配词条")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("点击右上角「+ 添加词条」或「智能导入」会议纪要，让专业术语 100% 精准识别。")
                        .font(.system(size: 12))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 38)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { idx, item in
                        if editingID == item.id {
                            inlineEditorRow(item)
                        } else {
                            displayRow(item)
                        }
                        if idx < filteredEntries.count - 1 {
                            TZHairline(leadingInset: 16)
                        }
                    }
                }
            }
        }
    }

    private func displayRow(_ item: LexiconEntry) -> some View {
        let isHovered = (hoveredID == item.id)

        return HStack(spacing: 10) {
            if isBatchMode {
                Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(selectedIDs.contains(item.id) ? TZTheme.accent : TZTheme.inkMuted)
            }

            Text(item.term)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(TZTheme.inkPrimary)

            if item.weight >= 9 {
                Text("★ 核心")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TZTheme.amber)
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 2)
                    .background(TZTheme.amberSoft)
                    .clipShape(Capsule())
            }

            Text(item.phoneticKey)
                .font(TZFont.mono(10.5))
                .foregroundStyle(TZTheme.inkMuted)
                .lineLimit(1)

            if !item.aliases.isEmpty {
                HStack(spacing: 4) {
                    ForEach(item.aliases.prefix(4), id: \.self) { al in
                        Text(al)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TZTheme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(TZTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
                    }
                    if item.aliases.count > 4 {
                        Text("+\(item.aliases.count - 4)")
                            .font(TZFont.mono(10))
                            .foregroundStyle(TZTheme.inkMuted)
                    }
                }
            }

            Spacer()

            Text(shortCategoryName(item.category))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(TZTheme.inkSecondary)
                .padding(.horizontal, 7.5)
                .padding(.vertical, 2.5)
                .background(TZTheme.recessedWell)
                .clipShape(Capsule())

            if isHovered && !isBatchMode {
                HStack(spacing: 4) {
                    Button { beginInlineEdit(item) } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TZTheme.inkSecondary)
                            .frame(width: 24, height: 24)
                            .background(TZTheme.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(TZTheme.hairline, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)

                    Button { lexiconStore.remove(id: item.id) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(TZTheme.crimson)
                            .frame(width: 24, height: 24)
                            .background(TZTheme.crimsonSoft.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10.5)
        .background(isHovered ? TZTheme.hoverFill : Color.clear)
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.10)) {
                hoveredID = inside ? item.id : (hoveredID == item.id ? nil : hoveredID)
            }
        }
        .onTapGesture {
            if isBatchMode {
                if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) }
                else { selectedIDs.insert(item.id) }
            } else {
                beginInlineEdit(item)
            }
        }
    }

    private func inlineEditorRow(_ item: LexiconEntry) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("编辑词条")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TZTheme.accent)
                Spacer()
                Toggle("★ 核心常驻（优先热词）", isOn: $editPinnedCore)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(TZTheme.inkPrimary)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("标准词").font(.system(size: 11)).foregroundStyle(TZTheme.inkSecondary)
                    TextField("标准词", text: $editTerm)
                        .tzRecessedInput(compact: true)
                        .onSubmit { commitInlineEdit(item.id) }
                }
                .frame(width: 180)

                VStack(alignment: .leading, spacing: 4) {
                    Text("常见误听词（逗号分隔）").font(.system(size: 11)).foregroundStyle(TZTheme.inkSecondary)
                    TextField("误听词1，误听词2…", text: $editAliases)
                        .tzRecessedInput(compact: true)
                        .onSubmit { commitInlineEdit(item.id) }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("分类").font(.system(size: 11)).foregroundStyle(TZTheme.inkSecondary)
                    Picker("", selection: $editCategory) {
                        ForEach(LexiconCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }
            }

            HStack(spacing: 8) {
                Button {
                    editingID = nil
                    lexiconStore.remove(id: item.id)
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, destructive: true))

                Spacer()

                Button("取消") { editingID = nil }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))

                Button("保存") { commitInlineEdit(item.id) }
                    .buttonStyle(TZPrimaryButtonStyle(compact: true, capsule: false))
            }
        }
        .padding(14)
        .background(TZTheme.accentSoft.opacity(0.45))
    }

    // MARK: Actions

    private func beginInlineEdit(_ item: LexiconEntry) {
        editingID = item.id
        editTerm = item.term
        editAliases = item.aliases.joined(separator: "，")
        editCategory = item.category
        editPinnedCore = item.weight >= 9
    }

    private func commitInlineEdit(_ id: UUID) {
        let parsedAliases = editAliases
            .components(separatedBy: CharacterSet(charactersIn: ",，/、;；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        lexiconStore.updateEntry(
            id: id,
            newTerm: editTerm,
            newAliases: parsedAliases,
            newCategory: editCategory,
            newWeight: editPinnedCore ? 10 : 7
        )
        appState.statusBanner = "已更新词条「\(editTerm)」"
        editingID = nil
    }

    private func shortCategoryName(_ cat: LexiconCategory) -> String {
        switch cat {
        case .person: return "人名"
        case .project: return "项目"
        case .finance: return "商业"
        case .memo: return "纪要"
        case .browser: return "浏览"
        case .autoLearned: return "自学习"
        }
    }
}

// MARK: - Add Single Lexicon Entry Modal Sheet

private struct AddLexiconEntrySheet: View {
    let onAdd: (String, [String], LexiconCategory, Bool) -> Void
    let onCancel: () -> Void

    @State private var term: String = ""
    @State private var aliases: String = ""
    @State private var category: LexiconCategory = .project
    @State private var isCore: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("添加词条")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TZTheme.inkPrimary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TZTheme.inkMuted)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("标准词（人名 / 产品 / 术语）")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
                TextField("例如：DeepSeek / TypeZero", text: $term)
                    .tzRecessedInput()
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("常见误听词（选填，逗号分隔）")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
                TextField("例如：迪普西克，深度求索", text: $aliases)
                    .tzRecessedInput()
            }

            HStack {
                Picker("分类", selection: $category) {
                    ForEach(LexiconCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .frame(width: 170)

                Spacer()

                Toggle("★ 核心常驻", isOn: $isCore)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                Button("添加") {
                    let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanTerm.isEmpty else { return }
                    let parsed = aliases
                        .components(separatedBy: CharacterSet(charactersIn: ",，/、;；"))
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    onAdd(cleanTerm, parsed, category, isCore)
                }
                .buttonStyle(TZPrimaryButtonStyle(compact: true, capsule: false))
                .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(width: 410)
        .background(TZTheme.canvasBg)
    }
}

// MARK: - Smart Corpus Import Modal Sheet

private struct SmartCorpusImportSheet: View {
    @ObservedObject var appState: AppState
    @ObservedObject var lexiconStore: PersonalLexiconStore
    let onDismiss: () -> Void

    @State private var rawCorpusInput: String = ""
    @State private var targetCategory: LexiconCategory = .project
    @State private var isDistilling: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("智能导入词库")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("粘贴会议纪要、名单，或直接从本机文档与浏览记录提取专有名词")
                        .font(.system(size: 12))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TZTheme.inkMuted)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    panel.prompt = "扫描文件夹提取词条"
                    if panel.runModal() == .OK, let dir = panel.url {
                        let added = lexiconStore.importFromMarkdownFolder(dir, maxEntries: 120)
                        appState.statusBanner = "扫描文件夹完成：新增 \(added) 个高频词条"
                        onDismiss()
                    }
                } label: {
                    Label("扫描本地纪要目录", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true))

                Button {
                    let added = lexiconStore.importFromLocalBrowserHistory(maxEntries: 60)
                    appState.statusBanner = "已从浏览历史提取 \(added) 个专有词"
                    onDismiss()
                } label: {
                    Label("提取浏览高频词", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true))
            }

            ZStack(alignment: .topLeading) {
                if rawCorpusInput.isEmpty {
                    Text("粘贴会议纪要、PRD 文档或同事人名列表…")
                        .font(.system(size: 12.5))
                        .foregroundStyle(TZTheme.inkMuted)
                        .padding(11)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $rawCorpusInput)
                    .font(.system(size: 13))
                    .foregroundStyle(TZTheme.inkPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(height: 130)
            }
            .background(TZTheme.recessedWell)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(TZTheme.hairline, lineWidth: 1))

            HStack(spacing: 8) {
                Picker("", selection: $targetCategory) {
                    ForEach(LexiconCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .labelsHidden()
                .frame(width: 112)

                Spacer()

                Button("按行导入") {
                    let lines = rawCorpusInput
                        .components(separatedBy: CharacterSet(charactersIn: "\n,，、;；"))
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { $0.count >= 2 }
                        .map { (term: $0, aliases: [String](), category: targetCategory) }
                    let count = lexiconStore.bulkUpsert(lines)
                    appState.statusBanner = "批量导入 \(count) 个词条"
                    onDismiss()
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true))
                .disabled(rawCorpusInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(isDistilling ? "提纯中…" : "AI 自动提纯") {
                    guard !rawCorpusInput.isEmpty, !isDistilling else { return }
                    isDistilling = true
                    let text = rawCorpusInput
                    Task {
                        await appState.distillPastedCorpus(text)
                        isDistilling = false
                        onDismiss()
                    }
                }
                .buttonStyle(TZAccentButtonStyle(compact: true, capsule: false))
                .disabled(isDistilling || rawCorpusInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 480)
        .background(TZTheme.canvasBg)
    }
}
