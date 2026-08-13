import Foundation

enum HistoryRange: String, CaseIterable, Identifiable {
    case all
    case thirtyDays
    case sevenDays
    case today

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .thirtyDays:
            return "30 Days"
        case .sevenDays:
            return "7 Days"
        case .today:
            return "Today"
        }
    }

    func startDay(
        through endingDay: Date,
        earliestHistoryDay: Date?,
        calendar: Calendar = .current
    ) -> Date {
        let finalDay = calendar.startOfDay(for: endingDay)

        switch self {
        case .all:
            guard let earliestHistoryDay else {
                return finalDay
            }
            return min(calendar.startOfDay(for: earliestHistoryDay), finalDay)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -29, to: finalDay) ?? finalDay
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -6, to: finalDay) ?? finalDay
        case .today:
            return finalDay
        }
    }
}
