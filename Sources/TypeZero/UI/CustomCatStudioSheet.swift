import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Live Studio Preview Stage (Renders Unsaved Draft `SkinSpec` + Floating Name Bubble at 30fps!)

private final class StudioCatPreviewNSView: NSView {
    let physics = CatPhysics()
    var previewStyle: PetVisualStyle = .kuroSticker
    var draftSkin: SkinSpec? = nil
    var catName: String = "年糕"
    var showNameBubble: Bool = true
    var onDropPhoto: ((URL) -> Void)?

    private var animTimer: Timer?
    private var lastTick: CFTimeInterval = CACurrentMediaTime()
    private var bubblePhase: CGFloat = 0

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        registerForDraggedTypes([.fileURL])
        if window != nil {
            startLoop()
        } else {
            stopLoop()
        }
    }

    deinit {
        animTimer?.invalidate()
    }

    private func startLoop() {
        guard animTimer == nil else { return }
        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = CACurrentMediaTime()
            let dt = CGFloat(min(0.08, max(0.001, now - self.lastTick)))
            self.lastTick = now
            self.bubblePhase += dt
            let cursorPt = CGPoint(x: 180 + sin(now * 1.35) * 58, y: 168 + cos(now * 0.95) * 22)
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
                cursorStagePt: CGPoint(x: 230 + sin(now * 1.35) * 65, y: 175 + cos(now * 0.95) * 25),
                screenMousePt: cursorPt,
                paused: false,
                privacy: false,
                reducedMotion: false
            )
            self.needsDisplay = true
        }
        RunLoop.main.add(t, forMode: .common)
        animTimer = t
    }

    private func stopLoop() {
        animTimer?.invalidate()
        animTimer = nil
    }

    override func mouseDown(with event: NSEvent) {
        let keys: [PhysicalKey] = [.c, .a, .t, .m, .e, .o, .w, .space]
        let pick = keys.randomElement() ?? .j
        physics.triggerVoiceKeyDown(pick)
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
        guard let first = urls.first(where: { Self.photoExts.contains($0.pathExtension.lowercased()) }) else { return false }
        DispatchQueue.main.async { [weak self] in self?.onDropPhoto?(first) }
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        let activeSpec = draftSkin ?? CatSettings.shared.activeSkin
        let trimmedName = catName.trimmingCharacters(in: .whitespacesAndNewlines)
        let accent: NSColor = {
            if let iris = activeSpec.palette.irisLeft ?? activeSpec.palette.iris {
                return NSColor(srgbRed: iris.r, green: iris.g, blue: iris.b, alpha: 1.0)
            }
            return NSColor.systemYellow
        }()

        if previewStyle == .clackOriginal {
            let stageW: CGFloat = 420
            let stageH: CGFloat = 365
            let sc = min(bounds.width / stageW, bounds.height / stageH)
            let ox = (bounds.width - stageW * sc) * 0.5
            let oy = (bounds.height - stageH * sc) * 0.5 + 8
            ctx.saveGState()
            ctx.translateBy(x: ox, y: oy)
            ctx.scaleBy(x: sc, y: sc)
            ClackRenderer.drawStage(
                in: ctx,
                pose: physics.clackSim.pose,
                breed: CatSettings.shared.coatTheme,
                handover: nil,
                customSkin: activeSpec,
                anchorX: 196,
                anchorY: 332,
                baseScale: 0.78,
                whiteOutline: CatSettings.shared.whiteOutline,
                showKeyLabels: true,
                showKeyBubbles: true
            )
            if showNameBubble, !trimmedName.isEmpty {
                CatCanvasView.drawCatNameBadgeStatic(
                    in: ctx,
                    headCenterX: 196 + physics.clackSim.pose.headLean.x * 0.62,
                    headTopY: 84 + physics.clackSim.pose.headLean.y * 0.62,
                    minX: 8,
                    maxX: stageW - 8,
                    minY: 2,
                    name: trimmedName,
                    mood: "🐾",
                    accentColor: accent,
                    alpha: 1.0,
                    phase: bubblePhase
                )
            }
            ctx.restoreGState()
        } else {
            let stageW = CatPhysics.canvasSize.width
            let stageH = CatPhysics.canvasSize.height + 38
            let s = min(bounds.width / stageW, bounds.height / stageH)
            let ox = (bounds.width - stageW * s) * 0.5
            let oy = (bounds.height - stageH * s) * 0.5 + 24 * s

            ctx.saveGState()
            ctx.translateBy(x: ox, y: oy)
            ctx.scaleBy(x: s, y: s)
            CatRenderer.draw(
                in: ctx,
                physics: physics,
                showPermissionPill: false,
                isPreview: true,
                customSkinOverride: activeSpec
            )
            if showNameBubble, !trimmedName.isEmpty {
                let hc = CatRenderer.headPosition(physics, skin: activeSpec)
                CatCanvasView.drawCatNameBadgeStatic(
                    in: ctx,
                    headCenterX: hc.x,
                    headTopY: hc.y - 38.0 * activeSpec.shape.headScale,
                    minX: 8,
                    maxX: stageW - 8,
                    minY: -36,
                    name: trimmedName,
                    mood: "🐾",
                    accentColor: accent,
                    alpha: 1.0,
                    phase: bubblePhase
                )
            }
            ctx.restoreGState()
        }
    }
}

