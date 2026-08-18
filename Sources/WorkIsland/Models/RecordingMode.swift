import Foundation

enum ActivityRecordingMode: String, CaseIterable, Identifiable {
    case stopwatch
    case manual
    case timer
    case pomodoro

    var id: String { rawValue }

    static let notchCases: [Self] = [
        .stopwatch,
        .manual,
        .timer,
        .pomodoro
    ]

    var notchMode: Self {
        self
    }

    var title: String {
        switch self {
        case .stopwatch:
            return "Stopwatch"
        case .manual:
            return "Manual"
        case .timer:
            return "Timer"
        case .pomodoro:
            return "Pomodoro"
        }
    }

    var systemImage: String {
        switch self {
        case .stopwatch:
            return "stopwatch"
        case .manual:
            return "square.and.pencil"
        case .timer:
            return "timer"
        case .pomodoro:
            return "repeat.circle"
        }
    }

    var activeMode: ActiveActivityMode? {
        switch self {
        case .stopwatch:
            return .stopwatch
        case .timer:
            return .timer
        case .pomodoro:
            return .pomodoro
        case .manual:
            return nil
        }
    }
}

enum ActiveActivityMode: String, Codable, Equatable {
    case stopwatch
    case timer
    case pomodoro
}

enum PomodoroPhase: String, Codable, Equatable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus:
            return "Focus"
        case .shortBreak:
            return "Break"
        case .longBreak:
            return "Long Break"
        }
    }

    var countsAsWork: Bool {
        self == .focus
    }
}

struct PomodoroConfiguration: Codable, Equatable {
    static let focusRange = 1...180
    static let shortBreakRange = 1...60
    static let longBreakRange = 1...120
    static let sessionsRange = 1...12
    static let standard = PomodoroConfiguration(
        focusMinutes: 25,
        shortBreakMinutes: 5,
        longBreakMinutes: 15,
        sessionsBeforeLongBreak: 4
    )

    let focusMinutes: Int
    let shortBreakMinutes: Int
    let longBreakMinutes: Int
    let sessionsBeforeLongBreak: Int

    init(
        focusMinutes: Int,
        shortBreakMinutes: Int,
        longBreakMinutes: Int,
        sessionsBeforeLongBreak: Int
    ) {
        self.focusMinutes = Self.clamp(
            focusMinutes,
            to: Self.focusRange
        )
        self.shortBreakMinutes = Self.clamp(
            shortBreakMinutes,
            to: Self.shortBreakRange
        )
        self.longBreakMinutes = Self.clamp(
            longBreakMinutes,
            to: Self.longBreakRange
        )
        self.sessionsBeforeLongBreak = Self.clamp(
            sessionsBeforeLongBreak,
            to: Self.sessionsRange
        )
    }

    func duration(for phase: PomodoroPhase) -> TimeInterval {
        let minutes: Int
        switch phase {
        case .focus:
            minutes = focusMinutes
        case .shortBreak:
            minutes = shortBreakMinutes
        case .longBreak:
            minutes = longBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }

    private static func clamp(
        _ value: Int,
        to range: ClosedRange<Int>
    ) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }
}

struct PomodoroRuntime: Codable, Equatable {
    var phase: PomodoroPhase
    var completedFocusSessions: Int
    let configuration: PomodoroConfiguration

    init(
        phase: PomodoroPhase = .focus,
        completedFocusSessions: Int = 0,
        configuration: PomodoroConfiguration
    ) {
        self.phase = phase
        self.completedFocusSessions = max(0, completedFocusSessions)
        self.configuration = configuration
    }

    mutating func advance() -> PomodoroPhase {
        switch phase {
        case .focus:
            completedFocusSessions += 1
            if completedFocusSessions
                .isMultiple(of: configuration.sessionsBeforeLongBreak) {
                phase = .longBreak
            } else {
                phase = .shortBreak
            }
        case .shortBreak, .longBreak:
            phase = .focus
        }
        return phase
    }
}

enum CompletionRevealMode: String, CaseIterable, Identifiable {
    case fiveSeconds
    case untilClosed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveSeconds:
            return "Temporary"
        case .untilClosed:
            return "Persistent"
        }
    }

    var timeout: TimeInterval? {
        switch self {
        case .untilClosed:
            return nil
        case .fiveSeconds:
            return 5
        }
    }
}

struct TimedActivityCompletion: Identifiable, Equatable {
    enum Kind: Equatable {
        case timer
        case focus(next: PomodoroPhase)
        case breakTime(next: PomodoroPhase)
    }

    let id = UUID()
    let kind: Kind
    let activityTitle: String
    let completedAt: Date

    var title: String {
        switch kind {
        case .timer:
            return "Timer Complete"
        case .focus:
            return "Focus Complete"
        case .breakTime:
            return "Break Complete"
        }
    }

    var nextTitle: String? {
        switch kind {
        case .timer:
            return nil
        case let .focus(next), let .breakTime(next):
            return next.title
        }
    }
}
