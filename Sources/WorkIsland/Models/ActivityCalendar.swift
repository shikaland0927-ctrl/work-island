import Foundation

struct ActivityWeek: Identifiable, Equatable {
    let startDate: Date
    let days: [DailyWorkTotal?]

    var id: Date { startDate }
}

struct CalendarDayRange: Equatable {
    let startDate: Date
    let endDate: Date
    let dayCount: Int
}

enum WorkdayCalendar {
    static let validStartHours = 0..<24

    static func normalizedStartHour(_ hour: Int) -> Int {
        validStartHours.contains(hour) ? hour : 0
    }

    static func day(
        containing date: Date,
        startHour: Int,
        calendar: Calendar = .current
    ) -> Date {
        let calendarDay = calendar.startOfDay(for: date)
        let boundary = start(
            of: calendarDay,
            startHour: startHour,
            calendar: calendar
        )

        guard date < boundary else {
            return calendarDay
        }

        return calendar.date(
            byAdding: .day,
            value: -1,
            to: calendarDay
        ) ?? calendarDay
    }

    static func interval(
        for day: Date,
        startHour: Int,
        calendar: Calendar = .current
    ) -> DateInterval {
        let calendarDay = calendar.startOfDay(for: day)
        let intervalStart = start(
            of: calendarDay,
            startHour: startHour,
            calendar: calendar
        )
        let nextDay = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendarDay
        ) ?? calendarDay.addingTimeInterval(86_400)
        let intervalEnd = start(
            of: nextDay,
            startHour: startHour,
            calendar: calendar
        )

        return DateInterval(
            start: intervalStart,
            end: max(intervalStart, intervalEnd)
        )
    }

    static func start(
        of day: Date,
        startHour: Int,
        calendar: Calendar = .current
    ) -> Date {
        let calendarDay = calendar.startOfDay(for: day)
        return calendar.date(
            byAdding: .hour,
            value: normalizedStartHour(startHour),
            to: calendarDay
        ) ?? calendarDay
    }
}

enum DashboardPeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    static let graphCases: [DashboardPeriod] = [.week, .month]

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var graphAxisStride: Int {
        self == .month ? 5 : 1
    }

    func shiftedDate(
        from date: Date,
        by offset: Int,
        calendar: Calendar = .current
    ) -> Date {
        let shifted: Date?
        switch self {
        case .day:
            shifted = calendar.date(byAdding: .day, value: offset, to: date)
        case .week:
            shifted = calendar.date(byAdding: .day, value: offset * 7, to: date)
        case .month:
            shifted = calendar.date(byAdding: .month, value: offset, to: date)
        }
        return calendar.startOfDay(for: shifted ?? date)
    }

    func calendarRange(
        containing date: Date,
        calendar: Calendar = .current
    ) -> CalendarDayRange {
        switch self {
        case .day:
            let day = calendar.startOfDay(for: date)
            return CalendarDayRange(startDate: day, endDate: day, dayCount: 1)
        case .week:
            return ActivityCalendar.sundayWeek(containing: date, calendar: calendar)
        case .month:
            return ActivityCalendar.month(containing: date, calendar: calendar)
        }
    }

    func displayLabel(
        containing date: Date,
        calendar: Calendar = .current
    ) -> String {
        let range = calendarRange(containing: date, calendar: calendar)
        let timeZone = calendar.timeZone

        switch self {
        case .day:
            return WorkFormatting.compactDate(range.startDate, timeZone: timeZone)
        case .week:
            return "\(WorkFormatting.monthDay(range.startDate, timeZone: timeZone))–\(WorkFormatting.monthDay(range.endDate, timeZone: timeZone))"
        case .month:
            return WorkFormatting.abbreviatedMonth(range.startDate, timeZone: timeZone)
        }
    }
}

enum ActivityCalendar {
    static func sundayWeek(
        containing date: Date,
        calendar: Calendar = .current
    ) -> CalendarDayRange {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 1

        let day = weekCalendar.startOfDay(for: date)
        let weekdayOffset = max(
            0,
            weekCalendar.component(.weekday, from: day) - weekCalendar.firstWeekday
        )
        let startDate = weekCalendar.date(
            byAdding: .day,
            value: -weekdayOffset,
            to: day
        ) ?? day
        let endDate = weekCalendar.date(
            byAdding: .day,
            value: 6,
            to: startDate
        ) ?? startDate

        return CalendarDayRange(
            startDate: startDate,
            endDate: endDate,
            dayCount: 7
        )
    }

    static func month(
        containing date: Date,
        calendar: Calendar = .current
    ) -> CalendarDayRange {
        let day = calendar.startOfDay(for: date)
        let monthStart = calendar.date(
            from: calendar.dateComponents([.era, .year, .month], from: day)
        ) ?? day
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 1
        let monthEnd = calendar.date(
            byAdding: .day,
            value: max(0, dayCount - 1),
            to: monthStart
        ) ?? monthStart

        return CalendarDayRange(
            startDate: monthStart,
            endDate: monthEnd,
            dayCount: dayCount
        )
    }

    static func daysElapsedInSundayWeek(
        through date: Date,
        calendar: Calendar = .current
    ) -> Int {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 1
        let day = weekCalendar.startOfDay(for: date)
        return max(1, weekCalendar.component(.weekday, from: day))
    }

    static func weeks(
        from points: [DailyWorkTotal],
        calendar: Calendar = .current
    ) -> [ActivityWeek] {
        guard let firstPoint = points.first,
              let lastPoint = points.last else {
            return []
        }

        var weekCalendar = calendar
        weekCalendar.firstWeekday = 1

        let firstDay = weekCalendar.startOfDay(for: firstPoint.day)
        let lastDay = weekCalendar.startOfDay(for: lastPoint.day)
        let weekdayOffset = (
            weekCalendar.component(.weekday, from: firstDay)
                - weekCalendar.firstWeekday
                + 7
        ) % 7
        let firstWeekStart = weekCalendar.date(
            byAdding: .day,
            value: -weekdayOffset,
            to: firstDay
        ) ?? firstDay

        let totalsByDay = Dictionary(
            uniqueKeysWithValues: points.map {
                (weekCalendar.startOfDay(for: $0.day), $0)
            }
        )
        let coveredDays = max(
            0,
            weekCalendar.dateComponents(
                [.day],
                from: firstWeekStart,
                to: lastDay
            ).day ?? 0
        )
        let weekCount = (coveredDays / 7) + 1

        return (0..<weekCount).compactMap { weekOffset in
            guard let weekStart = weekCalendar.date(
                byAdding: .day,
                value: weekOffset * 7,
                to: firstWeekStart
            ) else {
                return nil
            }

            let days = (0..<7).map { dayOffset -> DailyWorkTotal? in
                guard let day = weekCalendar.date(
                    byAdding: .day,
                    value: dayOffset,
                    to: weekStart
                ),
                day >= firstDay,
                day <= lastDay else {
                    return nil
                }
                return totalsByDay[weekCalendar.startOfDay(for: day)]
            }

            return ActivityWeek(startDate: weekStart, days: days)
        }
    }
}
