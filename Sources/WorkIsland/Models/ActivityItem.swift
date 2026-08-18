import Foundation

enum ActivityItemKind: String, Codable, CaseIterable, Identifiable {
    case task
    case routine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task:
            return "Task"
        case .routine:
            return "Routine"
        }
    }

    var systemImage: String {
        switch self {
        case .task:
            return "checkmark.circle"
        case .routine:
            return "repeat"
        }
    }

    var islandSystemImage: String {
        switch self {
        case .task:
            return "circle"
        case .routine:
            return "repeat"
        }
    }
}

enum RoutineFrequency: String, Codable, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var intervalUnit: String {
        switch self {
        case .day:
            return "day"
        case .week:
            return "week"
        case .month:
            return "month"
        }
    }
}

enum RoutineMonthMode: String, Codable, CaseIterable, Identifiable {
    case dates
    case pattern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dates:
            return "Date"
        case .pattern:
            return "Pattern"
        }
    }
}

enum RoutineOrdinal: String, Codable, CaseIterable, Identifiable {
    case first
    case second
    case third
    case fourth
    case last

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var index: Int? {
        switch self {
        case .first:
            return 1
        case .second:
            return 2
        case .third:
            return 3
        case .fourth:
            return 4
        case .last:
            return nil
        }
    }
}

struct RoutineSchedule: Codable, Hashable {
    var frequency: RoutineFrequency
    var interval: Int
    var weekdays: [Int]
    var monthMode: RoutineMonthMode
    var monthDates: [Int]
    var includesLastDay: Bool
    var ordinal: RoutineOrdinal
    var ordinalWeekday: Int
    var anchorDate: Date

    init(
        frequency: RoutineFrequency = .day,
        interval: Int = 1,
        weekdays: [Int] = [],
        monthMode: RoutineMonthMode = .dates,
        monthDates: [Int] = [],
        includesLastDay: Bool = false,
        ordinal: RoutineOrdinal = .first,
        ordinalWeekday: Int? = nil,
        anchorDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        let weekday = calendar.component(.weekday, from: anchorDate)
        let monthDate = calendar.component(.day, from: anchorDate)

        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = Self.cleanedWeekdays(
            weekdays.isEmpty ? [weekday] : weekdays
        )
        self.monthMode = monthMode
        self.monthDates = Self.cleanedMonthDates(
            monthDates.isEmpty ? [monthDate] : monthDates
        )
        self.includesLastDay = includesLastDay
        self.ordinal = ordinal
        self.ordinalWeekday = ordinalWeekday.flatMap {
            (1...7).contains($0) ? $0 : nil
        } ?? weekday
        self.anchorDate = calendar.startOfDay(for: anchorDate)
    }

    var isValid: Bool {
        guard interval > 0 else {
            return false
        }

        switch frequency {
        case .day:
            return true
        case .week:
            return !Self.cleanedWeekdays(weekdays).isEmpty
        case .month:
            switch monthMode {
            case .dates:
                return !Self.cleanedMonthDates(monthDates).isEmpty || includesLastDay
            case .pattern:
                return (1...7).contains(ordinalWeekday)
            }
        }
    }

    func isScheduled(
        on date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard isValid else {
            return false
        }

        let day = calendar.startOfDay(for: date)
        let anchorDay = calendar.startOfDay(for: anchorDate)
        guard day >= anchorDay else {
            return false
        }

        switch frequency {
        case .day:
            let distance = calendar.dateComponents(
                [.day],
                from: anchorDay,
                to: day
            ).day ?? -1
            return distance >= 0 && distance.isMultiple(of: interval)

        case .week:
            let anchorWeek = Self.sundayStart(of: anchorDay, calendar: calendar)
            let currentWeek = Self.sundayStart(of: day, calendar: calendar)
            let dayDistance = calendar.dateComponents(
                [.day],
                from: anchorWeek,
                to: currentWeek
            ).day ?? -1
            guard dayDistance >= 0,
                  (dayDistance / 7).isMultiple(of: interval) else {
                return false
            }
            return Self.cleanedWeekdays(weekdays).contains(
                calendar.component(.weekday, from: day)
            )

        case .month:
            let anchorMonth = Self.monthStart(of: anchorDay, calendar: calendar)
            let currentMonth = Self.monthStart(of: day, calendar: calendar)
            let distance = calendar.dateComponents(
                [.month],
                from: anchorMonth,
                to: currentMonth
            ).month ?? -1
            guard distance >= 0, distance.isMultiple(of: interval) else {
                return false
            }
            return matchesMonthRule(day, calendar: calendar)
        }
    }

