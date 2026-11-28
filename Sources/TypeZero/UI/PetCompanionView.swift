import SwiftUI
import AppKit

// MARK: - Live Embedded Vector Cat Preview Stage (NSViewRepresentable)

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
            let idleInput = ScriptedFrameInput(
                now: now,
                activeKeys: self.physics.virtualActiveKeys,
                orderedKeys: self.physics.virtualOrderedKeys,
                mouseScreenPos: CGPoint(x: 180 + sin(now * 1.3) * 55, y: 170 + cos(now * 0.9) * 20),
                mouseVelocity: .zero,
                leftMouseDown: false,
                rightMouseDown: false,
                lastMouseMoveTime: now,
                lastMouseClickTime: 0,
                lastKeyActivityTime: self.physics.lastVirtualKeyTime
            )
            self.physics.step(dt: dt, windowFrameInScreen: CGRect(x: 0, y: 0, width: 360, height: 320), scripted: idleInput)
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
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
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

private struct PetInlinePreviewStage: NSViewRepresentable {
    let coat: CatCoatTheme
    let customSkinID: String
    let whiteOutline: Bool
    let marquee: Bool

    func makeNSView(context: Context) -> PetInlinePreviewNSView {
        PetInlinePreviewNSView()
    }

    func updateNSView(_ nsView: PetInlinePreviewNSView, context: Context) {
        _ = (coat, customSkinID, whiteOutline, marquee)
        nsView.needsDisplay = true
    }
}

// MARK: - Top-Level Sidebar Tab: 「桌面搭子」 (PetCompanionView)