private struct StudioCatPreviewStage: NSViewRepresentable {
    let previewStyle: PetVisualStyle
    let draftSkin: SkinSpec?
    let revision: Int
    let catName: String
    let showNameBubble: Bool
    let onDropPhoto: (URL) -> Void

    func makeNSView(context: Context) -> StudioCatPreviewNSView {
        let v = StudioCatPreviewNSView()
        v.onDropPhoto = onDropPhoto
        return v
    }

    func updateNSView(_ nsView: StudioCatPreviewNSView, context: Context) {
        _ = revision
        nsView.previewStyle = previewStyle
        nsView.draftSkin = draftSkin
        nsView.catName = catName
        nsView.showNameBubble = showNameBubble
        nsView.onDropPhoto = onDropPhoto
        nsView.needsDisplay = true
    }
}

// MARK: - Custom Cat Photo Studio Modal Sheet

struct CustomCatStudioSheet: View {
    @ObservedObject var appState: AppState
    @ObservedObject var pet: PetCompanionController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var dna: CatPhotoDNA = CatPhotoDNA()
    @State private var previewPNGData: Data? = nil
    @State private var uploadedPhotoImage: NSImage? = nil
    @State private var draftSkin: SkinSpec? = nil
    @State private var draftRevision: Int = 0
    @State private var previewStyle: PetVisualStyle = .kuroSticker
    @State private var enableHeadNameBubble: Bool = true
    @State private var isAnalyzingPhoto: Bool = false
    @State private var analysisBanner: String = "上传一张自家猫咪的照片，自动还原毛色、开脸、异瞳与白手套，完美保留全部动画与顶额头换班！"
    @State private var errorMessage: String = ""
    @State private var didBootstrap: Bool = false

    private let suggestedNames = ["年糕", "煤球", "咪咪", "布丁", "大橘", "警长", "糯米"]

