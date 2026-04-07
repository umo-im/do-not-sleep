import Foundation
import IOKit.pwr_mgt

@MainActor
final class SleepAssertionController: ObservableObject {
    enum ProtectionMode {
        case none
        case systemSleep
        case screenSaver
        case systemSleepAndScreenSaver
    }

    @Published private(set) var isPreventingSleep = false
    @Published private(set) var isPreventingScreenSaver = false
    @Published private(set) var startedAt: Date?
    @Published private(set) var lastErrorCode: Int32?
    @Published private(set) var screenSaverErrorCode: Int32?

    private var sleepAssertionID: IOPMAssertionID = 0
    private var screenSaverAssertionID: IOPMAssertionID = 0
    private var sleepStartedAt: Date?
    private var screenSaverStartedAt: Date?

    private let restoreSleepKey = "restoreSleepPreventionOnLaunch"
    private let restoreScreenSaverKey = "restoreScreenSaverPreventionOnLaunch"

    init() {
        if shouldRestoreSleepPrevention {
            enableSleepPrevention()
        }

        if shouldRestoreScreenSaverPrevention {
            enableScreenSaverPrevention()
        }
    }

    isolated deinit {
        releaseAssertion(&sleepAssertionID)
        releaseAssertion(&screenSaverAssertionID)
    }

    var shouldRestoreSleepPrevention: Bool {
        restoreFlag(forKey: restoreSleepKey, defaultValue: true)
    }

    var shouldRestoreScreenSaverPrevention: Bool {
        restoreFlag(forKey: restoreScreenSaverKey, defaultValue: false)
    }

    var hasActiveProtection: Bool {
        isPreventingSleep || isPreventingScreenSaver
    }

    var protectionMode: ProtectionMode {
        switch (isPreventingSleep, isPreventingScreenSaver) {
        case (false, false):
            return .none
        case (true, false):
            return .systemSleep
        case (false, true):
            return .screenSaver
        case (true, true):
            return .systemSleepAndScreenSaver
        }
    }

    func setEnabled(_ enabled: Bool) {
        enabled ? enableSleepPrevention() : disableSleepPrevention()
    }

    func setScreenSaverEnabled(_ enabled: Bool) {
        enabled ? enableScreenSaverPrevention() : disableScreenSaverPrevention()
    }

    private func enableSleepPrevention() {
        guard !isPreventingSleep else { return }

        let result = createAssertion(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            "Keep the Mac awake" as CFString,
            &sleepAssertionID
        )

        guard result == kIOReturnSuccess else {
            sleepAssertionID = 0
            sleepStartedAt = nil
            isPreventingSleep = false
            lastErrorCode = Int32(result)
            UserDefaults.standard.set(false, forKey: restoreSleepKey)
            refreshStartedAt()
            return
        }

        sleepStartedAt = .now
        isPreventingSleep = true
        lastErrorCode = nil
        UserDefaults.standard.set(true, forKey: restoreSleepKey)
        refreshStartedAt()
    }

    private func disableSleepPrevention() {
        guard isPreventingSleep else { return }

        releaseAssertion(&sleepAssertionID)
        sleepStartedAt = nil
        isPreventingSleep = false
        lastErrorCode = nil
        UserDefaults.standard.set(false, forKey: restoreSleepKey)
        refreshStartedAt()
    }

    private func enableScreenSaverPrevention() {
        guard !isPreventingScreenSaver else { return }

        let result = createAssertion(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            "Keep the display awake" as CFString,
            &screenSaverAssertionID
        )

        guard result == kIOReturnSuccess else {
            screenSaverAssertionID = 0
            screenSaverStartedAt = nil
            isPreventingScreenSaver = false
            screenSaverErrorCode = Int32(result)
            UserDefaults.standard.set(false, forKey: restoreScreenSaverKey)
            refreshStartedAt()
            return
        }

        screenSaverStartedAt = .now
        isPreventingScreenSaver = true
        screenSaverErrorCode = nil
        UserDefaults.standard.set(true, forKey: restoreScreenSaverKey)
        refreshStartedAt()
    }

    private func disableScreenSaverPrevention() {
        guard isPreventingScreenSaver else { return }

        releaseAssertion(&screenSaverAssertionID)
        screenSaverStartedAt = nil
        isPreventingScreenSaver = false
        screenSaverErrorCode = nil
        UserDefaults.standard.set(false, forKey: restoreScreenSaverKey)
        refreshStartedAt()
    }

    private func refreshStartedAt() {
        startedAt = [sleepStartedAt, screenSaverStartedAt].compactMap { $0 }.min()
    }

    private func restoreFlag(forKey key: String, defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultValue
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    private func createAssertion(
        _ assertionType: CFString,
        _ reason: CFString,
        _ assertionID: inout IOPMAssertionID
    ) -> IOReturn {
        IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
    }

    private func releaseAssertion(_ assertionID: inout IOPMAssertionID) {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }
}
