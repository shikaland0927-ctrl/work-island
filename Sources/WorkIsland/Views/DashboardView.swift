import Charts
import SwiftUI

struct DashboardHeatmapMetrics {
    static let preferredCellSize: CGFloat = 10
    static let preferredSpacing: CGFloat = 3

    let cellSize: CGFloat
    let spacing: CGFloat

    static func fitting(weekCount: Int, availableWidth: CGFloat) -> Self {
        guard weekCount > 0 else {
            return Self(
                cellSize: preferredCellSize,
                spacing: preferredSpacing
            )
        }

        let gaps = max(0, weekCount - 1)
        let preferredWidth = CGFloat(weekCount) * preferredCellSize
            + CGFloat(gaps) * preferredSpacing
        let scale = min(1, max(0, availableWidth) / preferredWidth)

        return Self(
            cellSize: preferredCellSize * scale,
            spacing: preferredSpacing * scale
        )
    }

    func gridWidth(weekCount: Int) -> CGFloat {
        guard weekCount > 0 else {
            return 0
        }
        return CGFloat(weekCount) * cellSize
            + CGFloat(max(0, weekCount - 1)) * spacing
    }
}

struct DashboardAnalyticsLayout {
    static let graphPickerWidth: CGFloat = 180
    static let distributionPickerWidth: CGFloat = 250
    static let periodControlSpacing: CGFloat = 14
    static let navigationWidth: CGFloat = 44
    static let distributionLegendActivityMaximumWidth: CGFloat = 180
    static let distributionLegendColumnSpacing: CGFloat = 16

    static var trailingPeriodControlsWidth: CGFloat {
        distributionPickerWidth
            + periodControlSpacing
            + navigationWidth
    }

    static var pickerTrailingInset: CGFloat {
        periodControlSpacing + navigationWidth
    }
}

struct DashboardSummaryLayout {
    static let cardSpacing: CGFloat = 20
    static let totalCardWidth: CGFloat = 230
    static let cardMinHeight: CGFloat = 194
    static let metricSpacing: CGFloat = 8
}

struct DashboardView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        MainPageScrollContainer(
            maximumContentWidth: MainPageLayout.dashboardMaximumContentWidth
        ) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(
                    alignment: .top,
                    spacing: DashboardSummaryLayout.cardSpacing
                ) {
                    TotalCard()
                        .frame(width: DashboardSummaryLayout.totalCardWidth)

                    DashboardStatusCard()
                        .frame(maxWidth: .infinity)
                }

                ForEach(preferences.dashboardOrder) { card in
                    if preferences.isDashboardCardVisible(card) {
                        dashboardCard(card)
                    }
                }
            }
        }
        .navigationTitle("Dashboard")
    }

    @ViewBuilder
    private func dashboardCard(_ card: DashboardCard) -> some View {
        switch card {
        case .heatmap:
            DashboardHeatmapCard()
        case .graph:
            DashboardTrendCard()
        case .distribution:
            DashboardDistributionCard()
        }
    }
}

private struct TotalCard: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let currentDay = WorkdayCalendar.day(
                containing: context.date,
                startHour: preferences.dayStartHour
            )
            let todayTotal = store.totalDuration(
                on: currentDay,
                at: context.date,
                dayStartHour: preferences.dayStartHour
            )

            VStack(alignment: .leading, spacing: 14) {
                Label("TOTAL", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Text(WorkFormatting.clock(todayTotal))
                    .font(
                        .system(
                            size: 34,
                            weight: .bold,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("Completed and active work")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .padding(20)
            .frame(
                maxWidth: .infinity,
                minHeight: DashboardSummaryLayout.cardMinHeight,
                alignment: .leading
            )
        }
        .modifier(TotalCardSurface())
    }
}

private struct TotalCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [
                        Color.indigo,
                        Color.blue.opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(
                    cornerRadius: WorkAppearanceStyle.cardCornerRadius,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.indigo.opacity(0.22),
                radius: 18,
                y: 8
            )
    }
}