struct PetCompanionView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var pet: PetCompanionController
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            heroStageCard
            shiftHandoverSection
            voiceAndDesktopSettingsSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("桌面搭子")
                    .font(TZFont.title(24))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text("与语音胶囊完全独立共存：日常用键盘打字时同步陪打，按住说话走云端识别时把语音变成残影敲键再变成文字")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
            Spacer()
            HStack(spacing: 5.5) {
                Circle()
                    .fill(pet.isEnabled ? TZTheme.emerald : TZTheme.inkMuted.opacity(0.55))
                    .frame(width: 6.5, height: 6.5)
                Text(pet.isEnabled ? "桌宠在线陪打中" : "桌宠已收起")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(pet.isEnabled ? TZTheme.emerald : TZTheme.inkSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(pet.isEnabled ? TZTheme.emeraldSoft : TZTheme.recessedWell)
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
                    coat: pet.coatTheme,
                    customSkinID: pet.customSkinID,
                    whiteOutline: pet.whiteOutline,
                    marquee: pet.keyboardMarquee
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
            .frame(width: 216, height: 184)

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text("开启桌面黑猫搭子")
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text(CatSettings.shared.activeSkin.name)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(TZTheme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(TZTheme.accentSoft)
                                .clipShape(Capsule())
                        }
                        Text("开启后常驻桌面右下角（可揪住后颈任意拖动位置，右键小猫可呼出快捷菜单）")
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

                // 3-Column Live Companion Stats
                HStack(spacing: 10) {
                    statPill(title: "今日语音代敲", value: "\(pet.todayVoiceKeys)", unit: "键", accent: TZTheme.accent)
                    statPill(title: "今日键盘陪打", value: "\(pet.todayPhysicalKeys)", unit: "键", accent: TZTheme.emerald)
                    statPill(title: "累计摸头呼噜", value: "\(pet.petTouchCount)", unit: "次", accent: TZTheme.amber)
                }

                // Quick Interactive Action Buttons
                HStack(spacing: 10) {
                    Button {
                        pet.playShiftHandoverDemo()
                    } label: {
                        HStack(spacing: 5.5) {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                .font(.system(size: 12))
                            Text(pet.isHandoverRunning ? "正在换班交接中…" : "立即演示「吵架换班」")
                        }
                    }
                    .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
                    .disabled(pet.isHandoverRunning)

                    Button {
                        pet.playVoiceTypingDemo()
                    } label: {
                        HStack(spacing: 5.5) {
                            Image(systemName: "keyboard.fill")
                                .font(.system(size: 11.5))
                            Text("试播语音变敲键")
                        }
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                    if pet.isEnabled {
                        Button {
                            pet.resetPosition()
                        } label: {
                            HStack(spacing: 4.5) {
                                Image(systemName: "scope")
                                    .font(.system(size: 11))
                                Text("归位右下角")
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

    private func statPill(title: String, value: String, unit: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(TZTheme.inkMuted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(TZFont.metric(17))
                    .foregroundStyle(accent)
                Text(unit)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(TZTheme.recessedWell.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Section 1: 猫咪工位与换班交接仪式

    private var shiftHandoverSection: some View {
        TZGroupedSection(title: "猫咪工位与换班交接") {
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
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(CatCoatTheme.allCases) { coat in
                        breedSelectionCard(for: coat)
                    }
                }

                if !pet.importedSkins.isEmpty {
                    TZHairline()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("已导入的自定义皮肤")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(TZTheme.inkSecondary)
                        FlowImportedSkinsRow(pet: pet)
                    }
                }

                if !pet.statusNotice.isEmpty {
                    Text(pet.statusNotice)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.accent)
                }

                TZHairline()

                toggleRow(
                    title: "切换猫咪时触发「走入炸毛吵架换班」仪式",
                    subtitle: "新猫从左侧迈步入场，两只猫在键盘前弓背飞机耳斗嘴交接，旧猫骂骂咧咧下班后新猫上岗接管",
                    isOn: Binding(
                        get: { pet.enableHandoverAnimation },
                        set: { pet.setEnableHandoverAnimation($0) }
                    )
                )

                TZHairline()

                toggleRow(
                    title: "换班交接时播放真猫斗嘴原声",
                    subtitle: "内置多段抖音原味小猫「哇啦哇啦」吵架语音轮播，随时可静音",
                    isOn: Binding(
                        get: { pet.enableHandoverSound },
                        set: { pet.setEnableHandoverSound($0) }
                    )
                )
            }
            .padding(16)
        }
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
                        Text(coat.shortTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
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
            return (Color(red: 0.85, green: 0.66, blue: 0.44), Color(red: 0.98, green: 0.76, blue: 0.22))
        }
    }

    // MARK: - Section 2: 云端语音变敲键与日常桌面交互

    private var voiceAndDesktopSettingsSection: some View {
        TZGroupedSection(title: "语音代敲与桌面交互") {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                toggleRow(
                    title: "云端语音实时转化为敲键盘动作",
                    subtitle: "使用 TypeZero 语音输入时，将识别与润色流拆解为真实拼音/英文按键序列，双爪残影敲击后再上屏文字",
                    isOn: Binding(
                        get: { pet.enableVoiceTyping },
                        set: { pet.setEnableVoiceTyping($0) }
                    )
                )

                TZHairline()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2.5) {
                        Text("敲键盘时的上方飘字样式")
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

                TZHairline()

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2.5) {
                        Text("桌面体型缩放（\(Int((pet.scale * 100).rounded()))%）")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Text("也可直接在桌面上对准小猫滚动鼠标滚轮或双指捏合无级缩放")
                            .font(.system(size: 11.5))
                            .foregroundStyle(TZTheme.inkSecondary)
                    }
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { Double(pet.scale) },
                            set: { pet.setScale(CGFloat($0)) }
                        ),
                        in: 0.55...1.65,
                        step: 0.05
                    )
                    .tint(TZTheme.accent)
                    .frame(width: 200)
                }

                TZHairline()

                toggleRow(
                    title: "完全鼠标穿透（游戏 / 全屏办公防误触）",
                    subtitle: "开启后鼠标点击直接穿过小猫落到后方窗口；按住 Option (⌥) 键可随时临时解锁拎起或右键",
                    isOn: Binding(
                        get: { pet.fullClickThrough },
                        set: { pet.setFullClickThrough($0) }
                    )
                )

                TZHairline()

                toggleRow(
                    title: "经典贴纸白描边",
                    subtitle: "在深色代码编辑器与暗色壁纸上保持鲜明剪影轮廓",
                    isOn: Binding(
                        get: { pet.whiteOutline },
                        set: { pet.setWhiteOutline($0) }
                    )
                )

                TZHairline()

                toggleRow(
                    title: "听歌 / 看视频自动戴上 2.5D 耳机律动",
                    subtitle: "检测到系统声卡连续输出音频满 1.5 秒自动戴上耳机飘音符（双猫吵架或放歌时自动吃瓜）",
                    isOn: Binding(
                        get: { pet.autoHeadphonesOnMusic },
                        set: { pet.setAutoHeadphonesOnMusic($0) }
                    )
                )

                TZHairline()

                toggleRow(
                    title: "3 键翘后脚拍键 & 机械键盘流光跑马灯",
                    subtitle: "高速连敲或组合键时触发第三只脚拍键盘彩蛋与 RGB 流光加速",
                    isOn: Binding(
                        get: { pet.footEasterEgg && pet.keyboardMarquee },
                        set: {
                            pet.setFootEasterEgg($0)
                            pet.setKeyboardMarquee($0)
                        }
                    )
                )
            }
            .padding(16)
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
                            Text(skin.name)
                                .font(.system(size: 12, weight: active ? .semibold : .regular))
                                .foregroundStyle(active ? TZTheme.accent : TZTheme.inkPrimary)
                        }
                        .buttonStyle(.plain)

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