    func nextDates(
        startingAt date: Date,
        count: Int = 3,
        calendar: Calendar = .current
    ) -> [Date] {
        guard count > 0, isValid else {
            return []
        }

        var dates: [Date] = []
        var cursor = calendar.startOfDay(for: date)

        for _ in 0..<40_000 {
            if isScheduled(on: cursor, calendar: calendar) {
                dates.append(cursor)
                if dates.count == count {
                    break
                }
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return dates
    }

    func mostRecentDate(
        onOrBefore date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard isValid else {
            return nil
        }

        let anchorDay = calendar.startOfDay(for: anchorDate)
        var cursor = calendar.startOfDay(for: date)
        guard cursor >= anchorDay else {
            return nil
        }

        for _ in 0..<40_000 {
            if isScheduled(on: cursor, calendar: calendar) {
                return cursor
            }

            guard cursor > anchorDay,
                  let previous = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: cursor
                  ) else {
                break
            }
            cursor = previous
        }

        return nil
    }

    var summary: String {
        let every = interval == 1
            ? "Every \(frequency.intervalUnit)"
            : "Every \(interval) \(frequency.intervalUnit)s"

        switch frequency {
        case .day:
            return every
        case .week:
            let days = Self.cleanedWeekdays(weekdays)
                .map(Self.shortWeekdayName)
                .joined(separator: ", ")
            return "\(every) · \(days)"
        case .month:
            switch monthMode {
            case .dates:
                var labels = Self.cleanedMonthDates(monthDates).map(String.init)
                if includesLastDay {
                    labels.append("Last")
                }
                return "\(every) · \(labels.joined(separator: ", "))"
            case .pattern:
                return "\(every) · \(ordinal.title) \(Self.weekdayName(ordinalWeekday))"
            }
        }
    }

    static func shortWeekdayName(_ weekday: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard (1...7).contains(weekday) else {
            return "Day"
        }
        return names[weekday - 1]
    }

    static func weekdayName(_ weekday: Int) -> String {
        let names = [
            "Sunday", "Monday", "Tuesday", "Wednesday",
            "Thursday", "Friday", "Saturday"
        ]
        guard (1...7).contains(weekday) else {
            return "Day"
        }
        return names[weekday - 1]
    }

    private func matchesMonthRule(
        _ day: Date,
        calendar: Calendar
    ) -> Bool {
        switch monthMode {
        case .dates:
            let dayNumber = calendar.component(.day, from: day)
            if Self.cleanedMonthDates(monthDates).contains(dayNumber) {
                return true
            }

            guard includesLastDay,
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) else {
                return false
            }
            return calendar.component(.month, from: tomorrow)
                != calendar.component(.month, from: day)

        case .pattern:
            guard calendar.component(.weekday, from: day) == ordinalWeekday else {
                return false
            }

            if let ordinalIndex = ordinal.index {
                let dayNumber = calendar.component(.day, from: day)
                return ((dayNumber - 1) / 7) + 1 == ordinalIndex
            }

            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: day) else {
                return false
            }
            return calendar.component(.month, from: nextWeek)
                != calendar.component(.month, from: day)
        }
    }

    private static func cleanedWeekdays(_ values: [Int]) -> [Int] {
        Array(Set(values.filter { (1...7).contains($0) })).sorted()
    }

    private static func cleanedMonthDates(_ values: [Int]) -> [Int] {
        Array(Set(values.filter { (1...31).contains($0) })).sorted()
    }

    private static func sundayStart(
        of date: Date,
        calendar: Calendar
    ) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        return calendar.date(byAdding: .day, value: -(weekday - 1), to: day) ?? day
    }

    private static func monthStart(
        of date: Date,
        calendar: Calendar
    ) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
            ?? calendar.startOfDay(for: date)
    }
}