private struct DashboardStatusCard: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let stats = store.dashboardStats(
                at: context.date,
                dayStartHour: preferences.dayStartHour
            )

            VStack(alignment: .leading, spacing: 16) {
                Text("Status")
                    .font(.title3.weight(.semibold))

                HStack(spacing: DashboardSummaryLayout.metricSpacing) {
                    StatsMetric(
                        title: "Streak",
                        value: "\(stats.currentStreak)d",
                        detail: "Current",
                        systemImage: "flame.fill",
                        color: .orange
                    )

                    StatsMetric(
                        title: "Longest Streak",
                        value: "\(stats.longestStreak)d",
                        detail: "Record",
                        systemImage: "bolt.fill",
                        color: .pink
                    )

                    StatsMetric(
                        title: "Best Day",
                        value: WorkFormatting.readable(stats.bestDayDuration),
                        detail: stats.bestDay.map(shortDate) ?? "No work yet",
                        systemImage: "trophy.fill",
                        color: .yellow
                    )
                }
            }
            .padding(20)
            .frame(
                maxWidth: .infinity,
                minHeight: DashboardSummaryLayout.cardMinHeight,
                alignment: .topLeading
            )
        }
        .workCard()
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .locale(Locale(identifier: "en_US"))
        )
    }
}

private struct StatsMetric: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(
            Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

private struct DashboardHeatmapCard: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences

    private let weekdayLabelWidth: CGFloat = 26
    private let labelSpacing: CGFloat = 10

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let endingDay = WorkdayCalendar.day(
                containing: context.date,
                startHour: preferences.dayStartHour
            )
            let points = store.dailyTotals(
                last: 365,
                through: endingDay,
                at: context.date,
                dayStartHour: preferences.dayStartHour
            )
            let weeks = ActivityCalendar.weeks(from: points)
            let maximum = max(1, points.map(\.duration).max() ?? 1)
            let activeDays = points.filter { $0.duration > 0 }.count

            VStack(alignment: .leading, spacing: 16) {
                analyticsHeader(
                    title: "Heatmap",
                    subtitle: "Last 365 days",
                    trailing: "\(activeDays) active \(activeDays == 1 ? "day" : "days")"
                )

                GeometryReader { proxy in
                    let gridWidth = max(
                        0,
                        proxy.size.width - weekdayLabelWidth - labelSpacing
                    )
                    let metrics = DashboardHeatmapMetrics.fitting(
                        weekCount: weeks.count,
                        availableWidth: gridWidth
                    )

                    HStack(alignment: .top, spacing: labelSpacing) {
                        weekdayLabels(
                            cellSize: metrics.cellSize,
                            spacing: metrics.spacing
                        )

                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: metrics.spacing) {
                                ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                                    Color.clear
                                        .frame(width: metrics.cellSize, height: 12)
                                        .overlay(alignment: .leading) {
                                            Text(monthLabel(for: index, in: weeks))
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundStyle(.secondary)
                                                .fixedSize()
                                        }
                                        .accessibilityHidden(true)
                                }
                            }

                            HStack(alignment: .top, spacing: metrics.spacing) {
                                ForEach(weeks) { week in
                                    VStack(spacing: metrics.spacing) {
                                        ForEach(0..<7, id: \.self) { dayIndex in
                                            heatmapCell(
                                                point: week.days[dayIndex],
                                                maximum: maximum,
                                                cellSize: metrics.cellSize
                                            )
                                        }
                                    }
                                }
                            }

                        }
                        .padding(.bottom, 3)
                    }
                }
                .frame(height: 112)
            }
            .padding(22)
        }
        .workCard()
    }

    private func weekdayLabels(
        cellSize: CGFloat,
        spacing: CGFloat
    ) -> some View {
        VStack(spacing: spacing) {
            ForEach(0..<7, id: \.self) { index in
                Text(index == 1 ? "Mon" : (index == 3 ? "Wed" : (index == 5 ? "Fri" : "")))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: weekdayLabelWidth,
                        height: cellSize,
                        alignment: .trailing
                    )
            }
        }
        .padding(.top, 19)
    }

    @ViewBuilder
    private func heatmapCell(
        point: DailyWorkTotal?,
        maximum: TimeInterval,
        cellSize: CGFloat
    ) -> some View {
        if let point {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(heatmapColor(for: point.duration, maximum: maximum))
                .frame(width: cellSize, height: cellSize)
                .overlay {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
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

    private func heatmapColor(
        for duration: TimeInterval,
        maximum: TimeInterval
    ) -> Color {
        guard duration > 0 else {
            return Color.primary.opacity(0.065)
        }

        let ratio = min(1, duration / maximum)
        switch ratio {
        case 0..<0.25:
            return preferences.heatmapTint.color.opacity(0.28)
        case 0.25..<0.5:
            return preferences.heatmapTint.color.opacity(0.48)
        case 0.5..<0.75:
            return preferences.heatmapTint.color.opacity(0.70)
        default:
            return preferences.heatmapTint.color.opacity(0.94)
        }
    }

    private func monthLabel(
        for index: Int,
        in weeks: [ActivityWeek]
    ) -> String {
        let visibleDays = weeks[index].days.compactMap { $0?.day }
        guard let firstVisibleDay = visibleDays.first else {
            return ""
        }

        if index == 0 {
            return shortMonth(firstVisibleDay)
        }

        let calendar = Calendar.current
        guard let firstDayOfMonth = visibleDays.first(where: {
            calendar.component(.day, from: $0) == 1
        }) else {
            return ""
        }

        return shortMonth(firstDayOfMonth)
    }

    private func shortMonth(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
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

private struct DashboardTrendCard: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences
    @State private var range: DashboardPeriod = .week
    @State private var periodOffset = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let currentDay = WorkdayCalendar.day(
                containing: context.date,
                startHour: preferences.dayStartHour
            )
            let periodDate = range.shiftedDate(
                from: currentDay,
                by: periodOffset
            )
            let calendarRange = range.calendarRange(containing: periodDate)
            let totalPoints = store.dailyTotals(
                last: calendarRange.dayCount,
                through: calendarRange.endDate,
                at: context.date,
                dayStartHour: preferences.dayStartHour
            )
            let taskPoints = store.dailyTaskTotals(
                last: calendarRange.dayCount,
                through: calendarRange.endDate,
                at: context.date,
                dayStartHour: preferences.dayStartHour
            )
            let totals = store.taskTotals(
                last: calendarRange.dayCount,
                through: calendarRange.endDate,
                at: context.date,
                dayStartHour: preferences.dayStartHour
            )

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    analyticsHeader(
                        title: "Graph",
                        subtitle: range.displayLabel(containing: periodDate),
                        trailing: WorkFormatting.readable(
                            totalPoints.reduce(0) { $0 + $1.duration }
                        )
                    )

                    DashboardPeriodControls(
                        accessibilityName: "Graph range",
                        options: DashboardPeriod.graphCases,
                        pickerWidth: DashboardAnalyticsLayout.graphPickerWidth,
                        range: $range,
                        periodOffset: $periodOffset
                    )
                }

                if taskPoints.isEmpty {
                    AnalyticsEmptyState(
                        systemImage: "chart.bar.xaxis",
                        message: "No recorded work in this period."
                    )
                } else if let firstDay = totalPoints.first?.day,
                          let lastDay = totalPoints.last?.day,
                          let rangeEnd = Calendar.current.date(
                            byAdding: .day,
                            value: 1,
                            to: lastDay
                          ) {
                    Chart(taskPoints) { point in
                        BarMark(
                            x: .value("Day", point.day, unit: .day),
                            y: .value("Duration", point.duration),
                            stacking: .standard
                        )
                        .foregroundStyle(
                            TaskColorPalette.color(
                                for: point.taskID,
                                name: point.taskName
                            )
                        )
                        .cornerRadius(3)
                        .accessibilityLabel("\(shortDay(point.day)), \(point.taskName)")
                        .accessibilityValue(WorkFormatting.readable(point.duration))
                    }
                    .chartXScale(domain: firstDay...rangeEnd)
                    .chartXAxis {
                        AxisMarks(
                            values: .stride(
                                by: .day,
                                count: range.graphAxisStride
                            )
                        ) { value in
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(axisDay(date))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.primary.opacity(0.07))
                            AxisValueLabel {
                                if let duration = value.as(Double.self) {
                                    Text(axisDuration(duration))
                                }
                            }
                        }
                    }
                    .frame(height: 280)

                    DashboardTaskLegend(totals: totals)
                }
            }
            .padding(22)
        }
        .workCard()
        .onChange(of: range) { _ in
            periodOffset = 0
        }
    }

    private func axisDay(_ date: Date) -> String {
        if range == .week {
            return date.formatted(
                .dateTime
                    .weekday(.abbreviated)
                    .locale(Locale(identifier: "en_US"))
            )
        }
        return date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .locale(Locale(identifier: "en_US"))
        )
    }

    private func shortDay(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .weekday(.abbreviated)
                .locale(Locale(identifier: "en_US"))
        )
    }

    private func axisDuration(_ interval: TimeInterval) -> String {
        if interval >= 3_600 {
            return String(format: "%.1fh", interval / 3_600)
        }
        return "\(Int((interval / 60).rounded()))m"
    }
}

