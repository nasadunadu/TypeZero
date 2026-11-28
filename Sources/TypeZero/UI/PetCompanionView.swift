import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Live Embedded Vector Cat Preview Stage (Supports Both KuroCat & Clack-Clack Styles!)

private final class PetInlinePreviewNSView: NSView {
    let physics = CatPhysics()
    private var animTimer: Timer?
    private var lastTick: CFTimeInterval = CACurrentMediaTime()

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        if window != nil {
            startPreviewLoop()
        } else {
            stopPreviewLoop()
        }
    }

    deinit {
        animTimer?.invalidate()
    }

    private func startPreviewLoop() {
        guard animTimer == nil else { return }
        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = CACurrentMediaTime()
            let dt = CGFloat(min(0.08, max(0.001, now - self.lastTick)))
            self.lastTick = now
            let cursorPt = CGPoint(x: 180 + sin(now * 1.3) * 55, y: 170 + cos(now * 0.9) * 20)
            let idleInput = ScriptedFrameInput(
                now: now,
                activeKeys: self.physics.virtualActiveKeys,
                orderedKeys: self.physics.virtualOrderedKeys,
                mouseScreenPos: cursorPt,
                mouseVelocity: .zero,
                leftMouseDown: false,
                rightMouseDown: false,
                lastMouseMoveTime: now,
                lastMouseClickTime: 0,
                lastKeyActivityTime: self.physics.lastVirtualKeyTime
            )
            self.physics.step(dt: dt, windowFrameInScreen: CGRect(x: 0, y: 0, width: 360, height: 320), scripted: idleInput)
            self.physics.clackSim.step(
                dt: dt,
                cursorStagePt: CGPoint(x: 230 + sin(now * 1.3) * 65, y: 175 + cos(now * 0.9) * 25),
                screenMousePt: cursorPt,
                paused: false,
                privacy: false,
                reducedMotion: CatSettings.shared.reducedMotion
            )
            self.needsDisplay = true
        }
        RunLoop.main.add(t, forMode: .common)
        animTimer = t
    }

    private func stopPreviewLoop() {
        animTimer?.invalidate()
        animTimer = nil
    }

    override func mouseDown(with event: NSEvent) {
        let sampleKeys: [PhysicalKey] = [.t, .y, .p, .e, .z, .e, .r, .o, .space]
        let pick = sampleKeys.randomElement() ?? .j
        physics.triggerVoiceKeyDown(pick)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.physics.clackSim.triggerKeyUp(code: pick.clackCode)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        let sSettings = CatSettings.shared

        if sSettings.visualStyle == .clackOriginal {
            let stageW: CGFloat = 420
            let stageH: CGFloat = 350
            let sc = min(bounds.width / stageW, bounds.height / stageH)
            let ox = (bounds.width - stageW * sc) * 0.5
            let oy = (bounds.height - stageH * sc) * 0.5
            ctx.saveGState()
            ctx.translateBy(x: ox, y: oy)
            ctx.scaleBy(x: sc, y: sc)
            ClackRenderer.drawStage(
                in: ctx,
                pose: physics.clackSim.pose,
                breed: sSettings.coatTheme,
                handover: nil,
                customSkin: sSettings.customSkin.isEmpty ? nil : sSettings.activeSkin,
                anchorX: 196,
                anchorY: 326,
                baseScale: 0.78,
                whiteOutline: sSettings.whiteOutline,
                showKeyLabels: sSettings.showKeyLegends,
                showKeyBubbles: sSettings.showKeyBadges
            )
            ctx.restoreGState()
        } else {
            let sx = bounds.width / CatPhysics.canvasSize.width
            let sy = bounds.height / CatPhysics.canvasSize.height
            let s = min(sx, sy)
            let ox = (bounds.width - CatPhysics.canvasSize.width * s) * 0.5
            let oy = (bounds.height - CatPhysics.canvasSize.height * s) * 0.5

            ctx.saveGState()
            ctx.translateBy(x: ox, y: oy)
            ctx.scaleBy(x: s, y: s)
            CatRenderer.draw(in: ctx, physics: physics, showPermissionPill: false, isPreview: true)
            ctx.restoreGState()
        }
    }
}

private struct PetInlinePreviewStage: NSViewRepresentable {
    let style: PetVisualStyle
    let coat: CatCoatTheme
    let customSkinID: String
    let whiteOutline: Bool
    let marquee: Bool
    let keyGlow: Bool
    let kbTheme: KeyboardTheme
    let eyeTheme: EyeColorTheme
    let showLegends: Bool
    let levelKB: Bool

    func makeNSView(context: Context) -> PetInlinePreviewNSView {
        PetInlinePreviewNSView()
    }

    func updateNSView(_ nsView: PetInlinePreviewNSView, context: Context) {
        _ = (style, coat, customSkinID, whiteOutline, marquee, keyGlow, kbTheme, eyeTheme, showLegends, levelKB)
        nsView.needsDisplay = true
    }
}

// MARK: - Top-Level Sidebar Tab: 「桌面搭子」 (PetCompanionView)

