import AppKit
import SwiftUI

enum AppLaunchEnvironment {
    static let mode = AppLaunchMode()
}

@main
struct DoNotSleepApp: App {
    private let launchMode = AppLaunchEnvironment.mode
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var sleepController = SleepAssertionController()
    @StateObject private var launchAtLoginController = LaunchAtLoginController()

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(launchMode.showsMenuBar)) {
            MenuBarContentView(
                sleepController: sleepController,
                launchAtLoginController: launchAtLoginController
            )
        } label: {
            Image(systemName: menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSymbolName: String {
        switch sleepController.protectionMode {
        case .none:
            return "bolt.slash"
        case .systemSleep:
            return "bolt.fill"
        case .screenSaver, .systemSleepAndScreenSaver:
            return "display"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AppLaunchEnvironment.mode.showsMenuBar else {
            Task { @MainActor in
                exit(CommandLineRunner.run(AppLaunchEnvironment.mode))
            }
            return
        }

        NSApp.setActivationPolicy(.accessory)
    }
}
