import Charts
import SwiftUI

struct HistoryGraphView: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences
    let taskID: UUID?
    let range: HistoryRange

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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryCards(for: points)
                    chartCard(for: points)
                }
                .padding(28)
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Work Graph")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text("Daily work time for \(selectedTaskName) • \(range.title)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryCards(for points: [DailyWorkTotal]) -> some View {
        let total = points.reduce(0) { $0 + $1.duration }
        let average = total / Double(max(1, points.count))
        let best = points.max { $0.duration < $1.duration }

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
                title: "DAILY AVERAGE",
                value: WorkFormatting.readable(average),
                detail: "Across \(points.count) \(points.count == 1 ? "day" : "days")",
                systemImage: "chart.bar.fill"
            )

            HistoryMetricCard(
                title: "BEST DAY",
                value: best?.duration ?? 0 > 0
                    ? WorkFormatting.readable(best?.duration ?? 0)
                    : "—",
                detail: best?.duration ?? 0 > 0
                    ? shortDay(best?.day ?? Date())
                    : "No work yet",
                systemImage: "trophy.fill"
            )
        }
    }

    private func chartCard(for points: [DailyWorkTotal]) -> some View {
        let total = points.reduce(0) { $0 + $1.duration }
        let average = total / Double(max(1, points.count))
        let maximum = points.map(\.duration).max() ?? 0
        let upperBound = max(60, maximum * 1.15)
        let chartWidth = max(
            460,
            CGFloat(points.count) * (points.count > 90 ? 10 : 20)
        )

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Work Time")
                        .font(.title3.weight(.semibold))
                    Text(dateRangeLabel(for: points))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if average > 0 {
                    Label(
                        "Avg \(WorkFormatting.readable(average))",
                        systemImage: "line.diagonal"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }

            if total == 0 {
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("No work recorded in this range.")
                        .font(.subheadline.weight(.medium))
                    Text("Recorded time will appear here as daily bars.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    Chart {
                        ForEach(points) { point in
                            BarMark(
                                x: .value("Day", point.day, unit: .day),
                                y: .value("Duration", point.duration)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.indigo, .blue.opacity(0.72)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(4)
                            .accessibilityLabel(shortDay(point.day))
                            .accessibilityValue(WorkFormatting.readable(point.duration))
                        }

                        if average > 0 {
                            RuleMark(y: .value("Daily average", average))
                                .foregroundStyle(Color.secondary.opacity(0.7))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        }
                    }
                    .chartYScale(domain: 0...upperBound)
                    .chartXAxis {
                        AxisMarks(
                            values: .stride(
                                by: .day,
                                count: axisStride(for: points.count)
                            )
                        ) { value in
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(shortAxisDay(date))
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
                    .frame(width: chartWidth, height: 300)
                }
            }
        }
        .padding(22)
        .workCard()
    }

    private var selectedTaskName: String {
        guard let taskID,
              let task = store.task(id: taskID) else {
            return "all activities"
        }
        return task.name
    }

    private func dateRangeLabel(for points: [DailyWorkTotal]) -> String {
        guard let first = points.first?.day,
              let last = points.last?.day else {
            return range.title
        }
        return "\(shortDate(first)) – \(shortDate(last))"
    }

    private func axisStride(for dayCount: Int) -> Int {
        switch dayCount {
        case 0...14:
            return 1
        case 15...35:
            return 5
        case 36...100:
            return 14
        default:
            return 30
        }
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

    private func shortDay(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .weekday(.abbreviated)
                .locale(Locale(identifier: "en_US"))
        )
    }

    private func shortAxisDay(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
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
