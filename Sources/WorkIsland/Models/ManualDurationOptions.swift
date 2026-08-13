import Foundation

enum ManualDurationOptions {
    static let stepPreferenceKey = "manualMinuteStep"
    static let defaultMinuteStep = 5
    static let minuteStepRange = 1...59
    static let hours = Array(0...24)

    static func normalizedStep(_ step: Int) -> Int {
        minuteStepRange.contains(step) ? step : defaultMinuteStep
    }

    static func minutes(for step: Int) -> [Int] {
        let resolvedStep = normalizedStep(step)
        return Array(stride(from: 0, to: 60, by: resolvedStep))
    }

    static func snappedMinute(_ minute: Int, step: Int) -> Int {
        let resolvedStep = normalizedStep(step)
        let clampedMinute = min(59, max(0, minute))
        let snappedMinute = Int(
            (Double(clampedMinute) / Double(resolvedStep)).rounded()
        ) * resolvedStep
        return min(minutes(for: resolvedStep).last ?? 0, snappedMinute)
    }

    static func duration(hours: Int, minutes: Int) -> TimeInterval {
        let resolvedHours = max(0, hours)
        let resolvedMinutes = min(59, max(0, minutes))
        return TimeInterval((resolvedHours * 3_600) + (resolvedMinutes * 60))
    }
}