private enum PetSettingsSubTab: String, CaseIterable, Identifiable {
    case breedAndHandover = "breed"
    case soundAndVoice    = "sound"
    case keyboardAndLook  = "keyboard"
    case interactAndSys   = "system"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breedAndHandover: return "🐾 品种与换班"
        case .soundAndVoice:    return "🔊 打字声与语音代敲"
        case .keyboardAndLook:  return "⌨️ 键盘闪光与外观"
        case .interactAndSys:   return "🎮 互动、隐私与窗口"
        }
    }
}

struct PetCompanionView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var pet: PetCompanionController
    @Environment(\.colorScheme) private var scheme
    @State private var selectedSubTab: PetSettingsSubTab = .breedAndHandover

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            heroStageCard
            subTabBar
            switch selectedSubTab {
            case .breedAndHandover:
                shiftHandoverSection
            case .soundAndVoice:
                soundAndVoiceSection
            case .keyboardAndLook:
                keyboardAndAppearanceSection
            case .interactAndSys:
                interactionAndSystemSection
            }
        }
        .sheet(isPresented: $pet.showCustomCatStudio) {
            CustomCatStudioSheet(appState: appState, pet: pet)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("桌面搭子")
                    .font(TZFont.title(24))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text("陪你打字与办公的桌面小猫")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
            Spacer()
            HStack(spacing: 5.5) {
                Circle()
                    .fill(pet.isEnabled ? (pet.pauseInputSync ? TZTheme.amber : TZTheme.emerald) : TZTheme.inkMuted.opacity(0.55))
                    .frame(width: 6.5, height: 6.5)
                Text(pet.isEnabled ? (pet.pauseInputSync ? "已暂停同步" : "桌宠在线陪打中") : "桌宠已收起")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(pet.isEnabled ? (pet.pauseInputSync ? TZTheme.amber : TZTheme.emerald) : TZTheme.inkSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(pet.isEnabled ? (pet.pauseInputSync ? TZTheme.amberSoft : TZTheme.emeraldSoft) : TZTheme.recessedWell)
            .clipShape(Capsule())
        }
    }

    // MARK: - Hero Live Stage & Master Switch

    private var heroStageCard: some View {
        HStack(spacing: 20) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: scheme == .dark
                                ? [Color(red: 0.11, green: 0.12, blue: 0.19), Color(red: 0.07, green: 0.08, blue: 0.13)]
                                : [Color(red: 0.94, green: 0.95, blue: 0.99), Color(red: 0.89, green: 0.91, blue: 0.97)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(TZTheme.cardBorder, lineWidth: 1)
                    )

                PetInlinePreviewStage(
                    style: pet.visualStyle,
                    coat: pet.coatTheme,
                    customSkinID: pet.customSkinID,
                    whiteOutline: pet.whiteOutline,
                    marquee: pet.keyboardMarquee,
                    keyGlow: pet.keyboardKeyGlow,
                    kbTheme: pet.keyboardTheme,
                    eyeTheme: pet.eyeTheme,
                    showLegends: pet.showKeyLegends,
                    levelKB: pet.levelKeyboard
                )
                .padding(6)

                Text("点击小猫试敲一下")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TZTheme.inkMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 7)
            }
            .frame(width: 216, height: 186)

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text("开启桌面黑猫搭子")
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Button {
                                pet.promptRenameActiveCat()
                            } label: {
                                HStack(spacing: 3.5) {
                                    Text("🐾 \(pet.activeCatDisplayName)")
                                    Image(systemName: "pencil")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(TZTheme.accent)
                                .padding(.horizontal, 7.5)
                                .padding(.vertical, 2.5)
                                .background(TZTheme.accentSoft)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("点击给猫咪起名或改名")
                        }
                        Text("常驻桌面右下角（可揪后颈拖动、滚轮缩放、双击进入旋转缩放框，右键小猫可一键关流光/开关音效）")
                            .font(.system(size: 12))
                            .foregroundStyle(TZTheme.inkSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { pet.isEnabled },
                        set: { pet.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(TZTheme.accent)
                    .labelsHidden()
                }

                // 4-Column Live Companion Stats
                HStack(spacing: 9) {
                    statPill(title: "今日语音代敲", value: "\(pet.todayVoiceKeys)", unit: "键", accent: TZTheme.accent)
                    statPill(title: "今日键盘陪打", value: "\(pet.todayPhysicalKeys)", unit: "键", accent: TZTheme.emerald)
                    statPill(title: "实时手速", value: "\(pet.currentKPM)", unit: "KPM", accent: TZTheme.inkPrimary)
                    statPill(title: "摸头呼噜", value: "\(pet.petTouchCount)", unit: "次", accent: TZTheme.amber)
                }

                // Quick Interactive Action Buttons
                HStack(spacing: 8) {
                    Button {
                        pet.openCustomCatStudio()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11.5))
                            Text("上传我家猫咪照片")
                        }
                    }
                    .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))

                    Button {
                        pet.playShiftHandoverDemo()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                .font(.system(size: 11.5))
                            Text(pet.isHandoverRunning ? "正在换班中…" : "演示「顶额头换班」")
                        }
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                    Button {
                        pet.playVoiceTypingDemo()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "keyboard.fill")
                                .font(.system(size: 11))
                            Text("试播语音敲键")
                        }
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                    if pet.isEnabled {
                        Button {
                            pet.resetPosition()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "scope")
                                    .font(.system(size: 11))
                                Text("归位")
                            }
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                    }
                }
            }
        }
        .padding(18)
        .tzElevatedCard()
    }

    private var subTabBar: some View {
        TZSegmentedBar(
            items: PetSettingsSubTab.allCases.map { tab in
                TZSegmentedBar.Item(
                    title: tab.title,
                    isSelected: selectedSubTab == tab,
                    action: { selectedSubTab = tab }
                )
            }
        )
    }

    private func statPill(title: String, value: String, unit: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(TZTheme.inkMuted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(TZFont.metric(16))
                    .foregroundStyle(accent)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7.5)
        .background(TZTheme.recessedWell.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Tab 1: 🐾 品种与原版顶额头换班

    private var shiftHandoverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            TZGroupedSection(title: "桌宠画风引擎") {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("桌面渲染画风")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text(pet.visualStyle.subtitle)
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        TZSegmentedBar(
                            items: PetVisualStyle.allCases.map { st in
                                TZSegmentedBar.Item(
                                    title: st.title,
                                    isSelected: pet.visualStyle == st,
                                    action: { pet.setVisualStyle(st) }
                                )
                            },
                            compact: true
                        )
                    }
                }
                .padding(16)
            }

            TZGroupedSection(title: "我家猫咪") {
                Button {
                    pet.triggerCatNameBubbleNow(mood: "🐾")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.middle.bottom.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text("试冒一下名字")
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(TZTheme.accent)
                }
                .buttonStyle(.plain)
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    // Photo Upload & Drop CTA Banner
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(TZTheme.accentSoft)
                                .frame(width: 44, height: 44)
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(TZTheme.accent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("上传照片，定制自家猫咪")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("支持上传多张照片还原花色细节，也可直接把照片拖到桌面小猫身上")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer(minLength: 8)

                        Button {
                            pet.openCustomCatStudio()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11.5, weight: .bold))
                                Text("上传照片")
                            }
                        }
                        .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
                    }
                    .padding(12)
                    .background(TZTheme.accentSoft.opacity(0.32))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(TZTheme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    )
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
                        guard !matching.isEmpty else { return false }
                        let group = DispatchGroup()
                        let lock = NSLock()
                        var urls: [URL] = []
                        for prov in matching.prefix(PhotoCatAnalyzer.maxPhotoCount) {
                            group.enter()
                            prov.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                                defer { group.leave() }
                                let url: URL? = {
                                    if let d = item as? Data { return URL(dataRepresentation: d, relativeTo: nil) }
                                    return item as? URL
                                }()
                                if let url {
                                    lock.lock()
                                    urls.append(url)
                                    lock.unlock()
                                }
                            }
                        }
                        group.notify(queue: .main) {
                            if !urls.isEmpty {
                                pet.openCustomCatStudio(initialPhotoURLs: urls)
                            }
                        }
                        return true
                    }

                    TZHairline()

                    // Cat Name & Occasional Head-Top Floating Bubble Controls
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            HStack(spacing: 7) {
                                Text("猫咪名字：\(pet.activeCatDisplayName)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(TZTheme.inkPrimary)
                                Button("改名") {
                                    pet.promptRenameActiveCat()
                                }
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(TZTheme.accent)
                                .buttonStyle(.plain)
                            }
                            Text("开启后名字偶尔浮现在脑袋上")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        if pet.showOccasionalNameBubble {
                            TZSegmentedBar(
                                items: [(2, "高频 2分"), (4, "自然 4分"), (8, "安静 8分")].map { mins, label in
                                    TZSegmentedBar.Item(
                                        title: label,
                                        isSelected: pet.nameBubbleIntervalMinutes == mins,
                                        action: { pet.setNameBubbleIntervalMinutes(mins) }
                                    )
                                },
                                compact: true
                            )
                        }
                        Toggle("", isOn: Binding(
                            get: { pet.showOccasionalNameBubble },
                            set: { pet.setShowOccasionalNameBubble($0) }
                        ))
                        .toggleStyle(.switch)
                        .tint(TZTheme.accent)
                        .labelsHidden()
                    }
                }
                .padding(16)
            }

            TZGroupedSection(title: "猫咪品种与我家猫主子（支持一键顶额头换班）") {
                HStack(spacing: 12) {
                    Button {
                        pet.openSkinWorkshop()
                    } label: {
                        HStack(spacing: 3.5) {
                            Image(systemName: "safari")
                                .font(.system(size: 10.5, weight: .semibold))
                            Text("在线皮肤工坊")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        pet.importSkinViaOpenPanel()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10.5, weight: .semibold))
                            Text("导入 .kurocat 皮肤")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(pet.importedSkins, id: \.id) { skin in
                            customCatSelectionCard(for: skin)
                        }
                        ForEach(CatCoatTheme.allCases) { coat in
                            breedSelectionCard(for: coat)
                        }
                    }

                    if !pet.statusNotice.isEmpty {
                        Text(pet.statusNotice)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.accent)
                    }

                    TZHairline()

                    toggleRow(
                        title: "切换品种时播放原版「顶额头对峙换班」动画（10.58 秒完整版）",
                        subtitle: "新猫从左侧走入 → 旧猫起身对峙 → 双猫弓背炸出三撮背毛顶额头僵持 3 秒 → 旧猫转身走人 → 新猫走近转身落座",
                        isOn: Binding(
                            get: { pet.enableHandoverAnimation },
                            set: { pet.setEnableHandoverAnimation($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "对峙配音（换班顶额头瞬间播放猫叫声）",
                        subtitle: "默认采用 Clack-Clack 原版 3 秒「老吴！！」对峙原声，也可切换为抖音多段真猫吵架轮播",
                        isOn: Binding(
                            get: { pet.enableHandoverSound },
                            set: { pet.setEnableHandoverSound($0) }
                        )
                    )

                    if pet.enableHandoverSound {
                        TZHairline()
                        HStack(spacing: 12) {
                            Text("对峙音源与音量（\(pet.duelVolume)%）")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Spacer()
                            TZSegmentedBar(
                                items: PetDuelVoiceStyle.allCases.map { st in
                                    TZSegmentedBar.Item(
                                        title: st.title,
                                        isSelected: pet.duelVoiceStyle == st,
                                        action: { pet.setDuelVoiceStyle(st) }
                                    )
                                },
                                compact: true
                            )
                            Slider(
                                value: Binding(
                                    get: { Double(pet.duelVolume) },
                                    set: { pet.setDuelVolume(Int($0.rounded())) }
                                ),
                                in: 0...100,
                                step: 5
                            )
                            .tint(TZTheme.accent)
                            .frame(width: 110)

                            Button("试听") {
                                pet.previewDuelVoice()
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Tab 2: 🔊 机械键盘/鼠标音效 & 云端语音代敲

    private var soundAndVoiceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            TZGroupedSection(title: "机械键盘敲击声与鼠标微动音效（Clack-Clack 原版无损采样）") {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    toggleRow(
                        title: "键盘敲击声",
                        subtitle: "实际按下按键时播放一次清脆机械轴体声，长按按键不会连续连发，安全输入/隐私模式下自动静音",
                        isOn: Binding(
                            get: { pet.keyboardSound },
                            set: { pet.setKeyboardSound($0) }
                        )
                    )

                    HStack(spacing: 12) {
                        Text("键盘轴体音色与音量（\(pet.keyboardVolume)%）")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Spacer()
                        TZSegmentedBar(
                            items: PetKeyboardTone.allCases.map { tone in
                                TZSegmentedBar.Item(
                                    title: tone.title,
                                    isSelected: pet.keyboardTone == tone,
                                    action: { pet.setKeyboardTone(tone) }
                                )
                            },
                            compact: true
                        )
                        Slider(
                            value: Binding(
                                get: { Double(pet.keyboardVolume) },
                                set: { pet.setKeyboardVolume(Int($0.rounded())) }
                            ),
                            in: 0...100,
                            step: 5
                        )
                        .tint(TZTheme.accent)
                        .frame(width: 115)

                        Button("试听") {
                            pet.previewKeyboardTone()
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                    }

                    if pet.keyboardSound {
                        TZHairline()
                        toggleRow(
                            title: "语音输入转化为敲键时同步播放机械打字声",
                            subtitle: "开启后，按住说话识别出的文字由黑猫代敲上屏时也会发出疾速打字声",
                            isOn: Binding(
                                get: { pet.voiceTypingSound },
                                set: { pet.setVoiceTypingSound($0) }
                            )
                        )
                    }

                    TZHairline()

                    toggleRow(
                        title: "鼠标点击声",
                        subtitle: "点击鼠标左键、右键或中键时播放微动清脆点击声",
                        isOn: Binding(
                            get: { pet.mouseSound },
                            set: { pet.setMouseSound($0) }
                        )
                    )

                    HStack(spacing: 12) {
                        Text("鼠标微动音色与音量（\(pet.mouseVolume)%）")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Spacer()
                        TZSegmentedBar(
                            items: PetMouseTone.allCases.map { tone in
                                TZSegmentedBar.Item(
                                    title: tone.title,
                                    isSelected: pet.mouseTone == tone,
                                    action: { pet.setMouseTone(tone) }
                                )
                            },
                            compact: true
                        )
                        Slider(
                            value: Binding(
                                get: { Double(pet.mouseVolume) },
                                set: { pet.setMouseVolume(Int($0.rounded())) }
                            ),
                            in: 0...100,
                            step: 5
                        )
                        .tint(TZTheme.accent)
                        .frame(width: 115)

                        Button("试听") {
                            pet.previewMouseTone()
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                    }
                }
                .padding(16)
            }

            TZGroupedSection(title: "TypeZero 云端语音变敲键盘") {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    toggleRow(
                        title: "云端语音实时转化为敲键盘动作",
                        subtitle: "使用 TypeZero 语音输入时，将识别与润色流拆解为真实拼音/英文按键序列，双爪敲击后再上屏文字",
                        isOn: Binding(
                            get: { pet.enableVoiceTyping },
                            set: { pet.setEnableVoiceTyping($0) }
                        )
                    )

                    TZHairline()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("语音代敲时的上方飘字样式")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("默认弹出机械键盘按键字母（如 J · I · N），与物理键盘敲击视觉统一")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        TZSegmentedBar(
                            items: PetVoiceBadgeMode.allCases.map { mode in
                                TZSegmentedBar.Item(
                                    title: mode.title,
                                    isSelected: pet.voiceBadgeMode == mode,
                                    action: { pet.setVoiceBadgeMode(mode) }
                                )
                            },
                            compact: true
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Tab 3: ⌨️ 键盘闪光控制与外观细节（含独立关闭跑马灯流光 & 单键光晕）

    private var keyboardAndAppearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            TZGroupedSection(title: "键盘灯光、配色与气泡反馈（可彻底关闭闪光）") {
                HStack(spacing: 12) {
                    Button {
                        pet.openKeyboardPlaza()
                    } label: {
                        HStack(spacing: 3.5) {
                            Image(systemName: "safari")
                                .font(.system(size: 10.5, weight: .semibold))
                            Text("键盘皮肤广场")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        pet.importKeyboardSkinViaOpenPanel()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10.5, weight: .semibold))
                            Text("导入 .kurokb 键盘")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    toggleRow(
                        title: "键盘 RGB 跑马灯流光",
                        subtitle: "控制键盘面板上的彩色彗星扫光特效；关闭后立即移除粉色/彩虹流光带",
                        isOn: Binding(
                            get: { pet.keyboardMarquee },
                            set: { pet.setKeyboardMarquee($0) }
                        )
                    )

                    if pet.keyboardMarquee && pet.visualStyle == .kuroSticker {
                        TZHairline()
                        HStack(spacing: 12) {
                            Text("跑马灯流光模式")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { pet.marqueeMode },
                                set: { pet.setMarqueeMode($0) }
                            )) {
                                Text("循环播放全部（自动轮换）").tag(KeyboardMarqueeMode.all)
                                Text("单向扫描（左 → 右，原版）").tag(KeyboardMarqueeMode.sweep)
                                Text("循环环绕（无缝衔接）").tag(KeyboardMarqueeMode.loop)
                                Text("涟漪扩散（中心向两侧）").tag(KeyboardMarqueeMode.ripple)
                            }
                            .labelsHidden()
                            .frame(width: 240)
                        }
                    }

                    TZHairline()

                    toggleRow(
                        title: "按键单键背光闪烁光晕",
                        subtitle: "控制敲击某个键时键帽周围泛起的荧光扩散光晕与高速电火花；关闭后仅保留干净的物理键帽按压",
                        isOn: Binding(
                            get: { pet.keyboardKeyGlow },
                            set: { pet.setKeyboardKeyGlow($0) }
                        )
                    )

                    TZHairline()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("键盘配色主题")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("内置经典奶白暖黄、暗夜极客黑、复古奶油灰 3 套机械键盘配色，支持导入 .kurokb")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { pet.customKeyboardID.isEmpty ? "theme:\(pet.keyboardTheme.rawValue)" : "custom:\(pet.customKeyboardID)" },
                            set: { token in
                                if token.hasPrefix("custom:") {
                                    pet.selectCustomKeyboard(id: String(token.dropFirst(7)))
                                } else if token.hasPrefix("theme:"), let th = KeyboardTheme(rawValue: String(token.dropFirst(6))) {
                                    pet.selectKeyboardTheme(th)
                                }
                            }
                        )) {
                            ForEach(KeyboardTheme.allCases, id: \.rawValue) { kb in
                                Text(kb.rawValue).tag("theme:\(kb.rawValue)")
                            }
                            ForEach(pet.importedKeyboardSkins, id: \.id) { ckb in
                                Text("自定义：\(ckb.name)").tag("custom:\(ckb.id)")
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    TZHairline()

                    toggleRow(
                        title: "显示键帽刻字字符",
                        subtitle: "在小猫面前的迷你机械键盘键帽上显示字母与符号刻字",
                        isOn: Binding(
                            get: { pet.showKeyLegends },
                            set: { pet.setShowKeyLegends($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "键盘水平摆放（平行于屏幕底边）",
                        subtitle: "关闭时采用微倾透视摆放，开启时平行对齐桌面底部",
                        isOn: Binding(
                            get: { pet.levelKeyboard },
                            set: { pet.setLevelKeyboard($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "显示键盘按键上浮气泡",
                        subtitle: "按下键盘按键时，在对应键位上方飘起机械键帽气泡提示",
                        isOn: Binding(
                            get: { pet.showKeyBadges },
                            set: { pet.setShowKeyBadges($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "显示鼠标点击气泡提示",
                        subtitle: "点击鼠标左/右/中键时，在迷你鼠标上方弹出点击提示",
                        isOn: Binding(
                            get: { pet.showMouseBadges },
                            set: { pet.setShowMouseBadges($0) }
                        )
                    )
                }
                .padding(16)
            }

            TZGroupedSection(title: "瞳色、贴纸描边与姿态变换") {
                Button("重置姿态与位置") {
                    pet.resetPoseAndPosition()
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(TZTheme.accent)
                .buttonStyle(.plain)
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("猫咪瞳色")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text(pet.overrideSkinIris ? "当前已手动锁定瞳色" : "当前自动跟随品种默认瞳色")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        if pet.overrideSkinIris {
                            Button("跟随品种") {
                                pet.resetEyeToBreedDefault()
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                        }
                        Picker("", selection: Binding(
                            get: { pet.eyeTheme },
                            set: { pet.selectEyeTheme($0) }
                        )) {
                            ForEach(EyeColorTheme.allCases, id: \.rawValue) { eye in
                                Text(eye.rawValue).tag(eye)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 210)
                    }

                    TZHairline()

                    toggleRow(
                        title: "白色贴纸外描边",
                        subtitle: "在深色代码编辑器与暗色壁纸上保持鲜明剪影轮廓（双画风与换班动画均生效）",
                        isOn: Binding(
                            get: { pet.whiteOutline },
                            set: { pet.setWhiteOutline($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "水平镜像翻转",
                        subtitle: "左右翻转小猫与键鼠工位朝向",
                        isOn: Binding(
                            get: { pet.flipHorizontal },
                            set: { pet.setFlipHorizontal($0) }
                        )
                    )

                    TZHairline()

                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("旋转角度（\(Int(pet.rotationDeg.rounded()))°）")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("支持贴边斜放或倒挂；双击桌面小猫也可直接唤出可视化缩放旋转手柄")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { Double(pet.rotationDeg) },
                                set: { pet.setRotationDeg(CGFloat($0)) }
                            ),
                            in: -180...180,
                            step: 1
                        )
                        .tint(TZTheme.accent)
                        .frame(width: 170)

                        Button("回正 0°") {
                            pet.setRotationDeg(0)
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Tab 4: 🎮 趣味彩蛋、隐私同步与桌面窗口 / OBS

    private var interactionAndSystemSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            TZGroupedSection(title: "趣味互动与彩蛋（KuroCat 全套继承）") {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    toggleRow(
                        title: "打字过快时冒出生气青筋表情（💢）",
                        subtitle: "持续高速敲键（≥ 260 KPM）满 3.2 秒触发短暂炸毛生气表情，摸摸头可安抚",
                        isOn: Binding(
                            get: { pet.enableAnger },
                            set: { pet.setEnableAnger($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "拎起后颈拖拽物理摆动动画",
                        subtitle: "左键按住拖动小猫时触发揪后颈悬空与物理钟摆惯性；关闭后保持坐姿平移",
                        isOn: Binding(
                            get: { pet.enableDragAnimation },
                            set: { pet.setEnableDragAnimation($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "鼠标轻抚猫头呼噜眯眼互动",
                        subtitle: "光标在猫头区域轻晃抚摸时，小猫闭眼享受并飘起微光粒子",
                        isOn: Binding(
                            get: { pet.petInteraction },
                            set: { pet.setPetInteraction($0) }
                        )
                    )

                    TZHairline()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("多键组合打字彩蛋方式")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("同时按下第 3、第 4 个按键时翘起后脚或甩出尾巴帮忙拍键")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { pet.typingLimbMode },
                            set: { pet.setTypingLimbMode($0) }
                        )) {
                            Text("后脚 + 尾巴（3键后脚 / 4键尾巴）").tag(0)
                            Text("仅第 3 键翘后脚").tag(1)
                            Text("仅尾巴拍键").tag(2)
                            Text("仅两只前爪打字").tag(3)
                        }
                        .labelsHidden()
                        .frame(width: 235)
                    }

                    TZHairline()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("数位板与触控笔模式")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("接入 Wacom / 随航数位板握笔绘画时自动切换为握触控笔写字板")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        TZSegmentedBar(
                            items: [
                                TZSegmentedBar.Item(title: "自动检测", isSelected: pet.tabletMode == 0, action: { pet.setTabletMode(0) }),
                                TZSegmentedBar.Item(title: "始终数位板", isSelected: pet.tabletMode == 1, action: { pet.setTabletMode(1) }),
                                TZSegmentedBar.Item(title: "始终鼠标", isSelected: pet.tabletMode == 2, action: { pet.setTabletMode(2) })
                            ],
                            compact: true
                        )
                    }

                    TZHairline()

                    toggleRow(
                        title: "听歌 / 看视频自动戴上耳机律动",
                        subtitle: "系统声卡连续输出外部音频满 1.5 秒自动戴上 2.5D 耳机飘音符",
                        isOn: Binding(
                            get: { pet.autoHeadphonesOnMusic },
                            set: { pet.setAutoHeadphonesOnMusic($0) }
                        )
                    )

                    TZHairline()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("整点猫头报时气泡")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("每个整点（HH:00）在小猫头顶轻柔弹出当前时间提醒胶囊")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        Button("试播报时") {
                            pet.testHourlyAnnouncement()
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                        Toggle("", isOn: Binding(
                            get: { pet.hourlyAnnouncement },
                            set: { pet.setHourlyAnnouncement($0) }
                        ))
                        .toggleStyle(.switch)
                        .tint(TZTheme.accent)
                        .labelsHidden()
                    }
                }
                .padding(16)
            }

            TZGroupedSection(title: "键鼠同步、隐私保护与桌面窗口（Clack-Clack + KuroCat）") {
                if pet.inputNeedsPermission {
                    Button("前往开启「输入监控」权限 ↗") {
                        pet.openInputMonitoringSettings()
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(TZTheme.amber)
                    .buttonStyle(.plain)
                } else {
                    Text("🟢 \(pet.inputStatusText)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TZTheme.emerald)
                }
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    toggleRow(
                        title: "暂停键鼠同步",
                        subtitle: "暂停期间，小猫静坐休息，停止跟随物理键盘、鼠标移动及敲击音效",
                        isOn: Binding(
                            get: { pet.pauseInputSync },
                            set: { pet.setPauseInputSync($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "屏幕共享隐私模式",
                        subtitle: "共享屏幕或录屏时开启：打字仅显示双爪匿名轻拍，自动隐藏按键气泡、键位高亮与音效（密码框自动生效）",
                        isOn: Binding(
                            get: { pet.privacyMode },
                            set: { pet.setPrivacyMode($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "减少动态效果",
                        subtitle: "减轻大幅身体晃动、晕眩与夸张回弹，仅保留干净利落的双爪敲击反馈",
                        isOn: Binding(
                            get: { pet.reducedMotion },
                            set: { pet.setReducedMotion($0) }
                        )
                    )

                    TZHairline()

                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("桌面体型缩放（\(Int((pet.scale * 100).rounded()))%）")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("也可直接在桌面上对准小猫滚动鼠标滚轮或触控板双指捏合无级缩放")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { Double(pet.scale) },
                                set: { pet.setScale(CGFloat($0)) }
                            ),
                            in: 0.45...2.0,
                            step: 0.05
                        )
                        .tint(TZTheme.accent)
                        .frame(width: 200)
                    }

                    TZHairline()

                    toggleRow(
                        title: "始终置顶于全屏应用上方",
                        subtitle: "让小猫在全屏桌面空间与演示窗口上方保持置顶可见",
                        isOn: Binding(
                            get: { pet.fullScreenOverlay },
                            set: { pet.setFullScreenOverlay($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "全屏观影 / 全屏游戏时自动隐藏",
                        subtitle: "检测到前台其他应用进入全屏独占时自动隐身，退出全屏后自动恢复",
                        isOn: Binding(
                            get: { pet.autoHideFullscreen },
                            set: { pet.setAutoHideFullscreen($0) }
                        )
                    )

                    TZHairline()

                    toggleRow(
                        title: "完全鼠标穿透（防误触）",
                        subtitle: "开启后鼠标点击直接穿过小猫落到后方窗口；按住 Option (⌥) 键可随时临时拖动或右键",
                        isOn: Binding(
                            get: { pet.fullClickThrough },
                            set: { pet.setFullClickThrough($0) }
                        )
                    )

                    TZHairline()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("OBS 直播捕获模式")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("支持 OBS 透明窗口源捕获或 #00FF00 纯绿幕色度键抠像")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { pet.obsCaptureMode },
                            set: { pet.setOBSCaptureMode($0) }
                        )) {
                            Text("关闭（正常桌面悬浮）").tag(0)
                            Text("OBS 透明窗口捕获").tag(1)
                            Text("OBS 绿幕模式 (#00FF00)").tag(2)
                        }
                        .labelsHidden()
                        .frame(width: 210)
                    }

                    if pet.obsCaptureMode > 0 {
                        TZHairline()
                        toggleRow(
                            title: "OBS 后台捕获（隐藏自己桌面上的小猫）",
                            subtitle: "将小猫置于桌面壁纸层后方，自己屏幕无遮挡而 OBS 仍可实时捕获",
                            isOn: Binding(
                                get: { pet.obsHideDesktop },
                                set: { pet.setOBSHideDesktop($0) }
                            )
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Subcomponents

    private func customCatSelectionCard(for skin: SkinSpec) -> some View {
        let isSelected = (pet.customSkinID == skin.id)
        let bodyColor = Color(nsColor: skin.palette.body.srgbNS)
        let eyeL = Color(nsColor: (skin.palette.irisLeft ?? skin.palette.iris)?.srgbNS ?? NSColor.systemYellow)
        let eyeR = Color(nsColor: (skin.palette.irisRight ?? skin.palette.iris)?.srgbNS ?? NSColor.systemYellow)

        return HStack(spacing: 10) {
            Button {
                if !pet.isEnabled { pet.setEnabled(true) }
                pet.selectCustomSkin(id: skin.id)
            } label: {
                HStack(spacing: 11) {
                    ZStack {
                        if let png = skin.preview, let nsImg = NSImage(data: png) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
                                .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1.5)
                        } else {
                            Circle()
                                .fill(bodyColor)
                                .frame(width: 36, height: 36)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.78), lineWidth: 1.4))
                                .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 1.5)
                            HStack(spacing: 4) {
                                Circle().fill(eyeL).frame(width: 6.5, height: 6.5)
                                Circle().fill(eyeR).frame(width: 6.5, height: 6.5)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack(spacing: 6) {
                            Text(SkinLibrary.shared.displayName(for: skin))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(TZTheme.inkPrimary)
                                .lineLimit(1)
                            if isSelected {
                                Text("值班中")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(TZTheme.accent)
                                    .padding(.horizontal, 5.5)
                                    .padding(.vertical, 1.5)
                                    .background(TZTheme.accentSoft)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(skin.photoDNA?.breedBadge ?? (skin.author.isEmpty ? "自定义猫咪" : skin.author))
                            .font(.system(size: 11))
                            .foregroundStyle(TZTheme.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Button {
                    pet.openCustomCatStudio(editingSkinID: skin.id)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                .buttonStyle(.plain)
                .help("微调花色与名字")

                Button {
                    pet.renameImportedSkin(id: skin.id)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                .buttonStyle(.plain)
                .help("改名")

                Button {
                    pet.removeImportedSkin(id: skin.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TZTheme.inkMuted)
                }
                .buttonStyle(.plain)
                .help("移入废纸篓")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? TZTheme.accentSoft.opacity(0.55) : TZTheme.recessedWell.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(isSelected ? TZTheme.accent.opacity(0.65) : TZTheme.cardBorder, lineWidth: isSelected ? 1.25 : 0.8)
        )
    }

    private func breedSelectionCard(for coat: CatCoatTheme) -> some View {
        let isSelected = pet.customSkinID.isEmpty && pet.coatTheme == coat
        let swatchColors = coatSwatchColors(for: coat)

        return Button {
            if !pet.isEnabled {
                pet.setEnabled(true)
            }
            pet.selectBuiltInCoat(coat)
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(swatchColors.coat)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.78), lineWidth: 1.4))
                        .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 1.5)
                    HStack(spacing: 4) {
                        Circle().fill(swatchColors.eye).frame(width: 6.5, height: 6.5)
                        Circle().fill(swatchColors.eye).frame(width: 6.5, height: 6.5)
                    }
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        let customNick = CatSettings.shared.builtInNicknames[coat.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let baseTitle = coat == .orangeWhite ? "橘白猫 · 黄粽子" : coat.shortTitle
                        Text(customNick.isEmpty ? baseTitle : "\(customNick) · \(coat.shortTitle)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                            .lineLimit(1)
                        if isSelected {
                            Text("值班中")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(TZTheme.accent)
                                .padding(.horizontal, 5.5)
                                .padding(.vertical, 1.5)
                                .background(TZTheme.accentSoft)
                                .clipShape(Capsule())
                        }
                    }
                    Text(coat.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(isSelected ? TZTheme.accent : TZTheme.inkMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10.5)
            .background(isSelected ? TZTheme.accentSoft.opacity(0.55) : TZTheme.recessedWell.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(isSelected ? TZTheme.accent.opacity(0.65) : TZTheme.cardBorder, lineWidth: isSelected ? 1.25 : 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func coatSwatchColors(for coat: CatCoatTheme) -> (coat: Color, eye: Color) {
        switch coat {
        case .classicBlack:
            return (Color(red: 0.10, green: 0.10, blue: 0.12), Color(red: 0.79, green: 0.95, blue: 0.25))
        case .siamese:
            return (Color(red: 0.32, green: 0.23, blue: 0.19), Color(red: 0.65, green: 0.86, blue: 0.98))
        case .shorthair:
            return (Color(red: 0.62, green: 0.65, blue: 0.63), Color(red: 0.85, green: 0.70, blue: 0.34))
        case .orangeWhite:
            return (Color(red: 0.85, green: 0.60, blue: 0.34), Color(red: 0.72, green: 0.75, blue: 0.45))
        }
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2.5) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(TZTheme.accent)
                .labelsHidden()
        }
    }
}

private struct FlowImportedSkinsRow: View {
    @ObservedObject var pet: PetCompanionController

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pet.importedSkins, id: \.id) { skin in
                    let active = (pet.customSkinID == skin.id)
                    HStack(spacing: 6) {
                        Button {
                            if !pet.isEnabled { pet.setEnabled(true) }
                            pet.selectCustomSkin(id: skin.id)
                        } label: {
                            Text(SkinLibrary.shared.displayName(for: skin))
                                .font(.system(size: 12, weight: active ? .semibold : .regular))
                                .foregroundStyle(active ? TZTheme.accent : TZTheme.inkPrimary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            pet.renameImportedSkin(id: skin.id)
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 10.5))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("重命名")

                        Button {
                            pet.removeImportedSkin(id: skin.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(TZTheme.inkMuted)
                        }
                        .buttonStyle(.plain)
                        .help("移入废纸篓")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5.5)
                    .background(active ? TZTheme.accentSoft : TZTheme.recessedWell)
                    .clipShape(Capsule())
                }
            }
        }
    }
}
