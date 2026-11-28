import SwiftUI
import AppKit

// MARK: - Progressive Single-Task Onboarding Wizard ("注册免费领 1 个月超级 VIP")
// Step 1: Super VIP Value Hook (自研大模型 · 超快转换 · 智能整理 · 自动去语病)
// Step 2: Single-Field Email -> 6-Digit OTP (Auto-Submit)
// Step 3: Super VIP Activated Celebration + Future BYOK Bridge
// Step 4: Quick Trigger Key & Permission Handoff

struct OnboardingSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var scheme

    private enum Step: Int, CaseIterable {
        case welcome = 0
        case register = 1
        case reward = 2
        case ready = 3
    }

    private enum FocusField: Hashable {
        case email
        case otp
    }

    @State private var step: Step
    @State private var movingForward: Bool = true
    @State private var resendCooldown: Int = 0
    @State private var cooldownTimer: Timer? = nil
    @FocusState private var focusedField: FocusField?

    init(appState: AppState, initialStep: Int? = nil) {
        self.appState = appState
        let resolved: Step = {
            if let s = initialStep, let st = Step(rawValue: max(0, min(3, s - 1))) {
                return st
            }
            if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--onboarding-step=") }),
               let raw = Int(arg.replacingOccurrences(of: "--onboarding-step=", with: "")),
               let st = Step(rawValue: max(0, min(3, raw - 1))) {
                return st
            }
            return .welcome
        }()
        self._step = State(initialValue: resolved)
    }

    var body: some View {
        VStack(spacing: 0) {
            topChromeBar
                .frame(height: 28)
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 10)

            ZStack {
                switch step {
                case .welcome:
                    welcomeScreen
                        .transition(stepTransition)
                case .register:
                    registerScreen
                        .transition(stepTransition)
                case .reward:
                    rewardScreen
                        .transition(stepTransition)
                case .ready:
                    readyScreen
                        .transition(stepTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .frame(width: 520, height: 520)
        .background(
            ZStack {
                TZTheme.canvasBg
                RadialGradient(
                    colors: [TZTheme.accent.opacity(scheme == .dark ? 0.16 : 0.08), Color.clear],
                    center: .top,
                    startRadius: 10,
                    endRadius: 340
                )
            }
        )
        .preferredColorScheme(appState.llmConfig.appearance.colorScheme)
        .onDisappear {
            cooldownTimer?.invalidate()
            cooldownTimer = nil
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func goTo(_ target: Step) {
        movingForward = target.rawValue >= step.rawValue
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            step = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if target == .register {
                focusedField = appState.cloudCodeSent ? .otp : .email
            } else {
                focusedField = nil
            }
        }
    }

    // MARK: - Top Navigation & Progress Bar (Generous Safe Top Inset)

    private var topChromeBar: some View {
        HStack(alignment: .center) {
            if step != .welcome {
                Button {
                    let prev = Step(rawValue: max(0, step.rawValue - 1)) ?? .welcome
                    goTo(prev)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(TZTheme.inkSecondary)
                    .frame(width: 56, height: 26, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 56, height: 26)
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    let active = (item == step)
                    let passed = (item.rawValue < step.rawValue)
                    Capsule()
                        .fill(active ? TZTheme.accent : (passed ? TZTheme.accent.opacity(0.42) : TZTheme.inkMuted.opacity(0.22)))
                        .frame(width: active ? 22 : 6, height: 6)
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: step)
                }
            }

            Spacer()

            Button {
                appState.completeOnboarding()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TZTheme.inkMuted)
                    .frame(width: 26, height: 26)
                    .background(TZTheme.recessedWell.opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: 56, alignment: .trailing)
            .help("稍后配置")
        }
    }

    // MARK: - Step 1: Super VIP Welcome & 4 Core Advantages

    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 6)

            VStack(spacing: 9) {
                TZBrandEmblemView(size: 50)

                HStack(spacing: 5) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10.5, weight: .bold))
                    Text("新用户专属礼遇 · 超级 VIP 1 个月")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(TZTheme.accent)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(TZTheme.accentSoft)
                .clipShape(Capsule())

                Text("注册免费领超级 VIP")
                    .font(TZFont.title(24))
                    .foregroundStyle(TZTheme.inkPrimary)

                Text("在任意软件按一下说话，比打字快 4 倍，开口即终稿")
                    .font(.system(size: 13))
                    .foregroundStyle(TZTheme.inkSecondary)
            }

            Spacer(minLength: 18)

            // 2x2 Grid of Super VIP Benefits (Inspired by Shandianshuo + TypeZero Strengths)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    vipBenefitTile(
                        icon: "cpu.fill",
                        tint: TZTheme.accent,
                        title: "自研大模型",
                        subtitle: "中英混说与术语极准"
                    )
                    vipBenefitTile(
                        icon: "bolt.fill",
                        tint: Color(red: 0.95, green: 0.55, blue: 0.08),
                        title: "超快转换",
                        subtitle: "毫秒级实时流式出字"
                    )
                }
                HStack(spacing: 10) {
                    vipBenefitTile(
                        icon: "sparkles",
                        tint: TZTheme.emerald,
                        title: "智能整理",
                        subtitle: "自动分段与标点排版"
                    )
                    vipBenefitTile(
                        icon: "wand.and.stars",
                        tint: TZTheme.cyan,
                        title: "自动去语病",
                        subtitle: "过滤口癖与重复口误"
                    )
                }
            }

            Spacer(minLength: 22)

            VStack(spacing: 14) {
                Button {
                    appState.cloudAuthMessage = ""
                    if appState.cloudUser != nil {
                        goTo(.reward)
                    } else {
                        goTo(.register)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12.5))
                        Text(appState.cloudUser != nil ? "查看我的超级 VIP" : "免费注册领取 1 个月超级 VIP")
                            .font(.system(size: 14.5, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                }
                .buttonStyle(TZPrimaryButtonStyle(compact: false, capsule: true))

                HStack(spacing: 18) {
                    if appState.cloudUser != nil {
                        Button("换个邮箱注册领取") {
                            appState.logoutCloudAccount()
                            appState.cloudAuthMessage = ""
                            goTo(.register)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .buttonStyle(.plain)
                    }

                    Button("已有自有 API Key？直接去配置") {
                        appState.completeOnboarding()
                        appState.openCustomEngineSetup()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TZTheme.inkMuted)
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func vipBenefitTile(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.13))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(TZTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(TZTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Step 2: Frictionless Email Registration

    private var registerScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(TZTheme.accentSoft)
                        .frame(width: 50, height: 50)
                    Image(systemName: appState.cloudCodeSent ? "key.horizontal.fill" : "envelope.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                }

                Text(appState.cloudCodeSent ? "输入 6 位验证码" : "输入邮箱，领取超级 VIP")
                    .font(TZFont.title(22))
                    .foregroundStyle(TZTheme.inkPrimary)

                if appState.cloudCodeSent {
                    HStack(spacing: 6) {
                        Text("已发送至 \(appState.cloudEmailInput)")
                            .font(.system(size: 12.5))
                            .foregroundStyle(TZTheme.inkSecondary)
                            .lineLimit(1)
                        Button("更换邮箱") {
                            withAnimation(.easeOut(duration: 0.16)) {
                                appState.cloudCodeSent = false
                                appState.cloudCodeInput = ""
                                appState.cloudAuthMessage = ""
                                focusedField = .email
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("无需密码与绑卡，验证后立即开通超级 VIP 1 个月")
                        .font(.system(size: 13))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
            }

            Spacer(minLength: 24)

            if !appState.cloudCodeSent {
                VStack(spacing: 14) {
                    TextField("输入常用邮箱（QQ / 163 / Gmail / Outlook）", text: $appState.cloudEmailInput)
                        .focused($focusedField, equals: .email)
                        .font(.system(size: 14))
                        .tzRecessedInput()
                        .onSubmit { submitSendCode() }

                    Button {
                        submitSendCode()
                    } label: {
                        Text(appState.isCloudAuthBusy ? "正在发送验证码…" : "获取验证码")
                            .font(.system(size: 14.5, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(TZPrimaryButtonStyle(compact: false, capsule: true))
                    .disabled(appState.isCloudAuthBusy)
                }
                .frame(maxWidth: 380)
            } else {
                VStack(spacing: 14) {
                    TextField("6 位数字验证码", text: $appState.cloudCodeInput)
                        .focused($focusedField, equals: .otp)
                        .multilineTextAlignment(.center)
                        .font(TZFont.mono(21, weight: .bold))
                        .tzRecessedInput()
                        .onChange(of: appState.cloudCodeInput) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            if digits != newValue {
                                appState.cloudCodeInput = String(digits.prefix(6))
                            }
                            if digits.count == 6 && !appState.isCloudAuthBusy {
                                submitVerifyCode()
                            }
                        }
                        .onSubmit { submitVerifyCode() }

                    Button {
                        submitVerifyCode()
                    } label: {
                        Text(appState.isCloudAuthBusy ? "正在开通超级 VIP…" : "立即开通超级 VIP 1 个月")
                            .font(.system(size: 14.5, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(TZPrimaryButtonStyle(compact: false, capsule: true))
                    .disabled(appState.isCloudAuthBusy)

                    Button(resendCooldown > 0 ? "\(resendCooldown) 秒后可重发" : "没收到？重新发送验证码") {
                        submitSendCode()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(resendCooldown > 0 ? TZTheme.inkMuted : TZTheme.accent)
                    .buttonStyle(.plain)
                    .disabled(resendCooldown > 0 || appState.isCloudAuthBusy)
                }
                .frame(maxWidth: 360)
            }

            if !appState.cloudAuthMessage.isEmpty && appState.cloudAuthMessage.hasPrefix("❌") {
                Text(appState.cloudAuthMessage.replacingOccurrences(of: "❌ ", with: ""))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TZTheme.crimson)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 10)
            }

            Spacer(minLength: 24)

            Text("🔒 语音实时流式转换不留存，词库与历史 100% 仅存本机")
                .font(.system(size: 11.5))
                .foregroundStyle(TZTheme.inkMuted)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Step 3: Super VIP Arrived + How Good It Is + BYOK Bridge

    private var rewardScreen: some View {
        let readyPerms = appState.micAuthorized && appState.accessibilityGranted

        return VStack(spacing: 0) {
            Spacer(minLength: 6)

            VStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(TZTheme.emeraldSoft)
                        .frame(width: 50, height: 50)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(TZTheme.emerald)
                }

                Text("超级 VIP 1 个月已到账！")
                    .font(TZFont.title(23))
                    .foregroundStyle(TZTheme.inkPrimary)

                Text("👑 全部高阶语音与智能整理特权已免费解锁")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(TZTheme.emerald)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(TZTheme.emeraldSoft)
                    .clipShape(Capsule())
            }

            Spacer(minLength: 18)

            VStack(alignment: .leading, spacing: 12) {
                benefitRow(
                    icon: "bolt.fill",
                    tint: TZTheme.accent,
                    title: "自研大模型 · 超快转文字",
                    desc: "毫秒级实时响应，比打字快 4 倍，中英混说一次命中"
                )
                benefitRow(
                    icon: "wand.and.stars",
                    tint: TZTheme.emerald,
                    title: "智能整理 · 自动去语病",
                    desc: "自动过滤“嗯、啊、那个”口癖与口误，智能分段加标点"
                )
                benefitRow(
                    icon: "key.fill",
                    tint: TZTheme.cyan,
                    title: "满月后可无缝绑定自有 API",
                    desc: "软件永久免费；到期后按图文教程 2 分钟绑自有 API，每天仅 5 分钱"
                )
            }
            .padding(15)
            .background(TZTheme.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(TZTheme.cardBorder, lineWidth: 1))

            Spacer(minLength: 20)

            VStack(spacing: 14) {
                Button {
                    goTo(.ready)
                } label: {
                    HStack(spacing: 6) {
                        Text(readyPerms ? "下一步，确认快捷键开说" : "下一步，开启麦克风权限")
                            .font(.system(size: 14.5, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                }
                .buttonStyle(TZPrimaryButtonStyle(compact: false, capsule: true))

                Button("想现在就去配置自有 API（附图文教程）→") {
                    appState.completeOnboarding()
                    appState.openCustomEngineSetup()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TZTheme.accent)
                .buttonStyle(.plain)
                .padding(.bottom, 4)
            }
        }
    }

    private func benefitRow(icon: String, tint: Color, title: String, desc: String) -> some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text(desc)
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Step 4: Quick Trigger Key & Permission Ready

    private var readyScreen: some View {
        let allGranted = appState.micAuthorized && appState.accessibilityGranted

        return VStack(spacing: 0) {
            Spacer(minLength: 10)

            VStack(spacing: 8) {
                TZKeycapView(label: keycapEngravingLabel(for: appState.triggerKey), size: .large, highlighted: true)
                    .padding(.bottom, 4)

                Text("最后一步，按「\(appState.activeTriggerCompactLabel)」就能说")
                    .font(TZFont.title(21))
                    .foregroundStyle(TZTheme.inkPrimary)

                Text("在微信、飞书、文档等任意输入框按一下说话，再按一下自动成稿")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TZTheme.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 20)

            HStack(spacing: 7) {
                ForEach([TriggerKeyOption.fnKey, .rightOption, .leftOption, .rightCommand, .optionSpace], id: \.self) { opt in
                    let selected = (appState.triggerKey == opt)
                    Button {
                        appState.triggerKey = opt
                    } label: {
                        Text(opt.compactSidebarLabel)
                            .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? TZTheme.accent : TZTheme.inkSecondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(selected ? TZTheme.accentSoft : TZTheme.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(selected ? TZTheme.accent.opacity(0.6) : TZTheme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 16)

            if allGranted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TZTheme.emerald)
                    Text("麦克风与辅助功能权限已就绪")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TZTheme.emerald)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7.5)
                .background(TZTheme.emeraldSoft)
                .clipShape(Capsule())
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("开启麦克风与辅助功能，文字才能自动写入光标处")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                        HStack(spacing: 8) {
                            TZPermissionPill(title: "麦克风", ok: appState.micAuthorized)
                            TZPermissionPill(title: "辅助功能", ok: appState.accessibilityGranted)
                        }
                    }
                    Spacer()
                    Button("一键授权") {
                        appState.requestAllPermissions()
                    }
                    .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
                }
                .padding(12)
                .background(TZTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(TZTheme.amber.opacity(0.35), lineWidth: 1))
            }

            Spacer(minLength: 22)

            Button {
                appState.completeOnboarding()
                appState.selectedTab = .home
            } label: {
                Text("开始畅享超级 VIP")
                    .font(.system(size: 14.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
            }
            .buttonStyle(TZPrimaryButtonStyle(compact: false, capsule: true))
            .padding(.bottom, 4)
        }
    }

    private func keycapEngravingLabel(for option: TriggerKeyOption) -> String {
        switch option {
        case .fnKey: return "Fn"
        case .leftOption: return "左 ⌥"
        case .rightOption: return "右 ⌥"
        case .leftCommand: return "左 ⌘"
        case .rightCommand: return "右 ⌘"
        case .leftControl: return "左 ⌃"
        case .rightControl: return "右 ⌃"
        case .leftShift: return "左 ⇧"
        case .rightShift: return "右 ⇧"
        case .optionSpace: return "⌥␣"
        case .custom: return "⌘"
        }
    }

    // MARK: - Auth Actions

    private func submitSendCode() {
        Task {
            await appState.sendCloudEmailCode()
            if appState.cloudCodeSent {
                startResendCooldown()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = .otp
                }
            }
        }
    }

    private func submitVerifyCode() {
        Task {
            await appState.verifyCloudEmailCode()
            if appState.cloudUser != nil {
                goTo(.reward)
            }
        }
    }

    private func startResendCooldown() {
        cooldownTimer?.invalidate()
        resendCooldown = 60
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                if resendCooldown > 1 {
                    resendCooldown -= 1
                } else {
                    resendCooldown = 0
                    timer.invalidate()
                }
            }
        }
    }
}
