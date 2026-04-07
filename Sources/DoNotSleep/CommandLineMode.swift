import Foundation

enum AppLaunchMode {
    case menuBar
    case launchAtLoginStatus
    case setLaunchAtLogin(Bool)

    init(arguments: [String] = CommandLine.arguments) {
        let arguments = Array(arguments.dropFirst())

        switch arguments.first {
        case "--launch-at-login-status":
            self = .launchAtLoginStatus
        case "--launch-at-login-enable":
            self = .setLaunchAtLogin(true)
        case "--launch-at-login-disable":
            self = .setLaunchAtLogin(false)
        default:
            self = .menuBar
        }
    }

    var showsMenuBar: Bool {
        switch self {
        case .menuBar:
            return true
        case .launchAtLoginStatus, .setLaunchAtLogin:
            return false
        }
    }
}

@MainActor
enum CommandLineRunner {
    static func run(_ mode: AppLaunchMode) -> Int32 {
        let controller = LaunchAtLoginController()

        switch mode {
        case .menuBar:
            return 0
        case .launchAtLoginStatus:
            print(summary(for: controller))
            return 0
        case let .setLaunchAtLogin(enabled):
            let succeeded = controller.setEnabled(enabled)
            print(summary(for: controller))
            return succeeded ? 0 : 1
        }
    }

    private static func summary(for controller: LaunchAtLoginController) -> String {
        var lines = [
            "state=\(controller.state.commandName)",
            "message=\(controller.detailMessage())"
        ]

        if let lastErrorMessage = controller.lastErrorMessage {
            lines.append("error=\(lastErrorMessage)")
        }

        return lines.joined(separator: "\n")
    }
}
