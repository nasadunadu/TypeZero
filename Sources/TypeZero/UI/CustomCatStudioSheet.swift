import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Live Studio Preview Stage (30fps Animated Cat + Head-Top Name Bubble)

private final class StudioCatPreviewNSView: NSView {
    let physics = CatPhysics()
    var previewStyle: PetVisualStyle = .kuroSticker
    var draftSkin: SkinSpec? = nil
    var catName: String = "小咪"
    var showNameBubble: Bool = true
    var onDropPhotos: (([URL]) -> Void)?

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
        let photos = urls.filter { Self.photoExts.contains($0.pathExtension.lowercased()) }
        guard !photos.isEmpty else { return false }
        DispatchQueue.main.async { [weak self] in self?.onDropPhotos?(photos) }
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
    let onDropPhotos: ([URL]) -> Void

    func makeNSView(context: Context) -> StudioCatPreviewNSView {
        let v = StudioCatPreviewNSView()
        v.onDropPhotos = onDropPhotos
        return v
    }

    func updateNSView(_ nsView: StudioCatPreviewNSView, context: Context) {
        _ = revision
        nsView.previewStyle = previewStyle
        nsView.draftSkin = draftSkin
        nsView.catName = catName
        nsView.showNameBubble = showNameBubble
        nsView.onDropPhotos = onDropPhotos
        nsView.needsDisplay = true
    }
}

// MARK: - Simplified Consumer Custom Cat Studio Sheet (Multi-Photo + Name + Light Tweaks)

private struct UploadedCatPhotoSlot: Identifiable, Equatable {
    let id = UUID()
    let cgImage: CGImage
    let thumbnail: NSImage

    static func == (lhs: UploadedCatPhotoSlot, rhs: UploadedCatPhotoSlot) -> Bool {
        lhs.id == rhs.id
    }
}

struct CustomCatStudioSheet: View {
    @ObservedObject var appState: AppState
    @ObservedObject var pet: PetCompanionController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var dna: CatPhotoDNA = CatPhotoDNA()
    @State private var photoSlots: [UploadedCatPhotoSlot] = []
    @State private var previewPNGData: Data? = nil
    @State private var draftSkin: SkinSpec? = nil
    @State private var draftRevision: Int = 0
    @State private var previewStyle: PetVisualStyle = .kuroSticker
    @State private var enableHeadNameBubble: Bool = true
    @State private var isAnalyzingPhoto: Bool = false
    @State private var errorMessage: String = ""
    @State private var didBootstrap: Bool = false

    private let furSwatches: [(label: String, primary: String, stripe: String?)] = [
        ("纯黑", "#19191E", nil),
        ("黑狸", "#3A322B", "#141314"),
        ("棕狸", "#7D6752", "#2D2520"),
        ("橘猫", "#DF8B3E", "#AE5721"),
        ("蓝灰", "#737E8E", "#464E59"),
        ("三花", "#F6F2E9", "#232227"),
        ("纯白", "#F6F4EE", nil)
    ]