struct ActivityItem: Identifiable, Codable, Hashable {
    let id: UUID
    let activityID: UUID
    var title: String
    let kind: ActivityItemKind
    let createdAt: Date
    var sortOrder: Int?
    var completedAt: Date?
    var isPaused: Bool
    var schedule: RoutineSchedule?
    var completedOccurrenceKeys: [String]

    init(
        id: UUID = UUID(),
        activityID: UUID,
        title: String,
        kind: ActivityItemKind,
        createdAt: Date = Date(),
        sortOrder: Int? = nil,
        completedAt: Date? = nil,
        isPaused: Bool = false,
        schedule: RoutineSchedule? = nil,
        completedOccurrenceKeys: [String] = []
    ) {
        self.id = id
        self.activityID = activityID
        self.title = title
        self.kind = kind
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.completedAt = completedAt
        self.isPaused = isPaused
        self.schedule = schedule
        self.completedOccurrenceKeys = Array(Set(completedOccurrenceKeys)).sorted()
    }

    func isSelectable(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        switch kind {
        case .task:
            return completedAt == nil
        case .routine:
            guard !isPaused,
                  let schedule,
                  schedule.isScheduled(on: date, calendar: calendar) else {
                return false
            }
            return !completedOccurrenceKeys.contains(
                Self.occurrenceKey(for: date, calendar: calendar)
            )
        }
    }

    func nextPendingDates(
        startingAt date: Date = Date(),
        count: Int = 3,
        calendar: Calendar = .current
    ) -> [Date] {
        guard kind == .routine, let schedule else {
            return []
        }

        return schedule
            .nextDates(
                startingAt: date,
                count: count + completedOccurrenceKeys.count,
                calendar: calendar
            )
            .filter {
                !completedOccurrenceKeys.contains(
                    Self.occurrenceKey(for: $0, calendar: calendar)
                )
            }
            .prefix(count)
            .map { $0 }
    }

    func completedOccurrenceKeyForCurrentCycle(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard kind == .routine, let schedule else {
            return nil
        }

        let currentDay = calendar.startOfDay(for: date)
        for key in completedOccurrenceKeys.reversed() {
            guard let completedDay = Self.occurrenceDate(
                for: key,
                calendar: calendar
            ), completedDay <= currentDay,
               schedule.isScheduled(on: completedDay, calendar: calendar) else {
                continue
            }

            guard let dayAfterCompletion = calendar.date(
                byAdding: .day,
                value: 1,
                to: completedDay
            ) else {
                return key
            }

            let nextOccurrence = schedule.nextDates(
                startingAt: dayAfterCompletion,
                count: 1,
                calendar: calendar
            ).first
            let remainsCompleted = nextOccurrence.map { $0 > currentDay } ?? true
            return remainsCompleted ? key : nil
        }

        return nil
    }

    func occurrenceKeyForCurrentCycle(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard kind == .routine,
              let occurrence = schedule?.mostRecentDate(
                onOrBefore: date,
                calendar: calendar
              ) else {
            return nil
        }

        return Self.occurrenceKey(for: occurrence, calendar: calendar)
    }

    func completionDateForCurrentCycle(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        completedOccurrenceKeyForCurrentCycle(at: date, calendar: calendar)
            .flatMap { Self.occurrenceDate(for: $0, calendar: calendar) }
    }

    static func occurrenceKey(
        for date: Date,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func occurrenceDate(
        for key: String,
        calendar: Calendar
    ) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components) else {
            return nil
        }
        let normalized = calendar.startOfDay(for: date)
        return occurrenceKey(for: normalized, calendar: calendar) == key
            ? normalized
            : nil
    }
}
