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
        MenuBarExtra(
            L10n.string("menu.title"),
            systemImage: sleepController.isPreventingSleep ? "bolt.fill" : "bolt.slash",
            isInserted: .constant(launchMode.showsMenuBar)
        ) {
            MenuBarContentView(
                sleepController: sleepController,
                launchAtLoginController: launchAtLoginController
            )
        }
        .menuBarExtraStyle(.window)
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
