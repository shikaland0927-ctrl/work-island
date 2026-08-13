import SwiftUI

struct HistoryActivityView: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences
    let taskID: UUID?
    let range: HistoryRange

    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 4

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let endingDay = WorkdayCalendar.day(
                containing: context.date,
                startHour: preferences.dayStartHour
            )
            let points = store.dailyTotals(
                in: range,
                through: endingDay,
                forTaskID: taskID,
                at: context.date,
                dayStartHour: preferences.dayStartHour
            )
            let weeks = ActivityCalendar.weeks(from: points)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryCards(for: points)
                    activityCard(points: points, weeks: weeks)
                }
                .padding(28)
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Activity")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text("A contribution-style view of \(selectedTaskName) • \(range.title)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryCards(for points: [DailyWorkTotal]) -> some View {
        let total = points.reduce(0) { $0 + $1.duration }
        let activeDays = points.filter { $0.duration > 0 }.count
        let bestStreak = bestStreak(in: points)

        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 145), spacing: 14)],
            spacing: 14
        ) {
            HistoryMetricCard(
                title: "TOTAL",
                value: WorkFormatting.readable(total),
                detail: range.title,
                systemImage: "sum"
            )
            HistoryMetricCard(
                title: "ACTIVE DAYS",
                value: "\(activeDays)",
                detail: activeDays == 1 ? "Recorded day" : "Recorded days",
                systemImage: "calendar.badge.checkmark"
            )
            HistoryMetricCard(
                title: "BEST STREAK",
                value: "\(bestStreak)",
                detail: bestStreak == 1 ? "Consecutive day" : "Consecutive days",
                systemImage: "flame.fill"
            )
        }
    }

    private func activityCard(
        points: [DailyWorkTotal],
        weeks: [ActivityWeek]
    ) -> some View {
        let maximum = max(1, points.map(\.duration).max() ?? 1)

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Daily Activity")
                    .font(.title3.weight(.semibold))
                Text(dateRangeLabel(for: points))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 9) {
                weekdayLabels

                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: cellSpacing) {
                            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                                Color.clear
                                    .frame(width: cellSize, height: 12)
                                    .overlay(alignment: .leading) {
                                        Text(monthLabel(for: index, in: weeks))
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            .fixedSize()
                                    }
                                    .accessibilityHidden(true)
                            }
                        }

                        HStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(weeks) { week in
                                VStack(spacing: cellSpacing) {
                                    ForEach(0..<7, id: \.self) { dayIndex in
                                        activityCell(
                                            point: week.days[dayIndex],
                                            maximum: maximum
                                        )
                                    }
                                }
                            }
                        }

                        activityLegend
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(22)
        .workCard()
    }

    private var weekdayLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdayLabel(for: index))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: cellSize, alignment: .trailing)
            }
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private func activityCell(
        point: DailyWorkTotal?,
        maximum: TimeInterval
    ) -> some View {
        if let point {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(activityColor(for: point.duration, maximum: maximum))
                .frame(width: cellSize, height: cellSize)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
                }
                .help("\(longDate(point.day)): \(WorkFormatting.readable(point.duration))")
                .accessibilityLabel(longDate(point.day))
                .accessibilityValue(WorkFormatting.readable(point.duration))
        } else {
            Color.clear
                .frame(width: cellSize, height: cellSize)
                .accessibilityHidden(true)
        }
    }

    private var activityLegend: some View {
        HStack(spacing: 5) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(legendColor(level: level))
                    .frame(width: 12, height: 12)
            }

            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityHidden(true)
    }

    private var selectedTaskName: String {
        guard let taskID,
              let task = store.task(id: taskID) else {
            return "all activities"
        }
        return task.name
    }

    private func activityColor(
        for duration: TimeInterval,
        maximum: TimeInterval
    ) -> Color {
        guard duration > 0 else {
            return Color.primary.opacity(0.07)
        }

        let ratio = min(1, duration / maximum)
        switch ratio {
        case 0..<0.25:
            return Color.indigo.opacity(0.28)
        case 0.25..<0.5:
            return Color.indigo.opacity(0.47)
        case 0.5..<0.75:
            return Color.indigo.opacity(0.68)
        default:
            return Color.indigo.opacity(0.92)
        }
    }

    private func legendColor(level: Double) -> Color {
        guard level > 0 else {
            return Color.primary.opacity(0.07)
        }
        return Color.indigo.opacity(0.18 + (level * 0.74))
    }

    private func weekdayLabel(for index: Int) -> String {
        switch index {
        case 1:
            return "Mon"
        case 3:
            return "Wed"
        case 5:
            return "Fri"
        default:
            return ""
        }
    }

    private func monthLabel(
        for index: Int,
        in weeks: [ActivityWeek]
    ) -> String {
        guard let currentDay = weeks[index].days.compactMap({ $0?.day }).first else {
            return ""
        }
        guard index > 0,
              let previousDay = weeks[index - 1].days.compactMap({ $0?.day }).last else {
            return shortMonth(currentDay)
        }

        let calendar = Calendar.current
        return calendar.component(.month, from: currentDay)
            == calendar.component(.month, from: previousDay)
            ? ""
            : shortMonth(currentDay)
    }

    private func bestStreak(in points: [DailyWorkTotal]) -> Int {
        var current = 0
        var best = 0

        for point in points {
            if point.duration > 0 {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }

        return best
    }

    private func dateRangeLabel(for points: [DailyWorkTotal]) -> String {
        guard let first = points.first?.day,
              let last = points.last?.day else {
            return range.title
        }
        return "\(shortDate(first)) – \(shortDate(last))"
    }

    private func shortMonth(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .locale(Locale(identifier: "en_US"))
        )
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .year()
                .locale(Locale(identifier: "en_US"))
        )
    }

    private func longDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .year()
                .month(.wide)
                .day()
                .weekday(.wide)
                .locale(Locale(identifier: "en_US"))
        )
    }
}
