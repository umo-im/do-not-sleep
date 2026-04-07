import Foundation

enum L10n {
    private static let bundle: Bundle = {
#if SWIFT_PACKAGE
        return .module
#else
        return .main
#endif
    }()

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }

    static func activeDuration(since startDate: Date?, now: Date) -> String {
        guard let startDate else {
            return string("status.justStarted")
        }

        return format("status.activeDuration", durationText(for: max(1, now.timeIntervalSince(startDate))))
    }

    static func autoDisableCountdown(until endDate: Date?, now: Date) -> String {
        guard let endDate else {
            return string("timer.option.manual")
        }

        let remainingDuration = max(1, endDate.timeIntervalSince(now))
        return format("timer.remaining", durationText(for: remainingDuration))
    }

    private static func durationText(for duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = [.dropAll]

        if duration >= 3600 {
            formatter.allowedUnits = [.hour, .minute]
        } else if duration >= 60 {
            formatter.allowedUnits = [.minute, .second]
        } else {
            formatter.allowedUnits = [.second]
        }

        return formatter.string(from: duration) ?? "\(Int(duration))"
    }
}