private struct DashboardDistributionCard: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences
    @State private var range: DashboardPeriod = .week
    @State private var periodOffset = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let currentDay = WorkdayCalendar.day(
                containing: context.date,
                startHour: preferences.dayStartHour
            )
            let periodDate = range.shiftedDate(
                from: currentDay,
                by: periodOffset
            )
            let calendarRange = range.calendarRange(containing: periodDate)
            let totals = store.taskTotals(
                last: calendarRange.dayCount,
                through: calendarRange.endDate,
                at: context.date,
                dayStartHour: preferences.dayStartHour
            )
            let totalDuration = totals.reduce(0) { $0 + $1.duration }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    analyticsHeader(
                        title: "Distribution",
                        subtitle: range.displayLabel(containing: periodDate),
                        trailing: WorkFormatting.readable(totalDuration)
                    )

                    DashboardPeriodControls(
                        accessibilityName: "Distribution range",
                        options: DashboardPeriod.allCases,
                        pickerWidth: DashboardAnalyticsLayout.distributionPickerWidth,
                        range: $range,
                        periodOffset: $periodOffset
                    )
                }

                if totals.isEmpty {
                    AnalyticsEmptyState(
                        systemImage: "chart.pie",
                        message: "No activity distribution is available for this period."
                    )
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 34) {
                            DashboardDonutChart(
                                totals: totals,
                                totalDuration: totalDuration
                            )
                            .frame(width: 250, height: 250)

                            DistributionLegend(
                                totals: totals,
                                totalDuration: totalDuration
                            )
                        }

                        VStack(spacing: 24) {
                            DashboardDonutChart(
                                totals: totals,
                                totalDuration: totalDuration
                            )
                            .frame(width: 230, height: 230)

                            DistributionLegend(
                                totals: totals,
                                totalDuration: totalDuration
                            )
                        }
                    }
                }
            }
            .padding(22)
        }
        .workCard()
        .onChange(of: range) { _ in
            periodOffset = 0
        }
    }
}

