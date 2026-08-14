import SwiftUI

enum WorkIslandAppearance: String, CaseIterable, Identifiable {
    case classic
    case liquidGlass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:
            return "Classic"
        case .liquidGlass:
            return "Liquid Glass"
        }
    }
}

enum NotchOpenMode: String, CaseIterable, Identifiable {
    case hover
    case singleClick
    case doubleClick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hover:
            return "Hover"
        case .singleClick:
            return "Single Click"
        case .doubleClick:
            return "Double Click"
        }
    }
}

enum DashboardCard: String, CaseIterable, Identifiable {
    case heatmap
    case graph
    case distribution

    static let defaultOrder: [DashboardCard] = [
        .heatmap,
        .graph,
        .distribution
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heatmap:
            return "Heatmap"
        case .graph:
            return "Graph"
        case .distribution:
            return "Distribution"
        }
    }

    var systemImage: String {
        switch self {
        case .heatmap:
            return "square.grid.3x3.fill"
        case .graph:
            return "chart.bar.xaxis"
        case .distribution:
            return "chart.pie.fill"
        }
    }
}

enum HeatmapTint: String, CaseIterable, Identifiable {
    case indigo
    case blue
    case cyan
    case green
    case orange
    case pink

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .indigo:
            return .indigo
        case .blue:
            return .blue
        case .cyan:
            return .cyan
        case .green:
            return .green
        case .orange:
            return .orange
        case .pink:
            return .pink
        }
    }
}

struct NotchGlassConfiguration: Equatable {
    static let fixedFrost = 6
    static let fixedBezelDepth = 0
    static let blurRange = 0...12
    static let refractiveIndexHundredthsRange = 100...300

    static let standard = NotchGlassConfiguration(
        blur: 2,
        refractiveIndexHundredths: 150
    )

    let blur: Int
    let refractiveIndexHundredths: Int

    var frost: Int {
        Self.fixedFrost
    }

    var bezelDepth: Int {
        Self.fixedBezelDepth
    }

    var refractiveIndex: Double {
        Double(refractiveIndexHundredths) / 100
    }

    init(
        blur: Int,
        refractiveIndexHundredths: Int
    ) {
        self.blur = Self.normalized(blur, in: Self.blurRange)
        self.refractiveIndexHundredths = Self.normalized(
            refractiveIndexHundredths,
            in: Self.refractiveIndexHundredthsRange
        )
    }

    private static func normalized(
        _ value: Int,
        in range: ClosedRange<Int>
    ) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }
}

final class AppPreferences: ObservableObject {
    static let timerDurationRange = 1...(24 * 60 + 59)

    private enum Key {
        static let completedOnboarding = "completedOnboardingV1"
        static let completedNotchIntroduction = "completedNotchIntroductionV1"
        static let notchOpenMode = "notchOpenMode"
        static let dashboardOrder = "dashboardCardOrder"
        static let hiddenDashboardCards = "hiddenDashboardCards"
        static let heatmapTint = "heatmapTint"
        static let dayStartHour = "dayStartHour"
        static let recordingMode = "activityRecordingMode"
        static let timerDurationMinutes = "timerDurationMinutes"
        static let manualDurationMinutes = "manualDurationMinutes"
        static let manualTimeAnchor = "manualTimeAnchor"
        static let pomodoroFocusMinutes = "pomodoroFocusMinutes"
        static let pomodoroShortBreakMinutes = "pomodoroShortBreakMinutes"
        static let pomodoroLongBreakMinutes = "pomodoroLongBreakMinutes"
        static let pomodoroSessions = "pomodoroSessionsBeforeLongBreak"
        static let completionRevealMode = "completionRevealMode"
        static let showsCompactProgress = "showsCompactTimerProgress"
        static let appearance = "appearanceStyle"
        static let notchGlassBlur = "notchGlassBlur"
        static let notchGlassRefractiveIndexHundredths =
            "notchGlassRefractiveIndexHundredths"
    }

    @Published private(set) var isPrepared = false
    @Published private(set) var needsOnboarding = false
    @Published private(set) var showsNotchIntroduction = false
    @Published private(set) var isNotchGlassPreviewRequested = false
    @Published private(set) var notchGlassPreviewRequestRevision = 0

