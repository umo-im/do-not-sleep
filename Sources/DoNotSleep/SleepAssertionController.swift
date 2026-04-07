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

    enum AutoDisablePreset: Int, CaseIterable, Identifiable {
        case fifteenMinutes = 900
        case thirtyMinutes = 1800
        case oneHour = 3600
        case twoHours = 7200
        case fourHours = 14400

        var id: Int { rawValue }

        var duration: TimeInterval {
            TimeInterval(rawValue)
        }
    }

    enum AutoDisableMode: Equatable {
        case manual
        case preset(AutoDisablePreset)
        case custom
    }

    @Published private(set) var isPreventingSleep = false
    @Published private(set) var isPreventingScreenSaver = false
    @Published private(set) var startedAt: Date?
    @Published private(set) var lastErrorCode: Int32?
    @Published private(set) var screenSaverErrorCode: Int32?
    @Published private(set) var autoDisableMode: AutoDisableMode = .manual
    @Published private(set) var autoDisableDeadline: Date?

    private var sleepAssertionID: IOPMAssertionID = 0
    private var screenSaverAssertionID: IOPMAssertionID = 0
    private var sleepStartedAt: Date?
    private var screenSaverStartedAt: Date?
    private var autoDisableTask: Task<Void, Never>?

    private let restoreSleepKey = "restoreSleepPreventionOnLaunch"
    private let restoreScreenSaverKey = "restoreScreenSaverPreventionOnLaunch"
    private let autoDisableModeKey = "autoDisableMode"
    private let autoDisableDeadlineKey = "autoDisableDeadline"

    init() {
        if shouldRestoreSleepPrevention {
            enableSleepPrevention()
        }

        if shouldRestoreScreenSaverPrevention {
            enableScreenSaverPrevention()
        }

        restoreAutoDisableState()
    }

    isolated deinit {
        autoDisableTask?.cancel()
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

    var hasScheduledAutoDisable: Bool {
        autoDisableDeadline != nil
    }

    func setEnabled(_ enabled: Bool) {
        enabled ? enableSleepPrevention() : disableSleepPrevention()
    }

    func setScreenSaverEnabled(_ enabled: Bool) {
        enabled ? enableScreenSaverPrevention() : disableScreenSaverPrevention()
    }

    func startAutoDisableTimer(_ preset: AutoDisablePreset) {
        guard hasActiveProtection else { return }
        scheduleAutoDisable(at: .now.addingTimeInterval(preset.duration), mode: .preset(preset))
    }

    func extendAutoDisableTimer(by duration: TimeInterval = AutoDisablePreset.fifteenMinutes.duration) {
        guard hasActiveProtection, let autoDisableDeadline else { return }
        let baseDate = max(autoDisableDeadline, .now)
        scheduleAutoDisable(at: baseDate.addingTimeInterval(duration), mode: .custom)
    }

    func cancelAutoDisableTimer() {
        clearAutoDisableTimer()
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
        clearAutoDisableTimerIfNeeded()
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
        clearAutoDisableTimerIfNeeded()
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

    private func disableAllProtections() {
        if isPreventingSleep {
            disableSleepPrevention()
        }

        if isPreventingScreenSaver {
            disableScreenSaverPrevention()
        }
    }

    private func clearAutoDisableTimerIfNeeded() {
        guard !hasActiveProtection else { return }
        clearAutoDisableTimer()
    }

    private func scheduleAutoDisable(at deadline: Date, mode: AutoDisableMode) {
        guard hasActiveProtection else { return }

        autoDisableTask?.cancel()
        autoDisableMode = mode
        autoDisableDeadline = deadline
        persistAutoDisableState()

        autoDisableTask = Task { [weak self] in
            let remainingSeconds = max(deadline.timeIntervalSinceNow, 0)
            let sleepNanoseconds = UInt64(remainingSeconds * 1_000_000_000)

            if sleepNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: sleepNanoseconds)
            }

            guard !Task.isCancelled, let self else { return }
            self.handleAutoDisableDeadline(deadline)
        }
    }

    private func handleAutoDisableDeadline(_ deadline: Date) {
        guard autoDisableDeadline == deadline else { return }
        disableAllProtections()
    }

    private func clearAutoDisableTimer() {
        autoDisableTask?.cancel()
        autoDisableTask = nil
        autoDisableMode = .manual
        autoDisableDeadline = nil
        clearPersistedAutoDisableState()
    }

    private func restoreAutoDisableState() {
        guard let storedDeadline = UserDefaults.standard.object(forKey: autoDisableDeadlineKey) as? Double else {
            clearPersistedAutoDisableState()
            return
        }

        guard hasActiveProtection else {
            clearPersistedAutoDisableState()
            return
        }

        let deadline = Date(timeIntervalSince1970: storedDeadline)

        guard deadline > .now else {
            disableAllProtections()
            return
        }

        scheduleAutoDisable(at: deadline, mode: restoredAutoDisableMode())
    }

    private func restoredAutoDisableMode() -> AutoDisableMode {
        guard let storedMode = UserDefaults.standard.string(forKey: autoDisableModeKey) else {
            return .custom
        }

        if storedMode == "custom" {
            return .custom
        }

        let presetPrefix = "preset:"

        if storedMode.hasPrefix(presetPrefix),
           let rawValue = Int(storedMode.dropFirst(presetPrefix.count)),
           let preset = AutoDisablePreset(rawValue: rawValue) {
            return .preset(preset)
        }

        return .custom
    }

    private func persistAutoDisableState() {
        guard let autoDisableDeadline else {
            clearPersistedAutoDisableState()
            return
        }

        UserDefaults.standard.set(autoDisableDeadline.timeIntervalSince1970, forKey: autoDisableDeadlineKey)
        UserDefaults.standard.set(serializedAutoDisableMode(), forKey: autoDisableModeKey)
    }

    private func serializedAutoDisableMode() -> String {
        switch autoDisableMode {
        case .manual:
            return "manual"
        case let .preset(preset):
            return "preset:\(preset.rawValue)"
        case .custom:
            return "custom"
        }
    }

    private func clearPersistedAutoDisableState() {
        UserDefaults.standard.removeObject(forKey: autoDisableModeKey)
        UserDefaults.standard.removeObject(forKey: autoDisableDeadlineKey)
    }
}