private struct DashboardTaskLegend: View {
    let totals: [TaskWorkTotal]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 155), spacing: 12)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(totals) { total in
                HStack(spacing: 8) {
                    Circle()
                        .fill(
                            TaskColorPalette.color(
                                for: total.taskID,
                                name: total.taskName
                            )
                        )
                        .frame(width: 8, height: 8)

                    Text(total.taskName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(WorkFormatting.readable(total.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct DistributionLegend: View {
    let totals: [TaskWorkTotal]
    let totalDuration: TimeInterval

    var body: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: DashboardAnalyticsLayout
                .distributionLegendColumnSpacing,
            verticalSpacing: 13
        ) {
            ForEach(totals) { total in
                GridRow(alignment: .center) {
                    HStack(spacing: 10) {
                        RoundedRectangle(
                            cornerRadius: 3,
                            style: .continuous
                        )
                        .fill(
                            TaskColorPalette.color(
                                for: total.taskID,
                                name: total.taskName
                            )
                        )
                        .frame(width: 12, height: 12)

                        Text(total.taskName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }
                    .frame(
                        maxWidth: DashboardAnalyticsLayout
                            .distributionLegendActivityMaximumWidth,
                        alignment: .leading
                    )

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(percentage(for: total.duration))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                        Text(WorkFormatting.readable(total.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .gridColumnAlignment(.trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percentage(for duration: TimeInterval) -> String {
        guard totalDuration > 0 else {
            return "0%"
        }
        return String(format: "%.0f%%", (duration / totalDuration) * 100)
    }
}

private struct DashboardDonutChart: View {
    let totals: [TaskWorkTotal]
    let totalDuration: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                ForEach(slices) { slice in
                    DonutSliceShape(
                        startAngle: .degrees(slice.startAngle),
                        endAngle: .degrees(slice.endAngle)
                    )
                    .fill(
                        TaskColorPalette.color(
                            for: slice.total.taskID,
                            name: slice.total.taskName
                        )
                    )
                    .overlay {
                        DonutSliceShape(
                            startAngle: .degrees(slice.startAngle),
                            endAngle: .degrees(slice.endAngle)
                        )
                        .stroke(Color(nsColor: .controlBackgroundColor), lineWidth: 2)
                    }
                }

                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: size * 0.52, height: size * 0.52)

                VStack(spacing: 3) {
                    Text("TOTAL")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(WorkFormatting.readable(totalDuration))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: size * 0.46)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
    }

    private var slices: [DonutSliceData] {
        guard totalDuration > 0 else {
            return []
        }

        var startAngle = -90.0
        return totals.map { total in
            let degrees = (total.duration / totalDuration) * 360
            let slice = DonutSliceData(
                total: total,
                startAngle: startAngle,
                endAngle: startAngle + degrees
            )
            startAngle += degrees
            return slice
        }
    }
}

private struct DonutSliceData: Identifiable {
    let total: TaskWorkTotal
    let startAngle: Double
    let endAngle: Double

    var id: UUID { total.taskID }
}

private struct DonutSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct DashboardPeriodNavigation: View {
    @Binding var periodOffset: Int

    var body: some View {
        HStack(spacing: 4) {
            previousButton
                .buttonStyle(.borderless)

            if periodOffset < 0 {
                nextButton
                    .buttonStyle(.borderless)
            } else {
                Color.clear
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
        }
        .frame(
            width: DashboardAnalyticsLayout.navigationWidth,
            alignment: .leading
        )
    }

    private var previousButton: some View {
        Button {
            periodOffset -= 1
        } label: {
            Image(systemName: "chevron.left")
                .frame(width: 20, height: 20)
        }
        .accessibilityLabel("Previous period")
        .help("Previous")
    }

    private var nextButton: some View {
        Button {
            periodOffset += 1
        } label: {
            Image(systemName: "chevron.right")
                .frame(width: 20, height: 20)
        }
        .accessibilityLabel("Next period")
        .help("Next")
    }

}

private struct DashboardPeriodControls: View {
    let accessibilityName: String
    let options: [DashboardPeriod]
    let pickerWidth: CGFloat
    @Binding var range: DashboardPeriod
    @Binding var periodOffset: Int

    var body: some View {
        HStack(spacing: DashboardAnalyticsLayout.periodControlSpacing) {
            WorkSegmentedPicker(
                accessibilityName: accessibilityName,
                selection: $range,
                options: options,
                title: { $0.title },
                height: 30
            )
            .frame(width: pickerWidth, alignment: .trailing)

            DashboardPeriodNavigation(periodOffset: $periodOffset)
        }
        .frame(
            width: DashboardAnalyticsLayout.trailingPeriodControlsWidth,
            alignment: .trailing
        )
    }
}

private struct AnalyticsEmptyState: View {
    let systemImage: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
    }
}

private func analyticsHeader(
    title: String,
    subtitle: String,
    trailing: String
) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Spacer(minLength: 8)

        Text(trailing)
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}