    @Published var appearance: WorkIslandAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Key.appearance)
        }
    }

    @Published private(set) var notchGlassConfiguration: NotchGlassConfiguration {
        didSet {
            defaults.set(
                notchGlassConfiguration.blur,
                forKey: Key.notchGlassBlur
            )
            defaults.set(
                notchGlassConfiguration.refractiveIndexHundredths,
                forKey: Key.notchGlassRefractiveIndexHundredths
            )
        }
    }

    @Published var notchOpenMode: NotchOpenMode {
        didSet {
            defaults.set(notchOpenMode.rawValue, forKey: Key.notchOpenMode)
        }
    }

    @Published var recordingMode: ActivityRecordingMode {
        didSet {
            defaults.set(recordingMode.rawValue, forKey: Key.recordingMode)
        }
    }

    @Published private(set) var dashboardOrder: [DashboardCard] {
        didSet {
            defaults.set(
                dashboardOrder.map(\.rawValue),
                forKey: Key.dashboardOrder
            )
        }
    }

    @Published private(set) var hiddenDashboardCards: Set<DashboardCard> {
        didSet {
            defaults.set(
                hiddenDashboardCards.map(\.rawValue).sorted(),
                forKey: Key.hiddenDashboardCards
            )
        }
    }

    @Published var heatmapTint: HeatmapTint {
        didSet {
            defaults.set(heatmapTint.rawValue, forKey: Key.heatmapTint)
        }
    }

    @Published private(set) var dayStartHour: Int {
        didSet {
            defaults.set(dayStartHour, forKey: Key.dayStartHour)
        }
    }

    @Published private(set) var timerDurationMinutes: Int {
        didSet {
            defaults.set(
                timerDurationMinutes,
                forKey: Key.timerDurationMinutes
            )
        }
    }

    @Published private(set) var manualDurationMinutes: Int {
        didSet {
            defaults.set(
                manualDurationMinutes,
                forKey: Key.manualDurationMinutes
            )
        }
    }

    @Published var manualTimeAnchor: SessionTimeAnchor {
        didSet {
            defaults.set(
                manualTimeAnchor.rawValue,
                forKey: Key.manualTimeAnchor
            )
        }
    }

    @Published private(set) var pomodoroConfiguration: PomodoroConfiguration {
        didSet {
            defaults.set(
                pomodoroConfiguration.focusMinutes,
                forKey: Key.pomodoroFocusMinutes
            )
            defaults.set(
                pomodoroConfiguration.shortBreakMinutes,
                forKey: Key.pomodoroShortBreakMinutes
            )
            defaults.set(
                pomodoroConfiguration.longBreakMinutes,
                forKey: Key.pomodoroLongBreakMinutes
            )
            defaults.set(
                pomodoroConfiguration.sessionsBeforeLongBreak,
                forKey: Key.pomodoroSessions
            )
        }
    }

    @Published var completionRevealMode: CompletionRevealMode {
        didSet {
            defaults.set(
                completionRevealMode.rawValue,
                forKey: Key.completionRevealMode
            )
        }
    }

    @Published var showsCompactProgress: Bool {
        didSet {
            defaults.set(
                showsCompactProgress,
                forKey: Key.showsCompactProgress
            )
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = WorkIslandAppearance(
            rawValue: defaults.string(forKey: Key.appearance) ?? ""
        ) ?? .classic
        notchGlassConfiguration = NotchGlassConfiguration(
            blur: defaults.object(forKey: Key.notchGlassBlur) as? Int
                ?? NotchGlassConfiguration.standard.blur,
            refractiveIndexHundredths: defaults.object(
                forKey: Key.notchGlassRefractiveIndexHundredths
            ) as? Int
                ?? NotchGlassConfiguration.standard.refractiveIndexHundredths
        )
        notchOpenMode = NotchOpenMode(
            rawValue: defaults.string(forKey: Key.notchOpenMode) ?? ""
        ) ?? .hover
        recordingMode = ActivityRecordingMode(
            rawValue: defaults.string(forKey: Key.recordingMode) ?? ""
        ) ?? .stopwatch
        dashboardOrder = Self.normalizedDashboardOrder(
            defaults.stringArray(forKey: Key.dashboardOrder) ?? []
        )
        hiddenDashboardCards = Set(
            (defaults.stringArray(forKey: Key.hiddenDashboardCards) ?? [])
                .compactMap(DashboardCard.init(rawValue:))
        )
        heatmapTint = HeatmapTint(
            rawValue: defaults.string(forKey: Key.heatmapTint) ?? ""
        ) ?? .indigo
        dayStartHour = WorkdayCalendar.normalizedStartHour(
            defaults.object(forKey: Key.dayStartHour) as? Int ?? 0
        )
        timerDurationMinutes = Self.normalizedTimerDuration(
            defaults.object(forKey: Key.timerDurationMinutes) as? Int ?? 25
        )
        manualDurationMinutes = Self.normalizedTimerDuration(
            defaults.object(forKey: Key.manualDurationMinutes) as? Int
                ?? ManualDurationOptions.defaultMinuteStep
        )
        manualTimeAnchor = SessionTimeAnchor(
            rawValue: defaults.string(forKey: Key.manualTimeAnchor) ?? ""
        ) ?? .end
        pomodoroConfiguration = PomodoroConfiguration(
            focusMinutes: defaults.object(
                forKey: Key.pomodoroFocusMinutes
            ) as? Int ?? PomodoroConfiguration.standard.focusMinutes,
            shortBreakMinutes: defaults.object(
                forKey: Key.pomodoroShortBreakMinutes
            ) as? Int ?? PomodoroConfiguration.standard.shortBreakMinutes,
            longBreakMinutes: defaults.object(
                forKey: Key.pomodoroLongBreakMinutes
            ) as? Int ?? PomodoroConfiguration.standard.longBreakMinutes,
            sessionsBeforeLongBreak: defaults.object(
                forKey: Key.pomodoroSessions
            ) as? Int ?? PomodoroConfiguration.standard.sessionsBeforeLongBreak
        )
        completionRevealMode = CompletionRevealMode(
            rawValue: defaults.string(forKey: Key.completionRevealMode) ?? ""
        ) ?? .fiveSeconds
        if defaults.object(forKey: Key.showsCompactProgress) == nil {
            showsCompactProgress = true
        } else {
            showsCompactProgress = defaults.bool(
                forKey: Key.showsCompactProgress
            )
        }
    }

    func prepareForLaunch(hadExistingData: Bool) {
        guard !isPrepared else {
            return
        }

        if defaults.object(forKey: Key.completedOnboarding) == nil,
           hadExistingData {
            defaults.set(true, forKey: Key.completedOnboarding)
            defaults.set(true, forKey: Key.completedNotchIntroduction)
        }

        needsOnboarding = !defaults.bool(forKey: Key.completedOnboarding)
        showsNotchIntroduction = !needsOnboarding
            && !defaults.bool(forKey: Key.completedNotchIntroduction)
        isPrepared = true
    }

    func completeOnboarding() {
        defaults.set(true, forKey: Key.completedOnboarding)
        defaults.set(false, forKey: Key.completedNotchIntroduction)
        needsOnboarding = false
        showsNotchIntroduction = true
    }

    func completeNotchIntroduction() {
        defaults.set(true, forKey: Key.completedNotchIntroduction)
        showsNotchIntroduction = false
    }

    func isDashboardCardVisible(_ card: DashboardCard) -> Bool {
        !hiddenDashboardCards.contains(card)
    }

    func setDashboardCard(_ card: DashboardCard, isVisible: Bool) {
        if isVisible {
            hiddenDashboardCards.remove(card)
        } else {
            hiddenDashboardCards.insert(card)
        }
    }

    func moveDashboardCards(
        fromOffsets sourceOffsets: IndexSet,
        toOffset destination: Int
    ) {
        guard sourceOffsets.allSatisfy(dashboardOrder.indices.contains),
              (0...dashboardOrder.count).contains(destination) else {
            return
        }

        dashboardOrder.move(
            fromOffsets: sourceOffsets,
            toOffset: destination
        )
    }

    func resetDashboard() {
        dashboardOrder = DashboardCard.defaultOrder
        hiddenDashboardCards = []
        heatmapTint = .indigo
    }

    func setNotchGlassConfiguration(
        blur: Int? = nil,
        refractiveIndexHundredths: Int? = nil
    ) {
        notchGlassConfiguration = NotchGlassConfiguration(
            blur: blur ?? notchGlassConfiguration.blur,
            refractiveIndexHundredths: refractiveIndexHundredths
                ?? notchGlassConfiguration.refractiveIndexHundredths
        )
    }

    func resetNotchGlassConfiguration() {
        notchGlassConfiguration = .standard
    }

    func beginNotchGlassPreview() {
        notchGlassPreviewRequestRevision &+= 1
        isNotchGlassPreviewRequested = true
    }

    func endNotchGlassPreview() {
        isNotchGlassPreviewRequested = false
    }

    func setDayStartHour(_ hour: Int) {
        dayStartHour = WorkdayCalendar.normalizedStartHour(hour)
    }

    func setTimerDuration(hours: Int, minutes: Int) {
        let total = max(0, hours) * 60 + min(59, max(0, minutes))
        timerDurationMinutes = Self.normalizedTimerDuration(total)
    }

    func setManualDuration(hours: Int, minutes: Int) {
        let total = max(0, hours) * 60 + min(59, max(0, minutes))
        manualDurationMinutes = Self.normalizedTimerDuration(total)
    }

    func setPomodoroConfiguration(
        focusMinutes: Int? = nil,
        shortBreakMinutes: Int? = nil,
        longBreakMinutes: Int? = nil,
        sessionsBeforeLongBreak: Int? = nil
    ) {
        pomodoroConfiguration = PomodoroConfiguration(
            focusMinutes: focusMinutes
                ?? pomodoroConfiguration.focusMinutes,
            shortBreakMinutes: shortBreakMinutes
                ?? pomodoroConfiguration.shortBreakMinutes,
            longBreakMinutes: longBreakMinutes
                ?? pomodoroConfiguration.longBreakMinutes,
            sessionsBeforeLongBreak: sessionsBeforeLongBreak
                ?? pomodoroConfiguration.sessionsBeforeLongBreak
        )
    }

    private static func normalizedTimerDuration(_ minutes: Int) -> Int {
        min(
            timerDurationRange.upperBound,
            max(timerDurationRange.lowerBound, minutes)
        )
    }

    private static func normalizedDashboardOrder(
        _ storedValues: [String]
    ) -> [DashboardCard] {
        var result: [DashboardCard] = []

        for value in storedValues {
            guard let card = DashboardCard(rawValue: value),
                  !result.contains(card) else {
                continue
            }
            result.append(card)
        }

        for card in DashboardCard.defaultOrder where !result.contains(card) {
            result.append(card)
        }

        return result
    }
}

extension Notification.Name {
    static let workIslandNotchDidExpand = Notification.Name(
        "WorkIslandNotchDidExpand"
    )
}
