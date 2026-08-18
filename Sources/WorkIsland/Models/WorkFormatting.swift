import Foundation

enum WorkFormatting {
    static func clock(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func readable(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded(.down)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(totalSeconds)s"
    }

    static func dayTitle(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.wide)
                .day()
                .weekday(.abbreviated)
                .locale(Locale(identifier: "en_US"))
        )
    }

    static func time(
        _ date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        formatted(date, pattern: "HH:mm", timeZone: timeZone)
    }

    static func compactDate(
        _ date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        formatted(date, pattern: "M/d (EEE)", timeZone: timeZone)
    }

    static func monthDay(
        _ date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        formatted(date, pattern: "M/d", timeZone: timeZone)
    }

    static func abbreviatedMonth(
        _ date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        formatted(date, pattern: "MMM", timeZone: timeZone)
    }

    private static func formatted(
        _ date: Date,
        pattern: String,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
