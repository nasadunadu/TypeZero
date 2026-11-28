import SwiftUI
import AppKit

// MARK: - 1-Month Free Trial Graduation & BYOK Handover Sheet

struct TrialExhaustedSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var isExpired: Bool {
        appState.activeCloudTrial?.isExpired == true
    }

    private var formattedChars: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: appState.totalCharactersDictated)) ?? "\(appState.totalCharactersDictated)"
    }

    private var formattedHoursSaved: String {
        let hrs = appState.estimatedTimeSavedHours
        if hrs < 0.1 {
            let mins = max(1, Int((hrs * 60.0).rounded()))
            return "\(mins) 分钟"
        }
        return String(format: "%.1f 小时", hrs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                TZBrandEmblemView(size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isExpired ? "你的 1 个月免费畅享之旅已圆满完成" : "你的免费云端体验额度已全部用完")
                        .font(TZFont.title(18))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("TypeZero 软件本体永久免费，你的词库与个人风格已 100% 完整保留")
                        .font(.system(size: 12.5))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                Spacer()
            }

            // Achievement Stats Strip
            HStack(spacing: 10) {
                achievementTile(value: formattedChars, unit: "字", label: "累计开口成文", tint: TZTheme.accent)
                achievementTile(value: formattedHoursSaved, unit: "", label: "为你省下打字", tint: TZTheme.emerald)
                achievementTile(value: "\(appState.history.count)", unit: "次", label: "累计智能成稿", tint: TZTheme.cyan)
            }

            // Value & Transparent Cost Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                    Text("如何继续无限畅用？（永久零软件订阅费）")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                }
                Text("只需 2 分钟绑定个人 API Key（推荐 豆包语音 2.0 + DeepSeek），按官方底价直连无月租，日常办公每天仅约 5 分钱，充 ¥10 能用大半年；或一键切换 100% 本机离线引擎永久 ¥0。")
                    .font(.system(size: 12))
                    .foregroundStyle(TZTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2.5)
            }
            .padding(14)
            .background(TZTheme.accentSoft.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(TZTheme.accent.opacity(0.24), lineWidth: 1)
            )

            // Primary & Secondary Conversion Actions
            VStack(spacing: 9) {
                Button {
                    appState.openCustomEngineSetup()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("去绑定个人 API Key（2 分钟搞定 · 每天约 5 分钱）")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(TZPrimaryButtonStyle(compact: false, capsule: true))

                HStack(spacing: 9) {
                    Button {
                        NSWorkspace.shared.open(CloudAuthClient.byokGuideURL)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 11.5))
                            Text("查看豆包 & DeepSeek 开通教程 ↗")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: false))

                    Button {
                        appState.switchToLocalOfflineEngine()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 11.5))
                            Text("切 100% 本机离线（永久 ¥0）")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: false))
                }
            }

            // Footer utility row
            HStack {
                Button("有朋友赠送的增容码？去兑换") {
                    appState.showTrialExhaustedSheet = false
                    appState.selectedSettingsTab = .account
                    appState.selectedTab = .settings
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(TZTheme.accent)
                .buttonStyle(.plain)

                Spacer()

                Button("稍后再说") {
                    appState.showTrialExhaustedSheet = false
                    dismiss()
                }
                .font(.system(size: 11.5))
                .foregroundStyle(TZTheme.inkMuted)
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 540)
        .background(TZTheme.canvasBg)
        .preferredColorScheme(appState.llmConfig.appearance.colorScheme)
    }

    private func achievementTile(value: String, unit: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(TZFont.metric(22))
                    .foregroundStyle(tint)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
            }
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(TZTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(TZTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(TZTheme.cardBorder, lineWidth: 1)
        )
    }
}
