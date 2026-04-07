import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    enum State {
        case disabled
        case enabled
        case requiresApproval
        case unavailable
    }

    @Published private(set) var state: State = .disabled
    @Published private(set) var lastErrorMessage: String?

    private let service = SMAppService.mainApp
    private var isRunningFromAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    init() {
        refreshStatus()
    }

    var isEnabled: Bool {
        switch state {
        case .enabled, .requiresApproval:
            return true
        case .disabled, .unavailable:
            return false
        }
    }

    var isToggleEnabled: Bool {
        isRunningFromAppBundle
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        guard isRunningFromAppBundle else {
            state = .unavailable
            lastErrorMessage = L10n.string("loginItem.error.unavailable")
            return false
        }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }

            refreshStatus()
            lastErrorMessage = nil
            return true
        } catch {
            refreshStatus()
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func detailMessage() -> String {
        switch state {
        case .enabled:
            return L10n.string("loginItem.enabled.detail")
        case .disabled:
            return L10n.string("loginItem.disabled.detail")
        case .requiresApproval:
            return L10n.string("loginItem.requiresApproval.detail")
        case .unavailable:
            return L10n.string("loginItem.unavailable.detail")
        }
    }

    private func refreshStatus() {
        guard isRunningFromAppBundle else {
            state = .unavailable
            return
        }

        switch service.status {
        case .enabled:
            state = .enabled
        case .notRegistered:
            state = .disabled
        case .requiresApproval:
            state = .requiresApproval
        case .notFound:
            state = .disabled
        @unknown default:
            state = .disabled
        }
    }
}

extension LaunchAtLoginController.State {
    var commandName: String {
        switch self {
        case .disabled:
            return "disabled"
        case .enabled:
            return "enabled"
        case .requiresApproval:
            return "requiresApproval"
        case .unavailable:
            return "unavailable"
        }
    }
}
