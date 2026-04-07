import AppKit
import SwiftUI

struct StatusOverviewCard: View {
    let accentColor: Color
    let symbolName: String
    let title: String
    let message: String
    let detail: String
    let startedAt: Date?
    let isActive: Bool
    let lastErrorCode: Int32?
    let screenSaverErrorCode: Int32?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accentColor.opacity(0.16))
                        .frame(width: 40, height: 40)

                    Image(systemName: symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isActive {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Label(
                        L10n.activeDuration(since: startedAt, now: context.date),
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accentColor)
                }
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let lastErrorCode {
                ErrorMessageView(message: L10n.format("error.assertionFailed", lastErrorCode))
            }

            if let screenSaverErrorCode {
                ErrorMessageView(message: L10n.format("error.screenSaverAssertionFailed", screenSaverErrorCode))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(StatusCardBackground(accentColor: accentColor))
    }
}

struct SettingsCard<Content: View, Accessory: View>: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let content: Content
    let accessory: Accessory

    init(
        title: String,
        subtitle: String,
        symbolName: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 28, height: 28)

                    Image(systemName: symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                accessory
            }

            content
        }
        .padding(14)
        .background(PanelCardBackground())
    }
}

extension SettingsCard where Accessory == EmptyView {
    init(title: String, subtitle: String, symbolName: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, symbolName: symbolName, content: content) {
            EmptyView()
        }
    }
}

struct ProtectionToggleRow: View {
    let symbolName: String
    let title: String
    let detail: String
    let accentColor: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill((isOn ? accentColor : .secondary).opacity(isOn ? 0.14 : 0.09))
                    .frame(width: 30, height: 30)

                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOn ? accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(InsetPanelBackground(tint: accentColor, emphasized: isOn))
    }
}

struct AutoDisableTimerSection: View {
    @ObservedObject var sleepController: SleepAssertionController
    private let presetColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !sleepController.hasScheduledAutoDisable {
                Text(helperMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("timer.presets.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: presetColumns, spacing: 8) {
                    TimerOptionButton(
                        title: L10n.string("timer.option.manual"),
                        isSelected: sleepController.autoDisableMode == .manual,
                        isEnabled: sleepController.hasActiveProtection
                    ) {
                        sleepController.cancelAutoDisableTimer()
                    }

                    ForEach(SleepAssertionController.AutoDisablePreset.allCases) { preset in
                        TimerOptionButton(
                            title: label(for: preset),
                            isSelected: sleepController.autoDisableMode == .preset(preset),
                            isEnabled: sleepController.hasActiveProtection
                        ) {
                            sleepController.startAutoDisableTimer(preset)
                        }
                    }
                }
            }

            if sleepController.hasScheduledAutoDisable {
                HStack(spacing: 8) {
                    Button(L10n.string("timer.extend")) {
                        sleepController.extendAutoDisableTimer()
                    }
                    .buttonStyle(.bordered)

                    Button(L10n.string("timer.cancel")) {
                        sleepController.cancelAutoDisableTimer()
                    }
                    .buttonStyle(.borderless)
                }
                .controlSize(.small)
            }
        }
    }

    private var helperMessage: String {
        sleepController.hasActiveProtection
            ? L10n.string("timer.helper.active")
            : L10n.string("timer.helper.inactive")
    }

    private func label(for preset: SleepAssertionController.AutoDisablePreset) -> String {
        switch preset {
        case .fifteenMinutes:
            return L10n.string("timer.option.15m")
        case .thirtyMinutes:
            return L10n.string("timer.option.30m")
        case .oneHour:
            return L10n.string("timer.option.1h")
        case .twoHours:
            return L10n.string("timer.option.2h")
        case .fourHours:
            return L10n.string("timer.option.4h")
        }
    }
}

struct AppSettingsSection: View {
    @ObservedObject var launchAtLoginController: LaunchAtLoginController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProtectionToggleRow(
                symbolName: "person.crop.circle.badge.checkmark",
                title: L10n.string("loginItem.toggle"),
                detail: launchAtLoginController.detailMessage(),
                accentColor: .blue,
                isOn: Binding(
                    get: { launchAtLoginController.isEnabled },
                    set: { launchAtLoginController.setEnabled($0) }
                )
            )
            .disabled(!launchAtLoginController.isToggleEnabled)

            if let lastErrorMessage = launchAtLoginController.lastErrorMessage {
                ErrorMessageView(message: L10n.format("loginItem.error.updateFailed", lastErrorMessage))
            }

            HStack {
                Spacer()

                Button(L10n.string("button.quit")) {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("q")
            }
            .padding(.top, 2)
        }
    }
}

struct ErrorMessageView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct AutoDisableHeaderStatus: View {
    @ObservedObject var sleepController: SleepAssertionController

    var body: some View {
        if let deadline = sleepController.autoDisableDeadline {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(L10n.autoDisableCountdown(until: deadline, now: context.date))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .monospacedDigit()
            }
        }
    }
}

struct TimerOptionButton: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
        .opacity(isEnabled ? 1 : 0.45)
        .disabled(!isEnabled)
    }
}

struct InsetPanelBackground: View {
    let tint: Color
    let emphasized: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(tint.opacity(emphasized ? 0.08 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(emphasized ? 0.18 : 0.08), lineWidth: 1)
            )
    }
}

struct PanelCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            )
    }
}

struct StatusCardBackground: View {
    let accentColor: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.16),
                        Color(nsColor: .controlBackgroundColor).opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accentColor.opacity(0.16), lineWidth: 1)
            )
    }
}
