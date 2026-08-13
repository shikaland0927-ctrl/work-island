import XCTest
@testable import WorkIsland

final class AppPreferencesTests: XCTestCase {
    func testFreshInstallCompletesOnboardingThenShowsNotchIntroductionOnce() throws {
        let defaults = try temporaryDefaults()
        let preferences = AppPreferences(defaults: defaults)

        preferences.prepareForLaunch(hadExistingData: false)

        XCTAssertTrue(preferences.isPrepared)
        XCTAssertTrue(preferences.needsOnboarding)
        XCTAssertFalse(preferences.showsNotchIntroduction)

        preferences.completeOnboarding()

        XCTAssertFalse(preferences.needsOnboarding)
        XCTAssertTrue(preferences.showsNotchIntroduction)

        preferences.completeNotchIntroduction()
        let restored = AppPreferences(defaults: defaults)
        restored.prepareForLaunch(hadExistingData: false)

        XCTAssertFalse(restored.needsOnboarding)
        XCTAssertFalse(restored.showsNotchIntroduction)
    }

    func testExistingDataSkipsFirstRunUIWithoutChangingUserData() throws {
        let defaults = try temporaryDefaults()
        let preferences = AppPreferences(defaults: defaults)

        preferences.prepareForLaunch(hadExistingData: true)

        XCTAssertTrue(preferences.isPrepared)
        XCTAssertFalse(preferences.needsOnboarding)
        XCTAssertFalse(preferences.showsNotchIntroduction)
    }

    func testDashboardAndNotchPreferencesPersist() throws {
        let defaults = try temporaryDefaults()
        let preferences = AppPreferences(defaults: defaults)

        preferences.appearance = .liquidGlass
        preferences.notchOpenMode = .singleClick
        preferences.recordingMode = .pomodoro
        preferences.heatmapTint = .green
        preferences.setDayStartHour(4)
        preferences.setTimerDuration(hours: 1, minutes: 35)
        preferences.setManualDuration(hours: 2, minutes: 10)
        preferences.manualTimeAnchor = .start
        preferences.setPomodoroConfiguration(
            focusMinutes: 40,
            shortBreakMinutes: 8,
            longBreakMinutes: 20,
            sessionsBeforeLongBreak: 3
        )
        preferences.completionRevealMode = .untilClosed
        preferences.showsCompactProgress = false
        preferences.setDashboardCard(.heatmap, isVisible: false)
        preferences.moveDashboardCards(
            fromOffsets: IndexSet(integer: 2),
            toOffset: 1
        )

        let restored = AppPreferences(defaults: defaults)

        XCTAssertEqual(restored.appearance, .liquidGlass)
        XCTAssertEqual(restored.notchOpenMode, .singleClick)
        XCTAssertEqual(restored.recordingMode, .pomodoro)
        XCTAssertEqual(restored.heatmapTint, .green)
        XCTAssertEqual(restored.dayStartHour, 4)
        XCTAssertEqual(restored.timerDurationMinutes, 95)
        XCTAssertEqual(restored.manualDurationMinutes, 130)
        XCTAssertEqual(restored.manualTimeAnchor, .start)
        XCTAssertEqual(
            restored.pomodoroConfiguration,
            PomodoroConfiguration(
                focusMinutes: 40,
                shortBreakMinutes: 8,
                longBreakMinutes: 20,
                sessionsBeforeLongBreak: 3
            )
        )
        XCTAssertEqual(restored.completionRevealMode, .untilClosed)
        XCTAssertFalse(restored.showsCompactProgress)
        XCTAssertFalse(restored.isDashboardCardVisible(.heatmap))
        XCTAssertEqual(
            restored.dashboardOrder,
            [.heatmap, .distribution, .graph]
        )

        restored.resetDashboard()

        XCTAssertEqual(restored.dashboardOrder, DashboardCard.defaultOrder)
        XCTAssertTrue(
            DashboardCard.allCases.allSatisfy(
                restored.isDashboardCardVisible
            )
        )
        XCTAssertEqual(restored.heatmapTint, .indigo)
        XCTAssertEqual(restored.dayStartHour, 4)
    }

