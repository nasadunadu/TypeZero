import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Live Embedded Vector Cat Preview Stage (Supports Both KuroCat & Clack-Clack Styles)

private final class PetInlinePreviewNSView: NSView {
    let physics = CatPhysics()
    var onDropPhotos: (([URL]) -> Void)?
    private var animTimer: Timer?
    private var lastTick: CFTimeInterval = CACurrentMediaTime()

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        registerForDraggedTypes([.fileURL])
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
        if CatSettings.shared.activeSkin.species == "fish" {
            physics.fishSwim.triggerPuffUp(duration: 1.6)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.physics.clackSim.triggerKeyUp(code: pick.clackCode)
        }
        needsDisplay = true
    }

    private static let photoExts: Set<String> = ["png", "jpg", "jpeg", "heic", "webp", "bmp", "tiff"]

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        return urls.contains(where: { Self.photoExts.contains($0.pathExtension.lowercased()) }) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        let photos = urls.filter { Self.photoExts.contains($0.pathExtension.lowercased()) }
        guard !photos.isEmpty else { return false }
        DispatchQueue.main.async { [weak self] in self?.onDropPhotos?(photos) }
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        let sSettings = CatSettings.shared

        if sSettings.visualStyle == .clackOriginal && sSettings.activeSkin.species != "fish" {
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
    let onDropPhotos: ([URL]) -> Void

    func makeNSView(context: Context) -> PetInlinePreviewNSView {
        let v = PetInlinePreviewNSView()
        v.onDropPhotos = onDropPhotos
        return v
    }

    func updateNSView(_ nsView: PetInlinePreviewNSView, context: Context) {
        _ = (style, coat, customSkinID, whiteOutline, marquee, keyGlow, kbTheme, eyeTheme, showLegends, levelKB)
        nsView.onDropPhotos = onDropPhotos
        nsView.needsDisplay = true
    }
}

// MARK: - Top-Level Sidebar Tab: 「桌面搭子」 (Clean Consumer Layout)

private enum PetSettingsSubTab: String, CaseIterable, Identifiable {
    case cats       = "cats"
    case fish       = "fish"
    case sound      = "sound"
    case appearance = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cats:       return "猫咪"
        case .fish:       return "小鱼"
        case .sound:      return "音效"
        case .appearance: return "外观与偏好"
        }
    }

    var icon: String {
        switch self {
        case .cats:       return "cat.fill"
        case .fish:       return "fish.fill"
        case .sound:      return "speaker.wave.2.fill"
        case .appearance: return "slider.horizontal.3"
        }
    }
}

