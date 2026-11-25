import SwiftUI

// MARK: - History View (Chronological Grouped Native Feed + Hover Frosted Action Pill)

struct HistoryView: View {
    @ObservedObject var appState: AppState

    @State private var searchQuery: String = ""
    @State private var hoveredRecordID: UUID? = nil
    @State private var copiedRecordID: UUID? = nil
    @State private var expandedRawIDs: Set<UUID> = []
    @State private var lexiconFixRecord: DictationRecord? = nil
    @State private var fixTerm: String = ""
    @State private var fixAlias: String = ""

    private var filteredRecords: [DictationRecord] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return appState.history }
        return appState.history.filter { rec in
            rec.polishedText.localizedCaseInsensitiveContains(q)
                || rec.rawTranscript.localizedCaseInsensitiveContains(q)
                || rec.targetAppName.localizedCaseInsensitiveContains(q)
        }
    }

    private var groupedSections: [(title: String, items: [DictationRecord])] {
        let cal = Calendar.current
        var today: [DictationRecord] = []
        var yesterday: [DictationRecord] = []
        var earlier: [DictationRecord] = []

        for rec in filteredRecords {
            if cal.isDateInToday(rec.timestamp) {
                today.append(rec)
            } else if cal.isDateInYesterday(rec.timestamp) {
                yesterday.append(rec)
            } else {
                earlier.append(rec)
            }
        }

        var out: [(String, [DictationRecord])] = []
        if !today.isEmpty { out.append(("今天", today)) }
        if !yesterday.isEmpty { out.append(("昨天", yesterday)) }
        if !earlier.isEmpty { out.append(("更早", earlier)) }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerBar

            if groupedSections.isEmpty {
                emptyStateCard
            } else {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(groupedSections, id: \.title) { section in
                        TZGroupedSection(title: "\(section.title) · \(section.items.count)") {
                            ForEach(Array(section.items.enumerated()), id: \.element.id) { idx, rec in
                                historyRow(rec)
                                if idx < section.items.count - 1 {
                                    TZHairline(leadingInset: 52)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $lexiconFixRecord) { rec in
            QuickLexiconFixSheet(
                record: rec,
                term: $fixTerm,
                alias: $fixAlias,
                onSave: { term, alias in
                    appState.lexiconStore.upsert(
                        term: term,
                        aliases: alias.isEmpty ? [] : [alias],
                        category: .project,
                        weight: 9
                    )
                    appState.statusBanner = "已加入词库纠偏：\(term)"
                    lexiconFixRecord = nil
                },
                onCancel: {
                    lexiconFixRecord = nil
                }
            )
            .preferredColorScheme(appState.llmConfig.appearance.colorScheme)
        }
    }

    // MARK: Header + Inline Search

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("历史")
                    .font(TZFont.title(24))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text("\(appState.history.count)")
                    .font(TZFont.mono(12, weight: .semibold))
                    .foregroundStyle(TZTheme.inkMuted)
            }

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TZTheme.inkMuted)
                TextField("搜索口述记录、应用…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(TZTheme.inkPrimary)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(TZTheme.inkMuted)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("⌘F")
                        .font(TZFont.mono(10, weight: .semibold))
                        .foregroundStyle(TZTheme.inkMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(TZTheme.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 4.5, style: .continuous).strokeBorder(TZTheme.hairline, lineWidth: 0.8))
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6.5)
            .frame(width: 250)
            .background(TZTheme.recessedWell)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(TZTheme.hairline, lineWidth: 1))
        }
    }

    // MARK: History Row

    private func historyRow(_ rec: DictationRecord) -> some View {
        let isHovered = (hoveredRecordID == rec.id)
        let isExpandedRaw = expandedRawIDs.contains(rec.id)
        let hasDiff = rec.rawTranscript != rec.polishedText

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                TZAppIconBadge(appName: rec.targetAppName)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(formatTimestamp(rec.timestamp))
                            .font(TZFont.mono(11))
                            .foregroundStyle(TZTheme.inkMuted)

                        Text(rec.targetAppName.isEmpty ? "外部应用" : rec.targetAppName)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)

                        if rec.mode == .rewriteSelection {
                            Text("改写")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(TZTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(TZTheme.accentSoft)
                                .clipShape(Capsule())
                        }

                        Text("\(rec.polishLatencyMs) ms · \(String(format: "%.1fs", rec.durationSeconds))")
                            .font(TZFont.mono(10))
                            .foregroundStyle(TZTheme.inkMuted)

                        Spacer()
                    }

                    Text(rec.polishedText)
                        .font(.system(size: 13.5))
                        .lineSpacing(3.6)
                        .foregroundStyle(TZTheme.inkPrimary)
                        .textSelection(.enabled)
                }
            }

            if isExpandedRaw && hasDiff {
                HStack(alignment: .top, spacing: 8) {
                    Text("声学原稿")
                        .font(TZFont.mono(10, weight: .semibold))
                        .foregroundStyle(TZTheme.inkMuted)
                        .padding(.top, 1.5)
                    Text(rec.rawTranscript)
                        .font(.system(size: 12))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TZTheme.recessedWell)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.leading, 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12.5)
        .background(isHovered ? TZTheme.hoverFill : Color.clear)
        .overlay(alignment: .topTrailing) {
            if isHovered || copiedRecordID == rec.id {
                HStack(spacing: 3) {
                    rowActionButton(
                        title: copiedRecordID == rec.id ? "已复制" : "复制",
                        icon: copiedRecordID == rec.id ? "checkmark" : "doc.on.doc",
                        accent: true
                    ) {
                        ContextInjector.saveToSafetyClipboard(rec.polishedText)
                        copiedRecordID = rec.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                            if copiedRecordID == rec.id { copiedRecordID = nil }
                        }
                    }

                    if hasDiff {
                        rowActionButton(
                            title: "原声",
                            icon: isExpandedRaw ? "chevron.up" : "waveform",
                            accent: isExpandedRaw
                        ) {
                            withAnimation(.easeOut(duration: 0.14)) {
                                if isExpandedRaw { expandedRawIDs.remove(rec.id) }
                                else { expandedRawIDs.insert(rec.id) }
                            }
                        }
                    }

                    rowActionButton(title: "纠偏", icon: "book.closed", accent: false) {
                        fixTerm = ""
                        fixAlias = ""
                        lexiconFixRecord = rec
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            appState.removeHistoryRecord(id: rec.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(TZTheme.crimson.opacity(0.85))
                            .frame(width: 24, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("删除此条记录")
                }
                .padding(4)
                .background(.ultraThinMaterial)
                .background(TZTheme.cardElevated.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(TZTheme.strongLine, lineWidth: 0.85)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 9, x: 0, y: 3)
                .padding(.top, 9)
                .padding(.trailing, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.12)) {
                hoveredRecordID = inside ? rec.id : (hoveredRecordID == rec.id ? nil : hoveredRecordID)
            }
        }
    }

    private func rowActionButton(title: String, icon: String, accent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3.5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(accent ? TZTheme.accent : TZTheme.inkSecondary)
            .padding(.horizontal, 7.5)
            .padding(.vertical, 4)
            .background(accent ? TZTheme.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: searchQuery.isEmpty ? "clock" : "magnifyingglass")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(TZTheme.inkMuted)
            Text(searchQuery.isEmpty ? "尚无口述历史" : "没有找到匹配「\(searchQuery)」的记录")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TZTheme.inkPrimary)
            if searchQuery.isEmpty {
                Text("按下 \(appState.activeTriggerCompactLabel) 开始语音输入，所有原声与成稿都会保存在本地。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .tzElevatedCard(cornerRadius: 14, padding: 16)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) || cal.isDateInYesterday(date) {
            return Self.hhmmFormatter.string(from: date)
        }
        return Self.dateTimeFormatter.string(from: date)
    }

    private static let hhmmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MM/dd HH:mm"
        return f
    }()
}
