import Foundation

enum SessionTimeAnchor: String, CaseIterable, Identifiable {
    case start = "Start"
    case end = "End"

    var id: String { rawValue }
}

struct WorkSegment: Codable, Hashable {
    let startedAt: Date
    let endedAt: Date

    var duration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }

    func duration(
        on day: Date,
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> TimeInterval {
        let interval = WorkdayCalendar.interval(
            for: day,
            startHour: dayStartHour,
            calendar: calendar
        )
        let overlapStart = max(startedAt, interval.start)
        let overlapEnd = min(endedAt, interval.end)
        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }
}

struct WorkSession: Identifiable, Codable, Hashable {
    let id: UUID
    var taskID: UUID?
    var subject: String
    var activityItemID: UUID? = nil
    var activityItemTitle: String? = nil
    var activityItemKind: ActivityItemKind? = nil
    var note: String
    let startedAt: Date
    let endedAt: Date
    let segments: [WorkSegment]

    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    func duration(
        on day: Date,
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> TimeInterval {
        segments.reduce(0) {
            $0 + $1.duration(
                on: day,
                calendar: calendar,
                dayStartHour: dayStartHour
            )
        }
    }
}

struct ActiveWork: Codable, Equatable {
    let id: UUID
    var taskID: UUID?
    var subject: String
    var activityItemID: UUID? = nil
    var activityItemTitle: String? = nil
    var activityItemKind: ActivityItemKind? = nil
    var activityItemOccurrenceKey: String? = nil
    var note: String
    let startedAt: Date
    var completedSegments: [WorkSegment]
    var runningSince: Date?
    var activityMode: ActiveActivityMode? = nil
    var plannedDuration: TimeInterval? = nil
    var pomodoro: PomodoroRuntime? = nil

    var isRunning: Bool {
        runningSince != nil
    }

    var resolvedMode: ActiveActivityMode {
        activityMode ?? .stopwatch
    }

    var pomodoroPhase: PomodoroPhase? {
        guard resolvedMode == .pomodoro else {
            return nil
        }
        return pomodoro?.phase
    }

    var countsAsWork: Bool {
        pomodoroPhase?.countsAsWork ?? true
    }

    var isTimed: Bool {
        guard resolvedMode != .stopwatch,
              let plannedDuration else {
            return false
        }
        return plannedDuration.isFinite && plannedDuration > 0
    }

    var modeTitle: String {
        switch resolvedMode {
        case .stopwatch:
            return "Stopwatch"
        case .timer:
            return "Timer"
        case .pomodoro:
            return pomodoroPhase?.title ?? "Pomodoro"
        }
    }

    func segments(at date: Date) -> [WorkSegment] {
        guard let runningSince else {
            return completedSegments
        }

        return completedSegments + [
            WorkSegment(startedAt: runningSince, endedAt: max(runningSince, date))
        ]
    }

    func elapsed(at date: Date) -> TimeInterval {
        segments(at: date).reduce(0) { $0 + $1.duration }
    }

    func displayedDuration(at date: Date) -> TimeInterval {
        guard isTimed, let plannedDuration else {
            return elapsed(at: date)
        }
        return max(0, plannedDuration - elapsed(at: date))
    }

    func progress(at date: Date) -> Double? {
        guard isTimed, let plannedDuration else {
            return nil
        }
        return min(1, max(0, elapsed(at: date) / plannedDuration))
    }

    func remainingDuration(at date: Date) -> TimeInterval? {
        guard isTimed, let plannedDuration else {
            return nil
        }
        return max(0, plannedDuration - elapsed(at: date))
    }

    func expectedCompletionDate() -> Date? {
        guard isTimed,
              let plannedDuration,
              let runningSince else {
            return nil
        }
        let completedDuration = completedSegments.reduce(0) {
            $0 + $1.duration
        }
        let remaining = max(0, plannedDuration - completedDuration)
        return runningSince.addingTimeInterval(remaining)
    }

    func recordedSegments(at date: Date) -> [WorkSegment] {
        countsAsWork ? segments(at: date) : []
    }

    func recordedElapsed(at date: Date) -> TimeInterval {
        recordedSegments(at: date).reduce(0) { $0 + $1.duration }
    }

    func recordedDuration(
        on day: Date,
        at date: Date,
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> TimeInterval {
        recordedSegments(at: date).reduce(0) {
            $0 + $1.duration(
                on: day,
                calendar: calendar,
                dayStartHour: dayStartHour
            )
        }
    }

    func duration(
        on day: Date,
        at date: Date,
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> TimeInterval {
        segments(at: date).reduce(0) {
            $0 + $1.duration(
                on: day,
                calendar: calendar,
                dayStartHour: dayStartHour
            )
        }
    }

    mutating func pause(at date: Date) {
        guard let runningSince else {
            return
        }

        if date > runningSince {
            completedSegments.append(
                WorkSegment(startedAt: runningSince, endedAt: date)
            )
        }
        self.runningSince = nil
    }

    mutating func resume(at date: Date) {
        guard runningSince == nil else {
            return
        }
        runningSince = date
    }

    mutating func finish(at date: Date) -> WorkSession {
        pause(at: date)
        return WorkSession(
            id: id,
            taskID: taskID,
            subject: subject,
            activityItemID: activityItemID,
            activityItemTitle: activityItemTitle,
            activityItemKind: activityItemKind,
            note: note,
            startedAt: startedAt,
            endedAt: date,
            segments: completedSegments
        )
    }
}