    var body: some View {
        VStack(spacing: 0) {
            studioHeader
            Divider().overlay(TZTheme.cardBorder)

            HStack(alignment: .top, spacing: 20) {
                leftPreviewColumn
                    .frame(width: 286)

                ScrollView(.vertical, showsIndicators: false) {
                    rightControlsColumn
                        .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)

            Divider().overlay(TZTheme.cardBorder)
            studioFooter
        }
        .frame(width: 810, height: 600)
        .background(TZTheme.canvasBg)
        .onAppear {
            bootstrapInitialStateIfNeeded()
        }
        .onChange(of: dna) { _, _ in
            recompileDraftSkin()
        }
    }

    // MARK: - Header

    private var studioHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(TZTheme.accentSoft)
                    .frame(width: 34, height: 34)
                Image(systemName: "cat.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TZTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(pet.editingStudioSkinID == nil ? "上传照片 · 定制我家猫咪" : "微调我家猫咪花色与名字")
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text(analysisBanner)
                    .font(.system(size: 11.5))
                    .foregroundStyle(isAnalyzingPhoto ? TZTheme.accent : TZTheme.inkSecondary)
                    .lineLimit(1)
            }
            Spacer()

            Button {
                choosePhotoViaOpenPanel()
            } label: {
                HStack(spacing: 5) {
                    if isAnalyzingPhoto {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(uploadedPhotoImage == nil ? "选择猫咪照片…" : "重新选一张照片…")
                }
            }
            .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
            .disabled(isAnalyzingPhoto)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Left Column: Live 60fps Animated Cat + Uploaded Photo Card

    private var leftPreviewColumn: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: scheme == .dark
                                ? [Color(red: 0.11, green: 0.12, blue: 0.19), Color(red: 0.07, green: 0.08, blue: 0.13)]
                                : [Color(red: 0.94, green: 0.95, blue: 0.99), Color(red: 0.88, green: 0.90, blue: 0.97)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(TZTheme.cardBorder, lineWidth: 1)
                    )

                StudioCatPreviewStage(
                    previewStyle: previewStyle,
                    draftSkin: draftSkin,
                    revision: draftRevision,
                    catName: dna.name,
                    showNameBubble: enableHeadNameBubble,
                    onDropPhoto: { url in
                        runPhotoAnalysis(from: url)
                    }
                )
                .padding(8)

                HStack(spacing: 6) {
                    Text(dna.breedBadge)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(TZTheme.accentSoft)
                        .clipShape(Capsule())

                    Text("点击小猫试敲键盘")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TZTheme.inkMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 9)
            }
            .frame(height: 248)

            // Style Switcher inside Live Preview
            TZSegmentedBar(
                items: PetVisualStyle.allCases.map { st in
                    TZSegmentedBar.Item(
                        title: st.title,
                        isSelected: previewStyle == st,
                        action: { previewStyle = st }
                    )
                },
                compact: true
            )

            // Photo Upload / Drop Card
            Button {
                choosePhotoViaOpenPanel()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        if let img = uploadedPhotoImage {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 58, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.2)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(TZTheme.accentSoft.opacity(0.75))
                                .frame(width: 58, height: 58)
                                .overlay(
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundStyle(TZTheme.accent)
                                )
                        }
                        if isAnalyzingPhoto {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.45))
                                .frame(width: 58, height: 58)
                            ProgressView().controlSize(.small)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(uploadedPhotoImage == nil ? "点击上传或拖入猫咪照片" : "已加载自家猫咪参考照")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Text("支持 JPG / PNG / HEIC / WebP\n自动剥离背景与黄光色偏，生成动态骨骼")
                            .font(.system(size: 10.5))
                            .foregroundStyle(TZTheme.inkSecondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(1.5)
                    }
                    Spacer(minLength: 0)
                }
                .padding(11)
                .background(TZTheme.recessedWell.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(TZTheme.accent.opacity(uploadedPhotoImage == nil ? 0.45 : 0.22), style: StrokeStyle(lineWidth: 1, dash: uploadedPhotoImage == nil ? [5, 3] : []))
                )
            }
            .buttonStyle(.plain)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDroppedProviders(providers)
            }
        }
    }

    // MARK: - Right Column: Naming + Fine-Tune Studio

    private var rightControlsColumn: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 7) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TZTheme.accent)
                Text("以下参数由 AI 从照片自动提取生成 — 修改任意色块或开关，左侧猫咪 0 延迟实时同步")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TZTheme.accentSoft.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            // 1. Cat Naming & Head Bubble Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("给猫咪起个名字", systemImage: "tag.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    Toggle(isOn: $enableHeadNameBubble) {
                        Text("偶尔出现在脑袋上")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(TZTheme.accent)
                }

                TextField("输入自家猫咪名字（如：年糕、煤球、咪咪）", text: $dna.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, weight: .medium))

                HStack(spacing: 6) {
                    Text("灵感昵称：")
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkMuted)
                    ForEach(suggestedNames, id: \.self) { sample in
                        Button(sample) {
                            dna.name = sample
                        }
                        .font(.system(size: 11, weight: dna.name == sample ? .semibold : .regular))
                        .foregroundStyle(dna.name == sample ? TZTheme.accent : TZTheme.inkSecondary)
                        .padding(.horizontal, 7.5)
                        .padding(.vertical, 2.5)
                        .background(dna.name == sample ? TZTheme.accentSoft : TZTheme.recessedWell)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(13)
            .tzElevatedCard()

            // 2. Coat Family & Face Blaze
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Label("花色底板与开脸样式（实时同步左侧动画）", systemImage: "paintbrush.pointed.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    if dna.patternFamily == .calico || dna.patternFamily == .tuxedoBicolor || dna.patternFamily == .tortoiseshell {
                        Button {
                            dna.patchSeed = (dna.patchSeed + 13) % 997
                        } label: {
                            HStack(spacing: 3.5) {
                                Image(systemName: "dice.fill")
                                    .font(.system(size: 10.5))
                                Text("微调斑块位置")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(TZTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("整体花色底板")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)
                        Picker("", selection: $dna.patternFamily) {
                            ForEach(CatPatternFamily.allCases) { fam in
                                Text(fam.title).tag(fam)
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("面部开脸 / 刘海")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)
                        Picker("", selection: $dna.faceBlaze) {
                            ForEach(CatFaceBlaze.allCases) { bz in
                                Text(bz.title).tag(bz)
                            }
                        }
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if dna.faceBlaze == .invertedV || dna.patternFamily == .calico || dna.patternFamily == .ragdollBicolor {
                    HStack(spacing: 10) {
                        Text("八字开脸宽度")
                            .font(.system(size: 11.5))
                            .foregroundStyle(TZTheme.inkSecondary)
                        Slider(value: $dna.blazeWidth, in: 0.28...0.86)
                            .tint(TZTheme.accent)
                    }
                }
            }
            .padding(13)
            .tzElevatedCard()

            // 3. Palette Swatches (Fur + Heterochromia Eyes + Nose)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("毛色、鼻头与瞳色（支持鸳鸯异瞳）", systemImage: "eyedropper.halffull")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    Toggle(isOn: $dna.heterochromia) {
                        Text("鸳鸯异瞳")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                }

                HStack(spacing: 12) {
                    hexColorControl(title: primaryColorLabel, hex: $dna.primaryFurHex)
                    hexColorControl(title: secondaryColorLabel, hex: $dna.secondaryFurHex)
                    if usesTertiaryColor {
                        hexColorControl(title: tertiaryColorLabel, hex: $dna.tertiaryFurHex)
                    }
                    hexColorControl(title: "鼻头色", hex: $dna.noseHex)
                }

                // Quick 1-click Fur Tone Presets so dark/black/brown/silver/ginger cats snap to exact richness immediately!
                HStack(spacing: 6) {
                    Text("主毛色快选：")
                        .font(.system(size: 10.5))
                        .foregroundStyle(TZTheme.inkMuted)
                    ForEach([
                        ("绒黑", "#19191E"),
                        ("黑狸深炭", "#3A322B"),
                        ("深巧褐", "#4A3528"),
                        ("暖灰褐", "#685C50"),
                        ("英短蓝", "#6E7887"),
                        ("美短银", "#B8BDBC"),
                        ("大橘金", "#DC954B"),
                        ("纯奶白", "#F6F2EA")
                    ], id: \.0) { label, presetHex in
                        Button {
                            dna.primaryFurHex = presetHex
                        } label: {
                            HStack(spacing: 3.5) {
                                Circle()
                                    .fill(Color(nsColor: CatCoatCompiler.swiftUIColor(presetHex)))
                                    .frame(width: 9, height: 9)
                                    .overlay(Circle().strokeBorder(Color.black.opacity(0.22), lineWidth: 0.6))
                                Text(label)
                                    .font(.system(size: 10.5))
                            }
                            .foregroundStyle(dna.primaryFurHex == presetHex ? TZTheme.accent : TZTheme.inkSecondary)
                            .padding(.horizontal, 6.5)
                            .padding(.vertical, 2.5)
                            .background(dna.primaryFurHex == presetHex ? TZTheme.accentSoft : TZTheme.recessedWell)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 14) {
                    hexColorControl(title: dna.heterochromia ? "左眼瞳色" : "双眼瞳色", hex: Binding(
                        get: { dna.irisLeftHex },
                        set: { newVal in
                            dna.irisLeftHex = newVal
                            if !dna.heterochromia {
                                dna.irisRightHex = newVal
                            }
                        }
                    ))
                    if dna.heterochromia {
                        hexColorControl(title: "右眼瞳色", hex: $dna.irisRightHex)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Text("发腮圆脸")
                            .font(.system(size: 11.5))
                            .foregroundStyle(TZTheme.inkSecondary)
                        Slider(value: $dna.cheekFullness, in: 0.88...1.22)
                            .tint(TZTheme.accent)
                            .frame(width: 105)
                    }
                }
            }
            .padding(13)
            .tzElevatedCard()

            // 4. Anatomical Details (Chest Bib, Socks, Stripes, Build)
            VStack(alignment: .leading, spacing: 10) {
                Label("胸围脖、白手套踏雪与条纹细节", systemImage: "pawprint.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TZTheme.inkPrimary)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("胸口白毛")
                            .font(.system(size: 11))
                            .foregroundStyle(TZTheme.inkSecondary)
                        Picker("", selection: $dna.chestBib) {
                            ForEach(CatChestBibStyle.allCases) { b in
                                Text(b.title).tag(b)
                            }
                        }
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("左前爪")
                            .font(.system(size: 11))
                            .foregroundStyle(TZTheme.inkSecondary)
                        Picker("", selection: $dna.frontLeftSock) {
                            ForEach(CatSockStyle.allCases) { s in
                                Text(s.title).tag(s)
                            }
                        }
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("右前爪")
                            .font(.system(size: 11))
                            .foregroundStyle(TZTheme.inkSecondary)
                        Picker("", selection: $dna.frontRightSock) {
                            ForEach(CatSockStyle.allCases) { s in
                                Text(s.title).tag(s)
                            }
                        }
                        .labelsHidden()
                    }
                }

                FlowTraitChips(dna: $dna)
            }
            .padding(13)
            .tzElevatedCard()
        }
    }

    // MARK: - Footer

    private var studioFooter: some View {
        HStack(spacing: 12) {
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.red)
            } else {
                Text("💡 领养后完整继承 60fps 敲键、摸头呼噜、揪后颈、打盹及 10.58 秒原版「顶额头吵架换班」！")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
            Spacer()

            Button("取消") {
                dismiss()
            }
            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

            Button {
                adoptAndActivateCat()
            } label: {
                HStack(spacing: 5.5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    let displayName = dna.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "小咪" : dna.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(pet.editingStudioSkinID == nil ? "领养「\(displayName)」并上岗换班！" : "保存「\(displayName)」的修改")
                }
            }
            .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
            .disabled(isAnalyzingPhoto)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }

    // MARK: - Helpers & Actions

    private var usesTertiaryColor: Bool {
        switch dna.patternFamily {
        case .calico, .tortoiseshell, .tabby, .tabbyBicolor, .shaded:
            return true
        default:
            return false
        }
    }

    private var primaryColorLabel: String {
        switch dna.patternFamily {
        case .calico: return "底毛白"
        case .ragdollBicolor: return "耳背重点色"
        case .colorpoint: return "身体浅底色"
        case .shaded: return "背顶渐层色"
        default: return "主毛色"
        }
    }

    private var secondaryColorLabel: String {
        switch dna.patternFamily {
        case .calico: return "橘斑色"
        case .tortoiseshell: return "琥珀金斑"
        case .colorpoint: return "挖煤重点色"
        default: return "白毛 / 副色"
        }
    }

    private var tertiaryColorLabel: String {
        switch dna.patternFamily {
        case .calico: return "墨黑斑色"
        case .tortoiseshell: return "浅奶油斑"
        case .shaded: return "尾尖细纹色"
        default: return "虎斑条纹色"
        }
    }

    private func hexColorControl(title: String, hex: Binding<String>) -> some View {
        HStack(spacing: 6) {
            ColorPicker("", selection: Binding(
                get: { Color(nsColor: CatCoatCompiler.swiftUIColor(hex.wrappedValue)) },
                set: { newColor in
                    hex.wrappedValue = CatCoatCompiler.hexString(from: NSColor(newColor))
                }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 24, height: 24)

            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(TZTheme.inkPrimary)
        }
    }

    private func bootstrapInitialStateIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        previewStyle = pet.visualStyle
        enableHeadNameBubble = pet.showOccasionalNameBubble

        if let editID = pet.editingStudioSkinID,
           let existing = SkinLibrary.shared.skin(id: editID) {
            if let existingDNA = existing.photoDNA {
                dna = existingDNA
            } else {
                dna.name = existing.name
                dna.primaryFurHex = CatCoatCompiler.hexString(from: existing.palette.body.srgbNS)
            }
            if let prev = existing.preview, let nsImg = NSImage(data: prev) {
                previewPNGData = prev
                uploadedPhotoImage = nsImg
            }
            analysisBanner = "正在编辑「\(existing.name)」的花色参数与专属名字"
            recompileDraftSkin()
            return
        }

        recompileDraftSkin()

        if let initialURL = pet.pendingStudioPhotoURL {
            pet.pendingStudioPhotoURL = nil
            runPhotoAnalysis(from: initialURL)
        }
    }

    private func recompileDraftSkin() {
        if let compiled = try? CatCoatCompiler.compileSkinSpec(from: dna, previewPNG: previewPNGData) {
            draftSkin = compiled
            draftRevision += 1
        }
    }

    private func choosePhotoViaOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "选择一张自家猫咪的照片"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .webP]
        if panel.runModal() == .OK, let url = panel.url {
            runPhotoAnalysis(from: url)
        }
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let resolvedURL: URL? = {
                if let data = item as? Data {
                    return URL(dataRepresentation: data, relativeTo: nil)
                }
                return item as? URL
            }()
            if let url = resolvedURL {
                Task { @MainActor in
                    runPhotoAnalysis(from: url)
                }
            }
        }
        return true
    }

    private func runPhotoAnalysis(from url: URL) {
        errorMessage = ""
        isAnalyzingPhoto = true
        analysisBanner = "🔍 正在识别猫咪前景轮廓、剥离光线色偏并还原花纹骨骼…"
        if let img = NSImage(contentsOf: url) {
            uploadedPhotoImage = img
        }
        let existingCustomName = (dna.name != "年糕" && !dna.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? dna.name : ""
        let cfg = appState.llmConfig
        let byokKey = appState.apiKeyInput
        let jwt = KeychainHelper.loadCloudJWT()

        Task {
            do {
                let res = try await PhotoCatAnalyzer.analyzeImage(
                    at: url,
                    preferredName: existingCustomName,
                    llmConfig: cfg,
                    byokAPIKey: byokKey,
                    cloudJWT: jwt
                )
                await MainActor.run {
                    self.previewPNGData = res.previewPNG
                    if let croppedNS = NSImage(data: res.previewPNG) {
                        self.uploadedPhotoImage = croppedNS
                    }
                    self.dna = res.dna
                    self.analysisBanner = res.sourceSummary
                    self.isAnalyzingPhoto = false
                    self.recompileDraftSkin()
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzingPhoto = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func adoptAndActivateCat() {
        errorMessage = ""
        do {
            let jsonData = try CatCoatCompiler.compileJSONData(from: dna, previewPNG: previewPNGData)
            if previewStyle != pet.visualStyle {
                pet.setVisualStyle(previewStyle)
            }
            try pet.adoptCompiledCatSkin(
                jsonData: jsonData,
                replacingSkinID: pet.editingStudioSkinID,
                enableNameBubble: enableHeadNameBubble
            )
            pet.editingStudioSkinID = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FlowTraitChips: View {
    @Binding var dna: CatPhotoDNA

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                chip(title: "额头 M 纹", isOn: $dna.foreheadM)
                chip(title: "脸颊眼线纹", isOn: $dna.cheekStripes)
                chip(title: "虎斑尾环", isOn: $dna.tailRings)
                chip(title: "异色尾尖", isOn: $dna.tailTipDip)
            }
            HStack(spacing: 7) {
                chip(title: "后爪白袜", isOn: $dna.hindSocks)
                chip(title: "俏皮下巴豆", isOn: $dna.chinSpot)
                chip(title: "修长流线体型", isOn: $dna.isSleekBuild)
            }
        }
    }

    private func chip(title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(isOn.wrappedValue ? TZTheme.accent : TZTheme.inkSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(isOn.wrappedValue ? TZTheme.accentSoft : TZTheme.recessedWell)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