struct PetCompanionView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var pet: PetCompanionController
    @Environment(\.colorScheme) private var scheme
    @State private var selectedSubTab: PetSettingsSubTab = .cats
    @State private var showAdvancedOptions: Bool = false

    private var customCatSkins: [SkinSpec] {
        pet.importedSkins.filter { $0.species != "fish" }
    }

    private var customFishSkins: [SkinSpec] {
        pet.importedSkins.filter { $0.species == "fish" && $0.author != PetCompanionController.builtInFishAuthor }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            heroStageCard
            subTabBar
            switch selectedSubTab {
            case .cats:
                catsSection
            case .fish:
                fishSection
            case .sound:
                soundSection
            case .appearance:
                appearanceAndPrefsSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if pet.activePetSpecies == "fish" {
                selectedSubTab = .fish
            }
        }
        .onChange(of: pet.lastAdoptedTick) { _, _ in
            selectedSubTab = (pet.lastAdoptedSpecies == "fish") ? .fish : .cats
        }
        .sheet(isPresented: $pet.showCustomCatStudio) {
            CustomCatStudioSheet(appState: appState, pet: pet)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("桌面搭子")
                .font(TZFont.title(24))
                .foregroundStyle(TZTheme.inkPrimary)

            Spacer()

            HStack(spacing: 5.5) {
                Circle()
                    .fill(pet.isEnabled ? (pet.pauseInputSync ? TZTheme.amber : TZTheme.emerald) : TZTheme.inkMuted.opacity(0.55))
                    .frame(width: 6.5, height: 6.5)
                Text(pet.isEnabled ? (pet.pauseInputSync ? "已暂停" : "在线中") : "已关闭")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(pet.isEnabled ? (pet.pauseInputSync ? TZTheme.amber : TZTheme.emerald) : TZTheme.inkSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(pet.isEnabled ? (pet.pauseInputSync ? TZTheme.amberSoft : TZTheme.emeraldSoft) : TZTheme.recessedWell)
            .clipShape(Capsule())
        }
    }

    // MARK: - Hero Live Stage & Quick Controls

    private var heroStageCard: some View {
        HStack(spacing: 18) {
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
                    levelKB: pet.levelKeyboard,
                    onDropPhotos: { urls in
                        pet.openCustomCatStudio(initialPhotoURLs: urls)
                    }
                )
                .padding(5)

                Text("点我试敲")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TZTheme.inkMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 6)
            }
            .frame(width: 186, height: 158)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Text(pet.activePetSpecies == "fish" ? "桌面小鱼" : "桌面小猫")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                        .lineLimit(1)

                    Button {
                        pet.promptRenameActiveCat()
                    } label: {
                        HStack(spacing: 3.5) {
                            Text("\(pet.activePetSpecies == "fish" ? "🫧" : "🐾") \(pet.activeCatDisplayName)")
                                .lineLimit(1)
                            Image(systemName: "pencil")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(TZTheme.accentSoft)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("改名")

                    Spacer(minLength: 4)

                    Toggle("", isOn: Binding(
                        get: { pet.isEnabled },
                        set: { pet.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(TZTheme.accent)
                    .labelsHidden()
                }

                // 3-Column Clean Live Stats
                HStack(spacing: 8) {
                    statPill(title: "语音代敲", value: "\(pet.todayVoiceKeys)", unit: "键", accent: TZTheme.accent)
                    statPill(title: "键盘陪打", value: "\(pet.todayPhysicalKeys)", unit: "键", accent: TZTheme.emerald)
                    statPill(title: pet.activePetSpecies == "fish" ? "戳肚互动" : "摸头呼噜", value: "\(pet.petTouchCount)", unit: "次", accent: TZTheme.amber)
                }

                // Single-Line Non-Wrapping Action Pills
                HStack(spacing: 8) {
                    Button {
                        pet.openCustomCatStudio(species: selectedSubTab == .fish ? "fish" : "cat")
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11))
                            Text(selectedSubTab == .fish ? "上传小鱼" : "上传猫咪")
                        }
                    }
                    .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))

                    if pet.activePetSpecies == "fish" {
                        Button {
                            pet.triggerFishPuffDemo()
                        } label: {
                            HStack(spacing: 4.5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text("鼓成刺球")
                            }
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                    } else {
                        Button {
                            pet.playShiftHandoverDemo()
                        } label: {
                            HStack(spacing: 4.5) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text(pet.isHandoverRunning ? "换班中" : "换班")
                            }
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                    }

                    Button {
                        pet.playVoiceTypingDemo()
                    } label: {
                        HStack(spacing: 4.5) {
                            Image(systemName: "keyboard.fill")
                                .font(.system(size: 10.5))
                            Text("试打字")
                        }
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                    if pet.isEnabled {
                        Button {
                            pet.resetPosition()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "scope")
                                    .font(.system(size: 10.5))
                                Text("归位")
                            }
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                    }

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .tzElevatedCard()
    }

    private var subTabBar: some View {
        TZSegmentedBar(
            items: PetSettingsSubTab.allCases.map { tab in
                TZSegmentedBar.Item(
                    title: tab.title,
                    icon: tab.icon,
                    isSelected: selectedSubTab == tab,
                    action: { selectedSubTab = tab }
                )
            }
        )
    }

    private func statPill(title: String, value: String, unit: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2.5) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(TZTheme.inkMuted)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(TZFont.metric(16))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(TZTheme.recessedWell.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Tab 1: 猫咪

    private var catsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TZGroupedSection(title: "选择猫咪") {
                HStack(spacing: 12) {
                    Button("导入皮肤") {
                        pet.importSkinViaOpenPanel()
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(TZTheme.accent)
                    .buttonStyle(.plain)

                    Button("皮肤工坊") {
                        pet.openSkinWorkshop()
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
                    .buttonStyle(.plain)
                }
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        addCustomCatTile
                        ForEach(customCatSkins, id: \.id) { skin in
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
                }
                .padding(14)
            }

            TZGroupedSection(title: "画风与换班") {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("画风")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Spacer()
                        TZSegmentedBar(
                            items: [
                                TZSegmentedBar.Item(
                                    title: "贴纸风",
                                    isSelected: pet.visualStyle == .kuroSticker,
                                    action: { pet.setVisualStyle(.kuroSticker) }
                                ),
                                TZSegmentedBar.Item(
                                    title: "立体风",
                                    isSelected: pet.visualStyle == .clackOriginal,
                                    action: { pet.setVisualStyle(.clackOriginal) }
                                )
                            ],
                            compact: true
                        )
                        .frame(width: 152)
                    }

                    TZHairline()

                    HStack(spacing: 10) {
                        Text("头顶偶尔冒出名字")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
                            .lineLimit(1)

                        Button("试一下") {
                            pet.triggerCatNameBubbleNow(mood: "🐾")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.accent)
                        .buttonStyle(.plain)

                        Spacer(minLength: 4)

                        if pet.showOccasionalNameBubble {
                            TZSegmentedBar(
                                items: [(2, "2分"), (4, "4分"), (8, "8分")].map { mins, label in
                                    TZSegmentedBar.Item(
                                        title: label,
                                        isSelected: pet.nameBubbleIntervalMinutes == mins,
                                        action: { pet.setNameBubbleIntervalMinutes(mins) }
                                    )
                                },
                                compact: true
                            )
                            .frame(width: 132)
                        }

                        Toggle("", isOn: Binding(
                            get: { pet.showOccasionalNameBubble },
                            set: { pet.setShowOccasionalNameBubble($0) }
                        ))
                        .toggleStyle(.switch)
                        .tint(TZTheme.accent)
                        .labelsHidden()
                    }

                    TZHairline()

                    simpleToggleRow(
                        title: "切换猫咪时播放换班动画",
                        isOn: Binding(
                            get: { pet.enableHandoverAnimation },
                            set: { pet.setEnableHandoverAnimation($0) }
                        )
                    )

                    TZHairline()

                    simpleToggleRow(
                        title: "换班配音",
                        isOn: Binding(
                            get: { pet.enableHandoverSound },
                            set: { pet.setEnableHandoverSound($0) }
                        )
                    )

                    if pet.enableHandoverSound {
                        HStack(spacing: 10) {
                            Text("音量 \(pet.duelVolume)%")
                                .font(.system(size: 12))
                                .foregroundStyle(TZTheme.inkSecondary)
                                .frame(width: 58, alignment: .leading)

                            TZSegmentedBar(
                                items: PetDuelVoiceStyle.allCases.map { st in
                                    TZSegmentedBar.Item(
                                        title: st == .clackLaoWu ? "原版" : "真猫",
                                        isSelected: pet.duelVoiceStyle == st,
                                        action: { pet.setDuelVoiceStyle(st) }
                                    )
                                },
                                compact: true
                            )
                            .frame(width: 116)

                            Slider(
                                value: Binding(
                                    get: { Double(pet.duelVolume) },
                                    set: { pet.setDuelVolume(Int($0.rounded())) }
                                ),
                                in: 0...100,
                                step: 5
                            )
                            .tint(TZTheme.accent)
                            .frame(maxWidth: 130)

                            Spacer(minLength: 4)

                            Button("试听") {
                                pet.previewDuelVoice()
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    private var addCustomCatTile: some View {
        Button {
            pet.openCustomCatStudio(species: "cat")
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(TZTheme.accentSoft)
                        .frame(width: 34, height: 34)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TZTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("上传自家猫咪")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                        .lineLimit(1)
                    Text("支持 1–4 张照片")
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(TZTheme.accentSoft.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(TZTheme.accent.opacity(0.38), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDroppedPhotoProviders(providers)
        }
    }

    // MARK: - Tab 2: 小鱼（与猫咪彻底隔离）

    private var fishSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TZGroupedSection(title: "选择小鱼") {
                Button("导入皮肤") {
                    pet.importSkinViaOpenPanel()
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(TZTheme.accent)
                .buttonStyle(.plain)
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        addCustomFishTile
                        ForEach(customFishSkins, id: \.id) { skin in
                            customCatSelectionCard(for: skin)
                        }
                        builtInPufferFishCard
                    }

                    if !pet.statusNotice.isEmpty {
                        Text(pet.statusNotice)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.accent)
                    }
                }
                .padding(14)
            }

            TZGroupedSection(title: "互动与名字") {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text("头顶偶尔冒出名字")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
                            .lineLimit(1)

                        Button("试一下") {
                            pet.triggerCatNameBubbleNow(mood: "🫧")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.accent)
                        .buttonStyle(.plain)

                        Spacer(minLength: 4)

                        if pet.showOccasionalNameBubble {
                            TZSegmentedBar(
                                items: [(2, "2分"), (4, "4分"), (8, "8分")].map { mins, label in
                                    TZSegmentedBar.Item(
                                        title: label,
                                        isSelected: pet.nameBubbleIntervalMinutes == mins,
                                        action: { pet.setNameBubbleIntervalMinutes(mins) }
                                    )
                                },
                                compact: true
                            )
                            .frame(width: 132)
                        }

                        Toggle("", isOn: Binding(
                            get: { pet.showOccasionalNameBubble },
                            set: { pet.setShowOccasionalNameBubble($0) }
                        ))
                        .toggleStyle(.switch)
                        .tint(TZTheme.accent)
                        .labelsHidden()
                    }

                    TZHairline()

                    HStack(spacing: 10) {
                        Text("戳肚鼓成刺球")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
                            .lineLimit(1)
                        Spacer()
                        Button("试一下") {
                            pet.triggerFishPuffDemo()
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                    }
                }
                .padding(14)
            }
        }
    }

    private var addCustomFishTile: some View {
        Button {
            pet.openCustomCatStudio(species: "fish")
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(TZTheme.accentSoft)
                        .frame(width: 34, height: 34)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TZTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("上传自家小鱼")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                        .lineLimit(1)
                    Text("支持 1–4 张照片")
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(TZTheme.accentSoft.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(TZTheme.accent.opacity(0.38), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDroppedPhotoProviders(providers)
        }
    }

    private var builtInPufferFishCard: some View {
        let isSelected = (pet.builtInFishSkinID != nil && pet.customSkinID == pet.builtInFishSkinID)

        return Button {
            pet.selectBuiltInFishPreset()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.94, green: 0.89, blue: 0.77))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.4))
                    HStack(spacing: 3.5) {
                        Circle()
                            .fill(Color(red: 0.87, green: 0.23, blue: 0.21))
                            .frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(Color(red: 0.29, green: 0.16, blue: 0.14), lineWidth: 1.3))
                        Circle()
                            .fill(Color(red: 0.87, green: 0.23, blue: 0.21))
                            .frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(Color(red: 0.29, green: 0.16, blue: 0.14), lineWidth: 1.3))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("红斑")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                            .lineLimit(1)
                        if isSelected {
                            Text("值班")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(TZTheme.accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(TZTheme.accentSoft)
                                .clipShape(Capsule())
                        }
                    }
                    Text("红斑狗头河豚")
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9.5)
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

    // MARK: - Tab 2: 音效

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TZGroupedSection(title: "键鼠音效") {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    simpleToggleRow(
                        title: "键盘敲击声",
                        isOn: Binding(
                            get: { pet.keyboardSound },
                            set: { pet.setKeyboardSound($0) }
                        )
                    )

                    if pet.keyboardSound {
                        HStack(spacing: 10) {
                            Text("音量 \(pet.keyboardVolume)%")
                                .font(.system(size: 12))
                                .foregroundStyle(TZTheme.inkSecondary)
                                .frame(width: 58, alignment: .leading)

                            TZSegmentedBar(
                                items: PetKeyboardTone.allCases.map { tone in
                                    TZSegmentedBar.Item(
                                        title: tone == .mxClear ? "段落轴" : "青轴",
                                        isSelected: pet.keyboardTone == tone,
                                        action: { pet.setKeyboardTone(tone) }
                                    )
                                },
                                compact: true
                            )
                            .frame(width: 132)

                            Slider(
                                value: Binding(
                                    get: { Double(pet.keyboardVolume) },
                                    set: { pet.setKeyboardVolume(Int($0.rounded())) }
                                ),
                                in: 0...100,
                                step: 5
                            )
                            .tint(TZTheme.accent)
                            .frame(maxWidth: 130)

                            Spacer(minLength: 4)

                            Button("试听") {
                                pet.previewKeyboardTone()
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                        }

                        TZHairline()

                        simpleToggleRow(
                            title: "语音代敲时同步播放打字声",
                            isOn: Binding(
                                get: { pet.voiceTypingSound },
                                set: { pet.setVoiceTypingSound($0) }
                            )
                        )
                    }

                    TZHairline()

                    simpleToggleRow(
                        title: "鼠标点击声",
                        isOn: Binding(
                            get: { pet.mouseSound },
                            set: { pet.setMouseSound($0) }
                        )
                    )

                    if pet.mouseSound {
                        HStack(spacing: 10) {
                            Text("音量 \(pet.mouseVolume)%")
                                .font(.system(size: 12))
                                .foregroundStyle(TZTheme.inkSecondary)
                                .frame(width: 58, alignment: .leading)

                            TZSegmentedBar(
                                items: PetMouseTone.allCases.map { tone in
                                    TZSegmentedBar.Item(
                                        title: tone == .crisp ? "清脆" : "G502",
                                        isSelected: pet.mouseTone == tone,
                                        action: { pet.setMouseTone(tone) }
                                    )
                                },
                                compact: true
                            )
                            .frame(width: 132)

                            Slider(
                                value: Binding(
                                    get: { Double(pet.mouseVolume) },
                                    set: { pet.setMouseVolume(Int($0.rounded())) }
                                ),
                                in: 0...100,
                                step: 5
                            )
                            .tint(TZTheme.accent)
                            .frame(maxWidth: 130)

                            Spacer(minLength: 4)

                            Button("试听") {
                                pet.previewMouseTone()
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                        }
                    }
                }
                .padding(14)
            }

            TZGroupedSection(title: "语音联动") {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    simpleToggleRow(
                        title: "说话时同步敲键盘",
                        isOn: Binding(
                            get: { pet.enableVoiceTyping },
                            set: { pet.setEnableVoiceTyping($0) }
                        )
                    )

                    if pet.enableVoiceTyping {
                        TZHairline()
                        HStack(spacing: 12) {
                            Text("飘字样式")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(TZTheme.inkPrimary)
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
                            .frame(width: 176)
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    // MARK: - Tab 3: 外观与偏好

    private var appearanceAndPrefsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TZGroupedSection(title: "键盘与外观") {
                Button("重置姿态") {
                    pet.resetPoseAndPosition()
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(TZTheme.accent)
                .buttonStyle(.plain)
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    simpleToggleRow(
                        title: "键盘跑马灯流光",
                        isOn: Binding(
                            get: { pet.keyboardMarquee },
                            set: { pet.setKeyboardMarquee($0) }
                        )
                    )

                    TZHairline()

                    simpleToggleRow(
                        title: "单键背光闪烁",
                        isOn: Binding(
                            get: { pet.keyboardKeyGlow },
                            set: { pet.setKeyboardKeyGlow($0) }
                        )
                    )

                    TZHairline()

                    HStack(spacing: 12) {
                        Text("键盘配色")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
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
                        .frame(width: 175)
                    }

                    TZHairline()

                    HStack(spacing: 10) {
                        Text("猫咪瞳色")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Spacer()
                        if pet.overrideSkinIris {
                            Button("跟随品种") {
                                pet.resetEyeToBreedDefault()
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.accent)
                            .buttonStyle(.plain)
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
                        .frame(width: 175)
                    }

                    TZHairline()

                    HStack(spacing: 12) {
                        Text("桌面大小（\(Int((pet.scale * 100).rounded()))%）")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
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
                        .frame(width: 170)
                    }

                    TZHairline()

                    simpleToggleRow(
                        title: "显示键帽字母",
                        isOn: Binding(
                            get: { pet.showKeyLegends },
                            set: { pet.setShowKeyLegends($0) }
                        )
                    )

                    TZHairline()

                    simpleToggleRow(
                        title: "按键上浮气泡",
                        isOn: Binding(
                            get: { pet.showKeyBadges },
                            set: { pet.setShowKeyBadges($0) }
                        )
                    )

                    TZHairline()

                    simpleToggleRow(
                        title: "白色贴纸描边",
                        isOn: Binding(
                            get: { pet.whiteOutline },
                            set: { pet.setWhiteOutline($0) }
                        )
                    )
                }
                .padding(14)
            }

            TZGroupedSection(title: "互动与窗口") {
                if pet.inputNeedsPermission {
                    Button("开启输入监控 ↗") {
                        pet.openInputMonitoringSettings()
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(TZTheme.amber)
                    .buttonStyle(.plain)
                } else {
                    Text("🟢 运行正常")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TZTheme.emerald)
                }
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    simpleToggleRow(
                        title: "摸头呼噜互动",
                        isOn: Binding(
                            get: { pet.petInteraction },
                            set: { pet.setPetInteraction($0) }
                        )
                    )

                    TZHairline()

                    simpleToggleRow(
                        title: "拎起后颈拖动",
                        isOn: Binding(
                            get: { pet.enableDragAnimation },
                            set: { pet.setEnableDragAnimation($0) }
                        )
                    )

                    TZHairline()

                    simpleToggleRow(
                        title: "听歌自动戴耳机",
                        isOn: Binding(
                            get: { pet.autoHeadphonesOnMusic },
                            set: { pet.setAutoHeadphonesOnMusic($0) }
                        )
                    )

                    TZHairline()

                    simpleToggleRow(
                        title: "屏幕共享隐私模式",
                        hint: "隐藏键位与音效",
                        isOn: Binding(
                            get: { pet.privacyMode },
                            set: { pet.setPrivacyMode($0) }
                        )
                    )

                    TZHairline()

                    simpleToggleRow(
                        title: "全屏应用时自动隐藏",
                        isOn: Binding(
                            get: { pet.autoHideFullscreen },
                            set: { pet.setAutoHideFullscreen($0) }
                        )
                    )

                    TZHairline()

                    simpleToggleRow(
                        title: "鼠标穿透",
                        hint: "按住 ⌥ 可拖动",
                        isOn: Binding(
                            get: { pet.fullClickThrough },
                            set: { pet.setFullClickThrough($0) }
                        )
                    )
                }
                .padding(14)
            }

            // Collapsible Power-User & Streaming Options (hidden by default for clean C-end simplicity)
            TZGroupedSection(title: "更多与直播设置") {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showAdvancedOptions.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAdvancedOptions ? "收起" : "展开")
                        Image(systemName: showAdvancedOptions ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
                }
                .buttonStyle(.plain)
            } content: {
                if showAdvancedOptions {
                    advancedOptionsContent
                        .padding(14)
                } else {
                    HStack {
                        Text("键盘皮肤、水平翻转、旋转、整点报时、数位板、OBS 绿幕等")
                            .font(.system(size: 11.5))
                            .foregroundStyle(TZTheme.inkMuted)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            showAdvancedOptions = true
                        }
                    }
                }
            }
        }
    }

    private var advancedOptionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("自定义键盘皮肤")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TZTheme.inkPrimary)
                Spacer()
                Button("皮肤广场") {
                    pet.openKeyboardPlaza()
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                Button("导入 .kurokb") {
                    pet.importKeyboardSkinViaOpenPanel()
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
            }

            if pet.keyboardMarquee && pet.visualStyle == .kuroSticker {
                TZHairline()
                HStack(spacing: 12) {
                    Text("跑马灯模式")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { pet.marqueeMode },
                        set: { pet.setMarqueeMode($0) }
                    )) {
                        Text("自动轮换").tag(KeyboardMarqueeMode.all)
                        Text("单向扫描").tag(KeyboardMarqueeMode.sweep)
                        Text("循环环绕").tag(KeyboardMarqueeMode.loop)
                        Text("涟漪扩散").tag(KeyboardMarqueeMode.ripple)
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            }

            TZHairline()
            simpleToggleRow(title: "暂停键鼠同步", isOn: Binding(get: { pet.pauseInputSync }, set: { pet.setPauseInputSync($0) }))

            TZHairline()
            simpleToggleRow(title: "键盘水平摆放", isOn: Binding(get: { pet.levelKeyboard }, set: { pet.setLevelKeyboard($0) }))

            TZHairline()
            simpleToggleRow(title: "鼠标点击气泡", isOn: Binding(get: { pet.showMouseBadges }, set: { pet.setShowMouseBadges($0) }))

            TZHairline()
            simpleToggleRow(title: "水平镜像翻转", isOn: Binding(get: { pet.flipHorizontal }, set: { pet.setFlipHorizontal($0) }))

            TZHairline()
            HStack(spacing: 10) {
                Text("旋转（\(Int(pet.rotationDeg.rounded()))°）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TZTheme.inkPrimary)
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
                .frame(width: 135)

                Button("回正") {
                    pet.setRotationDeg(0)
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
            }

            TZHairline()
            simpleToggleRow(title: "打字过快生气彩蛋", isOn: Binding(get: { pet.enableAnger }, set: { pet.setEnableAnger($0) }))

            TZHairline()
            HStack(spacing: 12) {
                Text("多键组合彩蛋")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TZTheme.inkPrimary)
                Spacer()
                Picker("", selection: Binding(get: { pet.typingLimbMode }, set: { pet.setTypingLimbMode($0) })) {
                    Text("后脚 + 尾巴").tag(0)
                    Text("仅翘后脚").tag(1)
                    Text("仅尾巴拍键").tag(2)
                    Text("仅前爪").tag(3)
                }
                .labelsHidden()
                .frame(width: 150)
            }

            TZHairline()
            HStack(spacing: 12) {
                Text("数位板模式")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TZTheme.inkPrimary)
                Spacer()
                TZSegmentedBar(
                    items: [
                        TZSegmentedBar.Item(title: "自动", isSelected: pet.tabletMode == 0, action: { pet.setTabletMode(0) }),
                        TZSegmentedBar.Item(title: "数位板", isSelected: pet.tabletMode == 1, action: { pet.setTabletMode(1) }),
                        TZSegmentedBar.Item(title: "鼠标", isSelected: pet.tabletMode == 2, action: { pet.setTabletMode(2) })
                    ],
                    compact: true
                )
                .frame(width: 170)
            }

            TZHairline()
            HStack(spacing: 10) {
                Text("整点猫头报时")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TZTheme.inkPrimary)
                Spacer()
                Button("试播") {
                    pet.testHourlyAnnouncement()
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                Toggle("", isOn: Binding(get: { pet.hourlyAnnouncement }, set: { pet.setHourlyAnnouncement($0) }))
                    .toggleStyle(.switch)
                    .tint(TZTheme.accent)
                    .labelsHidden()
            }

            TZHairline()
            simpleToggleRow(title: "减少动态效果", isOn: Binding(get: { pet.reducedMotion }, set: { pet.setReducedMotion($0) }))

            TZHairline()
            simpleToggleRow(title: "始终置顶于全屏上方", isOn: Binding(get: { pet.fullScreenOverlay }, set: { pet.setFullScreenOverlay($0) }))

            TZHairline()
            HStack(spacing: 12) {
                Text("OBS 捕获模式")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TZTheme.inkPrimary)
                Spacer()
                Picker("", selection: Binding(get: { pet.obsCaptureMode }, set: { pet.setOBSCaptureMode($0) })) {
                    Text("关闭").tag(0)
                    Text("透明窗口").tag(1)
                    Text("绿幕 (#00FF00)").tag(2)
                }
                .labelsHidden()
                .frame(width: 150)
            }

            if pet.obsCaptureMode > 0 {
                TZHairline()
                simpleToggleRow(title: "OBS 后台捕获", isOn: Binding(get: { pet.obsHideDesktop }, set: { pet.setOBSHideDesktop($0) }))
            }
        }
    }

    // MARK: - Subcomponents

    private func simpleToggleRow(title: String, hint: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TZTheme.inkPrimary)
                    .lineLimit(1)
                if let hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(TZTheme.accent)
                .labelsHidden()
        }
    }

    private func handleDroppedPhotoProviders(_ providers: [NSItemProvider]) -> Bool {
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

    private func customCatSelectionCard(for skin: SkinSpec) -> some View {
        let isSelected = (pet.customSkinID == skin.id)
        let bodyColor = Color(nsColor: skin.palette.body.srgbNS)
        let eyeL = Color(nsColor: (skin.palette.irisLeft ?? skin.palette.iris)?.srgbNS ?? NSColor.systemYellow)
        let eyeR = Color(nsColor: (skin.palette.irisRight ?? skin.palette.iris)?.srgbNS ?? NSColor.systemYellow)

        return HStack(spacing: 8) {
            Button {
                if !pet.isEnabled { pet.setEnabled(true) }
                pet.selectCustomSkin(id: skin.id)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        if let png = skin.preview, let nsImg = NSImage(data: png) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.4))
                        } else {
                            Circle()
                                .fill(bodyColor)
                                .frame(width: 34, height: 34)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.78), lineWidth: 1.4))
                            HStack(spacing: 3.5) {
                                Circle().fill(eyeL).frame(width: 6, height: 6)
                                Circle().fill(eyeR).frame(width: 6, height: 6)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(SkinLibrary.shared.displayName(for: skin))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(TZTheme.inkPrimary)
                                .lineLimit(1)
                            if isSelected {
                                Text("值班")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(TZTheme.accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(TZTheme.accentSoft)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(skin.fishDNA?.breedBadge ?? skin.photoDNA?.breedBadge ?? (skin.species == "fish" ? "我家小鱼" : "我家猫咪"))
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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                .buttonStyle(.plain)
                .help("编辑")

                Button {
                    pet.removeImportedSkin(id: skin.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TZTheme.inkMuted)
                }
                .buttonStyle(.plain)
                .help("删除")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9.5)
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
            if !pet.isEnabled { pet.setEnabled(true) }
            pet.selectBuiltInCoat(coat)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(swatchColors.coat)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.78), lineWidth: 1.4))
                    HStack(spacing: 3.5) {
                        Circle().fill(swatchColors.eye).frame(width: 6, height: 6)
                        Circle().fill(swatchColors.eye).frame(width: 6, height: 6)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        let customNick = CatSettings.shared.builtInNicknames[coat.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let baseTitle = coat == .orangeWhite ? "橘白猫 · 黄粽子" : coat.shortTitle
                        Text(customNick.isEmpty ? baseTitle : customNick)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                            .lineLimit(1)
                        if isSelected {
                            Text("值班")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(TZTheme.accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(TZTheme.accentSoft)
                                .clipShape(Capsule())
                        }
                    }
                    Text(coat.shortTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9.5)
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
}
