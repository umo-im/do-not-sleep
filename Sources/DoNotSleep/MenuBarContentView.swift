import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var sleepController: SleepAssertionController
    @ObservedObject var launchAtLoginController: LaunchAtLoginController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(sleepController.hasActiveProtection ? Color.green : Color.secondary.opacity(0.45))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)

                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(
                keepMacAwakeToggleTitle,
                isOn: Binding(
                    get: { sleepController.isPreventingSleep },
                    set: { sleepController.setEnabled($0) }
                )
            )
            .toggleStyle(.switch)

            Toggle(
                preventScreenSaverToggleTitle,
                isOn: Binding(
                    get: { sleepController.isPreventingScreenSaver },
                    set: { sleepController.setScreenSaverEnabled($0) }
                )
            )
            .toggleStyle(.switch)

            if sleepController.hasActiveProtection {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Label(L10n.activeDuration(since: sleepController.startedAt, now: context.date), systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(secondaryMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let lastErrorCode = sleepController.lastErrorCode {
                Text(L10n.format("error.assertionFailed", lastErrorCode))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let screenSaverErrorCode = sleepController.screenSaverErrorCode {
                Text(L10n.format("error.screenSaverAssertionFailed", screenSaverErrorCode))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Toggle(
                    L10n.string("loginItem.toggle"),
                    isOn: Binding(
                        get: { launchAtLoginController.isEnabled },
                        set: { launchAtLoginController.setEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                .disabled(!launchAtLoginController.isToggleEnabled)

                Text(launchAtLoginController.detailMessage())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let lastErrorMessage = launchAtLoginController.lastErrorMessage {
                    Text(L10n.format("loginItem.error.updateFailed", lastErrorMessage))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            HStack {
                Button(L10n.string("button.quit")) {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")

                Spacer()
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private var statusTitle: String {
        switch sleepController.protectionMode {
        case .none:
            return L10n.string("status.disabled.title")
        case .systemSleep:
            return L10n.string("status.enabled.title")
        case .screenSaver:
            return L10n.string("status.screen.title")
        case .systemSleepAndScreenSaver:
            return L10n.string("status.all.title")
        }
    }

    private var statusMessage: String {
        switch sleepController.protectionMode {
        case .none:
            return L10n.string("status.disabled.message")
        case .systemSleep:
            return L10n.string("status.enabled.message")
        case .screenSaver:
            return L10n.string("status.screen.message")
        case .systemSleepAndScreenSaver:
            return L10n.string("status.all.message")
        }
    }

    private var secondaryMessage: String {
        switch sleepController.protectionMode {
        case .none:
            return L10n.string("status.disabled.detail")
        case .systemSleep:
            return L10n.string("status.enabled.detail")
        case .screenSaver:
            return L10n.string("status.screen.detail")
        case .systemSleepAndScreenSaver:
            return L10n.string("status.all.detail")
        }
    }

    private var keepMacAwakeToggleTitle: String {
        sleepController.isPreventingSleep
            ? L10n.string("toggle.enabled")
            : L10n.string("toggle.disabled")
    }

    private var preventScreenSaverToggleTitle: String {
        sleepController.isPreventingScreenSaver
            ? L10n.string("screenSaver.toggle.enabled")
            : L10n.string("screenSaver.toggle.disabled")
    }
}