    func testTimedPreferencesNormalizeInvalidStoredAndNewValues() throws {
        let defaults = try temporaryDefaults()
        defaults.set(0, forKey: "timerDurationMinutes")
        defaults.set(0, forKey: "manualDurationMinutes")
        defaults.set("invalid", forKey: "manualTimeAnchor")
        defaults.set(999, forKey: "pomodoroFocusMinutes")
        defaults.set(0, forKey: "pomodoroShortBreakMinutes")
        defaults.set(999, forKey: "pomodoroLongBreakMinutes")
        defaults.set(0, forKey: "pomodoroSessionsBeforeLongBreak")

        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(preferences.timerDurationMinutes, 1)
        XCTAssertEqual(preferences.manualDurationMinutes, 1)
        XCTAssertEqual(preferences.manualTimeAnchor, .end)
        XCTAssertEqual(preferences.pomodoroConfiguration.focusMinutes, 180)
        XCTAssertEqual(preferences.pomodoroConfiguration.shortBreakMinutes, 1)
        XCTAssertEqual(preferences.pomodoroConfiguration.longBreakMinutes, 120)
        XCTAssertEqual(
            preferences.pomodoroConfiguration.sessionsBeforeLongBreak,
            1
        )

        preferences.setTimerDuration(hours: 99, minutes: 99)
        XCTAssertEqual(
            preferences.timerDurationMinutes,
            AppPreferences.timerDurationRange.upperBound
        )

        preferences.setManualDuration(hours: 99, minutes: 99)
        XCTAssertEqual(
            preferences.manualDurationMinutes,
            AppPreferences.timerDurationRange.upperBound
        )
    }

    func testManualDefaultsTreatNowAsTheEndOfFiveMinutes() throws {
        let preferences = AppPreferences(defaults: try temporaryDefaults())

        XCTAssertEqual(
            preferences.manualDurationMinutes,
            ManualDurationOptions.defaultMinuteStep
        )
        XCTAssertEqual(preferences.manualTimeAnchor, .end)
    }

    func testAppearanceKeepsClassicAsTheSafeDefault() throws {
        let freshDefaults = try temporaryDefaults()
        let freshPreferences = AppPreferences(defaults: freshDefaults)
        XCTAssertEqual(freshPreferences.appearance, .classic)
        XCTAssertNil(freshDefaults.object(forKey: "appearanceStyle"))

        let invalidDefaults = try temporaryDefaults()
        invalidDefaults.set("unknown", forKey: "appearanceStyle")
        XCTAssertEqual(
            AppPreferences(defaults: invalidDefaults).appearance,
            .classic
        )
        XCTAssertEqual(
            WorkIslandAppearance.allCases,
            [.classic, .liquidGlass]
        )
        XCTAssertEqual(WorkIslandAppearance.classic.title, "Classic")
        XCTAssertEqual(
            WorkIslandAppearance.liquidGlass.title,
            "Liquid Glass"
        )
    }

    func testDayStartRejectsInvalidStoredAndNewValues() throws {
        let defaults = try temporaryDefaults()
        defaults.set(27, forKey: "dayStartHour")

        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(preferences.dayStartHour, 0)

        preferences.setDayStartHour(-1)
        XCTAssertEqual(preferences.dayStartHour, 0)

        preferences.setDayStartHour(23)
        XCTAssertEqual(preferences.dayStartHour, 23)
        XCTAssertEqual(
            AppPreferences(defaults: defaults).dayStartHour,
            23
        )
    }

    func testPermanentStatsAndLegacyManualAreRemovedFromDashboardPreferences() throws {
        let defaults = try temporaryDefaults()
        defaults.set(
            ["manual", "distribution", "stats"],
            forKey: "dashboardCardOrder"
        )
        defaults.set(
            ["manual", "heatmap"],
            forKey: "hiddenDashboardCards"
        )

        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(
            preferences.dashboardOrder,
            [.distribution, .heatmap, .graph]
        )
        XCTAssertFalse(preferences.isDashboardCardVisible(.heatmap))
        XCTAssertNil(DashboardCard(rawValue: "stats"))
        XCTAssertEqual(
            DashboardCard.allCases,
            [.heatmap, .graph, .distribution]
        )
    }

    private func temporaryDefaults() throws -> UserDefaults {
        let suiteName = "WorkIslandTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
