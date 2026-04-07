import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var sleepController: SleepAssertionController
    @ObservedObject var launchAtLoginController: LaunchAtLoginController

    private var statusAccentColor: Color {
        switch sleepController.protectionMode {
        case .none:
            return .secondary
        case .systemSleep:
            return .green
        case .screenSaver:
            return .orange
        case .systemSleepAndScreenSaver:
            return .blue
        }
    }

    private var statusSymbolName: String {
        switch sleepController.protectionMode {
        case .none:
            return "bolt.slash"
        case .systemSleep:
            return "bolt.fill"
        case .screenSaver:
            return "display"
        case .systemSleepAndScreenSaver:
            return "display.and.arrow.down"
        }
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

    private var statusDetail: String {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusOverviewCard(
                accentColor: statusAccentColor,
                symbolName: statusSymbolName,
                title: statusTitle,
                message: statusMessage,
                detail: statusDetail,
                startedAt: sleepController.startedAt,
                isActive: sleepController.hasActiveProtection,
                lastErrorCode: sleepController.lastErrorCode,
                screenSaverErrorCode: sleepController.screenSaverErrorCode
            )

            SettingsCard(
                title: L10n.string("settings.protection.title"),
                subtitle: L10n.string("settings.protection.subtitle"),
                symbolName: "power"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    ProtectionToggleRow(
                        symbolName: "laptopcomputer",
                        title: L10n.string("protection.sleep.title"),
                        detail: L10n.string("protection.sleep.detail"),
                        accentColor: .green,
                        isOn: Binding(
                            get: { sleepController.isPreventingSleep },
                            set: { sleepController.setEnabled($0) }
                        )
                    )

                    ProtectionToggleRow(
                        symbolName: "display",
                        title: L10n.string("protection.display.title"),
                        detail: L10n.string("protection.display.detail"),
                        accentColor: .orange,
                        isOn: Binding(
                            get: { sleepController.isPreventingScreenSaver },
                            set: { sleepController.setScreenSaverEnabled($0) }
                        )
                    )
                }
            }

            SettingsCard(
                title: L10n.string("timer.section.title"),
                subtitle: L10n.string("settings.timer.subtitle"),
                symbolName: "timer"
            ) {
                AutoDisableTimerSection(sleepController: sleepController)
            } accessory: {
                AutoDisableHeaderStatus(sleepController: sleepController)
            }

            SettingsCard(
                title: L10n.string("settings.app.title"),
                subtitle: L10n.string("settings.app.subtitle"),
                symbolName: "gearshape"
            ) {
                AppSettingsSection(launchAtLoginController: launchAtLoginController)
            }
        }
        .padding(14)
        .frame(width: 376)
    }
}