    private let eyeSwatches: [(label: String, left: String, right: String, hetero: Bool)] = [
        ("翠绿", "#5A9456", "#5A9456", false),
        ("琥珀", "#DE9A38", "#DE9A38", false),
        ("金黄", "#D8E550", "#D8E550", false),
        ("冰蓝", "#64C1F8", "#64C1F8", false),
        ("异瞳", "#64C1F8", "#E3AC38", true)
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().overlay(TZTheme.cardBorder)

            HStack(alignment: .top, spacing: 18) {
                leftPreviewCard
                    .frame(width: 248)

                rightSimpleColumn
                    .frame(maxWidth: .infinity)
            }
            .padding(18)

            Divider().overlay(TZTheme.cardBorder)
            footerBar
        }
        .frame(width: 676, height: 452)
        .background(TZTheme.canvasBg)
        .onAppear {
            bootstrapInitialStateIfNeeded()
        }
        .onChange(of: dna) { _, _ in
            recompileDraftSkin()
        }
    }

    // MARK: - Clean Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "cat.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(TZTheme.accent)

            Text("定制我家猫咪")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(TZTheme.inkPrimary)

            Spacer()

            if isAnalyzingPhoto {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("正在生成…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TZTheme.accent)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Left Column: Live Cat Preview + Style Switch

    private var leftPreviewCard: some View {
        VStack(spacing: 10) {
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

                StudioCatPreviewStage(
                    previewStyle: previewStyle,
                    draftSkin: draftSkin,
                    revision: draftRevision,
                    catName: dna.name,
                    showNameBubble: enableHeadNameBubble,
                    onDropPhotos: { urls in
                        appendPhotosAndAnalyze(urls: urls)
                    }
                )
                .padding(6)

                HStack(spacing: 6) {
                    Text(dna.breedBadge)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(TZTheme.accentSoft)
                        .clipShape(Capsule())

                    Text("点小猫试敲")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TZTheme.inkMuted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)

            TZSegmentedBar(
                items: [
                    TZSegmentedBar.Item(
                        title: "贴纸风",
                        isSelected: previewStyle == .kuroSticker,
                        action: { previewStyle = .kuroSticker }
                    ),
                    TZSegmentedBar.Item(
                        title: "立体风",
                        isSelected: previewStyle == .clackOriginal,
                        action: { previewStyle = .clackOriginal }
                    )
                ],
                compact: true
            )
        }
    }

    // MARK: - Right Column: 1) Photos (1–4)  2) Name  3) Simple Tweaks

    private var rightSimpleColumn: some View {
        VStack(spacing: 11) {
            photoStripCard
            nameCard
            lightTweaksCard
            Spacer(minLength: 0)
        }
    }

    // 1. Multi-Photo Upload & Supplement Card (`1–4` photos)
    private var photoStripCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("猫咪照片")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(TZTheme.inkPrimary)

                if !photoSlots.isEmpty {
                    Text("\(photoSlots.count)/\(PhotoCatAnalyzer.maxPhotoCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TZTheme.inkMuted)
                }

                Spacer()

                if !photoSlots.isEmpty {
                    Button {
                        rerunMultiPhotoAnalysis()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10.5, weight: .semibold))
                            Text("重新制作")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(TZTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAnalyzingPhoto)
                }
            }

            if photoSlots.isEmpty {
                Button {
                    pickPhotosViaOpenPanel()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(TZTheme.accentSoft)
                                .frame(width: 44, height: 44)
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(TZTheme.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("上传猫咪照片")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("可传 1–4 张不同角度，细节更准")
                                .font(.system(size: 11))
                                .foregroundStyle(TZTheme.inkSecondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(TZTheme.recessedWell.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzingPhoto)
            } else {
                HStack(spacing: 9) {
                    ForEach(photoSlots) { slot in
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: slot.thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(TZTheme.cardBorder, lineWidth: 1)
                                )

                            Button {
                                removePhotoSlot(slot.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.black.opacity(0.65))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: -4)
                            .disabled(isAnalyzingPhoto)
                        }
                    }

                    if photoSlots.count < PhotoCatAnalyzer.maxPhotoCount {
                        Button {
                            pickPhotosViaOpenPanel()
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("补充照片")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(TZTheme.accent)
                            .frame(width: 54, height: 54)
                            .background(TZTheme.accentSoft.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(TZTheme.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isAnalyzingPhoto)
                    }

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(TZTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(TZTheme.cardBorder, lineWidth: 1)
        )
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDroppedProviders(providers)
        }
    }

    // 2. Clean Name Card
    private var nameCard: some View {
        HStack(spacing: 10) {
            Text("名字")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(TZTheme.inkPrimary)

            TextField("给猫咪起个名字", text: $dna.name)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 4)

            Text("偶尔冒出")
                .font(.system(size: 11.5))
                .foregroundStyle(TZTheme.inkSecondary)

            Toggle("", isOn: $enableHeadNameBubble)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(TZTheme.accent)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(TZTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(TZTheme.cardBorder, lineWidth: 1)
        )
    }

    // 3. Minimal 3-Row Appearance Adjustment Card (Fur Dots + Eye Dots + 4 Plain-Language Feature Pills)
    private var lightTweaksCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("微调外观")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(TZTheme.inkPrimary)

            // Row A: Coat color swatches
            HStack(spacing: 8) {
                Text("毛色")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkSecondary)
                    .frame(width: 30, alignment: .leading)

                ForEach(furSwatches, id: \.label) { item in
                    let isSelected = dna.primaryFurHex.caseInsensitiveCompare(item.primary) == .orderedSame
                    Button {
                        applyFurPreset(item)
                    } label: {
                        VStack(spacing: 3) {
                            Circle()
                                .fill(Color(nsColor: CatCoatCompiler.swiftUIColor(item.primary)))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .strokeBorder(isSelected ? TZTheme.accent : Color.primary.opacity(0.18), lineWidth: isSelected ? 2.2 : 1)
                                )
                            Text(item.label)
                                .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? TZTheme.accent : TZTheme.inkSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 2)

                ColorPicker("", selection: Binding(
                    get: { Color(nsColor: CatCoatCompiler.swiftUIColor(dna.primaryFurHex)) },
                    set: { newCol in
                        dna.primaryFurHex = CatCoatCompiler.hexString(from: NSColor(newCol))
                    }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 22, height: 22)
            }

            // Row B: Eye color swatches
            HStack(spacing: 10) {
                Text("眼睛")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkSecondary)
                    .frame(width: 30, alignment: .leading)

                ForEach(eyeSwatches, id: \.label) { eye in
                    let isSelected = (dna.heterochromia == eye.hetero) && (dna.irisLeftHex.caseInsensitiveCompare(eye.left) == .orderedSame)
                    Button {
                        dna.heterochromia = eye.hetero
                        dna.irisLeftHex = eye.left
                        dna.irisRightHex = eye.right
                    } label: {
                        HStack(spacing: 4) {
                            if eye.hetero {
                                HStack(spacing: 0) {
                                    Color(nsColor: CatCoatCompiler.swiftUIColor(eye.left))
                                    Color(nsColor: CatCoatCompiler.swiftUIColor(eye.right))
                                }
                                .frame(width: 16, height: 16)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(nsColor: CatCoatCompiler.swiftUIColor(eye.left)))
                                    .frame(width: 16, height: 16)
                            }
                            Text(eye.label)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? TZTheme.accent : TZTheme.inkPrimary)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(isSelected ? TZTheme.accentSoft : TZTheme.recessedWell)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }

            // Row C: 4 Plain-Language Feature Toggles
            HStack(spacing: 7) {
                Text("细节")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkSecondary)
                    .frame(width: 30, alignment: .leading)

                simplePill(title: "虎斑纹", isOn: hasTabbyStripes) {
                    toggleTabbyStripes()
                }
                simplePill(title: "白嘴套", isOn: dna.faceBlaze != .none && dna.faceBlaze != .sealMask) {
                    dna.faceBlaze = (dna.faceBlaze == .none || dna.faceBlaze == .sealMask) ? .noseBridgeBlaze : .none
                }
                simplePill(title: "白领巾", isOn: dna.chestBib != .none) {
                    dna.chestBib = (dna.chestBib == .none) ? .triangleCollar : .none
                }
                simplePill(title: "白手套", isOn: dna.frontLeftSock != .none || dna.frontRightSock != .none) {
                    let next: CatSockStyle = (dna.frontLeftSock == .none && dna.frontRightSock == .none) ? .mitten : .none
                    dna.frontLeftSock = next
                    dna.frontRightSock = next
                    dna.hindSocks = (next != .none)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(TZTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(TZTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Clean Footer

    private var footerBar: some View {
        HStack(spacing: 10) {
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
            Spacer()

            Button("取消") {
                dismiss()
            }
            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

            Button {
                adoptAndActivateCat()
            } label: {
                Text(pet.editingStudioSkinID == nil ? "放到桌面" : "保存")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
            .disabled(isAnalyzingPhoto)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Simple Preset & Feature Helpers

    private var hasTabbyStripes: Bool {
        dna.patternFamily == .tabby || dna.patternFamily == .tabbyBicolor
    }

    private func applyFurPreset(_ item: (label: String, primary: String, stripe: String?)) {
        dna.primaryFurHex = item.primary
        if item.label == "三花" {
            dna.patternFamily = .calico
            dna.secondaryFurHex = "#DC8E43"
            dna.tertiaryFurHex = "#232227"
            dna.faceBlaze = .invertedV
            dna.chestBib = .fullBib
            dna.breedBadge = "三花小猫"
        } else if let st = item.stripe {
            dna.tertiaryFurHex = st
            dna.patternFamily = (dna.chestBib != .none || dna.faceBlaze != .none) ? .tabbyBicolor : .tabby
            dna.foreheadM = true
            dna.cheekStripes = true
            dna.tailRings = true
            dna.tailTipDip = false
            dna.breedBadge = item.label + "小猫"
        } else {
            dna.patternFamily = (dna.chestBib != .none || dna.faceBlaze != .none) ? .tuxedoBicolor : .solid
            dna.foreheadM = false
            dna.cheekStripes = false
            dna.tailRings = false
            dna.breedBadge = item.label + "小猫"
        }
    }

    private func toggleTabbyStripes() {
        if hasTabbyStripes {
            dna.patternFamily = (dna.chestBib != .none || dna.faceBlaze != .none) ? .tuxedoBicolor : .solid
            dna.foreheadM = false
            dna.cheekStripes = false
            dna.tailRings = false
        } else {
            dna.patternFamily = (dna.chestBib != .none || dna.faceBlaze != .none) ? .tabbyBicolor : .tabby
            dna.foreheadM = true
            dna.cheekStripes = true
            dna.tailRings = true
            dna.tailTipDip = false
            if CatCoatCompiler.luminance(of: dna.primaryFurHex) < 0.14 {
                dna.primaryFurHex = "#3A322B"
            }
            dna.tertiaryFurHex = "#141314"
        }
    }

    private func simplePill(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3.5) {
                Image(systemName: isOn ? "checkmark" : "plus")
                    .font(.system(size: 9.5, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: isOn ? .semibold : .medium))
            }
            .foregroundStyle(isOn ? TZTheme.accent : TZTheme.inkSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(isOn ? TZTheme.accentSoft : TZTheme.recessedWell)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Multi-Photo Lifecycle & Actions

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
            if let prev = existing.preview,
               let nsImg = NSImage(data: prev),
               let cg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                previewPNGData = prev
                photoSlots = [UploadedCatPhotoSlot(cgImage: cg, thumbnail: nsImg)]
            }
            recompileDraftSkin()
            return
        }

        recompileDraftSkin()

        if !pet.pendingStudioPhotoURLs.isEmpty {
            let initial = pet.pendingStudioPhotoURLs
            pet.pendingStudioPhotoURLs = []
            appendPhotosAndAnalyze(urls: initial)
        }
    }

    private func recompileDraftSkin() {
        if let compiled = try? CatCoatCompiler.compileSkinSpec(from: dna, previewPNG: previewPNGData) {
            draftSkin = compiled
            draftRevision += 1
        }
    }

    private func pickPhotosViaOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "选择猫咪照片（可多选 1–4 张）"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .webP]
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            appendPhotosAndAnalyze(urls: panel.urls)
        }
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for prov in matching.prefix(PhotoCatAnalyzer.maxPhotoCount) {
            group.enter()
            prov.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let resolved: URL? = {
                    if let d = item as? Data { return URL(dataRepresentation: d, relativeTo: nil) }
                    return item as? URL
                }()
                if let u = resolved {
                    lock.lock()
                    urls.append(u)
                    lock.unlock()
                }
            }
        }
        group.notify(queue: .main) {
            if !urls.isEmpty {
                appendPhotosAndAnalyze(urls: urls)
            }
        }
        return true
    }

    private func appendPhotosAndAnalyze(urls: [URL]) {
        let remaining = max(0, PhotoCatAnalyzer.maxPhotoCount - photoSlots.count)
        let targetURLs = remaining > 0 ? Array(urls.prefix(remaining)) : Array(urls.prefix(PhotoCatAnalyzer.maxPhotoCount))
        var addedAny = false
        if remaining == 0 {
            photoSlots.removeAll()
        }
        for url in targetURLs {
            if let cg = PhotoCatAnalyzer.loadOrientedCGImage(from: url, maxPixelSize: 1024) {
                let thumbData = PhotoCatAnalyzer.renderSquarePreviewPNG(from: cg, size: 140)
                let thumb = NSImage(data: thumbData) ?? NSImage(cgImage: cg, size: NSSize(width: 70, height: 70))
                photoSlots.append(UploadedCatPhotoSlot(cgImage: cg, thumbnail: thumb))
                addedAny = true
            }
        }
        if addedAny {
            rerunMultiPhotoAnalysis()
        } else {
            errorMessage = "无法读取该图片，请换一张照片试试"
        }
    }

    private func removePhotoSlot(_ id: UUID) {
        photoSlots.removeAll { $0.id == id }
        if !photoSlots.isEmpty {
            rerunMultiPhotoAnalysis()
        }
    }

    private func rerunMultiPhotoAnalysis() {
        let cgImages = photoSlots.map(\.cgImage)
        guard !cgImages.isEmpty else { return }
        errorMessage = ""
        isAnalyzingPhoto = true

        let trimmedCurrent = dna.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let keepCustomName = (trimmedCurrent != "年糕" && trimmedCurrent != "小咪" && !trimmedCurrent.isEmpty) ? trimmedCurrent : ""
        let cfg = appState.llmConfig
        let byokKey = appState.apiKeyInput
        let jwt = KeychainHelper.loadCloudJWT()

        Task {
            let res = await PhotoCatAnalyzer.analyzeCGImages(
                cgImages,
                preferredName: keepCustomName,
                llmConfig: cfg,
                byokAPIKey: byokKey,
                cloudJWT: jwt
            )
            await MainActor.run {
                self.previewPNGData = res.previewPNG
                self.dna = res.dna
                self.isAnalyzingPhoto = false
                self.recompileDraftSkin()
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
