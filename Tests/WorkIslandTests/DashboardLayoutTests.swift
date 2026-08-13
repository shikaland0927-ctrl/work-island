import XCTest
@testable import WorkIsland

final class DashboardLayoutTests: XCTestCase {
    func testHeatmapMetricsNeverRequireHorizontalScrolling() {
        let weekCount = 53

        for availableWidth: CGFloat in [320, 480, 686, 900] {
            let metrics = DashboardHeatmapMetrics.fitting(
                weekCount: weekCount,
                availableWidth: availableWidth
            )

            XCTAssertGreaterThan(metrics.cellSize, 0)
            XCTAssertGreaterThanOrEqual(metrics.spacing, 0)
            XCTAssertLessThanOrEqual(
                metrics.gridWidth(weekCount: weekCount),
                availableWidth + 0.001
            )
        }
    }

    func testHeatmapMetricsKeepPreferredSizeWhenItFits() {
        let weekCount = 53
        let preferredWidth = CGFloat(weekCount) * DashboardHeatmapMetrics.preferredCellSize
            + CGFloat(weekCount - 1) * DashboardHeatmapMetrics.preferredSpacing

        let metrics = DashboardHeatmapMetrics.fitting(
            weekCount: weekCount,
            availableWidth: preferredWidth + 100
        )

        XCTAssertEqual(metrics.cellSize, 10, accuracy: 0.001)
        XCTAssertEqual(metrics.spacing, 3, accuracy: 0.001)
    }

    func testMainWindowKeepsDashboardCardsReadable() {
        XCTAssertEqual(MainWindowLayout.minimumWidth, 840)
        XCTAssertEqual(MainWindowLayout.minimumHeight, 540)
        XCTAssertLessThan(MainWindowLayout.minimumWidth, MainWindowLayout.defaultWidth)
        XCTAssertLessThan(MainWindowLayout.minimumHeight, MainWindowLayout.defaultHeight)
    }

    func testLiquidGlassKeepsTheExistingCardGeometry() {
        XCTAssertEqual(WorkAppearanceStyle.cardCornerRadius, 20)
        XCTAssertEqual(WorkAppearanceStyle.cardBorderWidth, 1)
        XCTAssertEqual(WorkAppearanceStyle.innerHighlightWidth, 0.5)
        XCTAssertGreaterThan(WorkAppearanceStyle.cardShadowRadius, 0)
        XCTAssertGreaterThan(WorkAppearanceStyle.cardShadowY, 0)
    }

    func testHistoryEditorKeepsDurationBesideTimestampWithAVisibleGroupGap() {
        XCTAssertGreaterThan(
            SessionInputLayout.groupSpacing,
            SessionInputLayout.fieldSpacing
        )
        XCTAssertEqual(SessionInputLayout.timestampWidth, 364)
        XCTAssertEqual(SessionDurationLayout.minutesWidth, 76)
        XCTAssertEqual(SessionDurationLayout.minuteStepSpacing, 8)
        XCTAssertEqual(SessionInputLayout.durationWidth, 202)
        XCTAssertEqual(SessionInputLayout.combinedWidth, 594)
        XCTAssertLessThan(SessionInputLayout.combinedWidth, 600)
    }

    func testNotchAndWindowUsePurposeBuiltDurationEditors() {
        XCTAssertEqual(DurationPickerLayout.columnWidth, 88)
        XCTAssertEqual(DurationPickerLayout.columnHeight, 168)
        XCTAssertEqual(DurationPickerLayout.contentWidth, 284)
        XCTAssertNotEqual(
            DurationPickerLayout.triggerWidth,
            SessionDurationLayout.width
        )
    }

    func testSettingsUsesOneTrailingWidthForAlertAndHeatmapColor() {
        XCTAssertEqual(SettingsControlLayout.standardTrailingWidth, 220)
        XCTAssertGreaterThan(
            SettingsControlLayout.notchOpenWidth,
            SettingsControlLayout.standardTrailingWidth
        )
        XCTAssertGreaterThan(
            SettingsControlLayout.pomodoroWidth,
            SettingsControlLayout.standardTrailingWidth
        )
        XCTAssertEqual(SettingsControlLayout.pomodoroFieldWidth, 76)
        XCTAssertEqual(
            SettingsControlLayout.pomodoroMenuWidth,
            SettingsControlLayout.pomodoroFieldWidth
        )
        XCTAssertEqual(SettingsControlLayout.pomodoroMenuHeight, 24)
        XCTAssertEqual(SettingsControlLayout.pomodoroSpacing, 10)
        XCTAssertEqual(
            SettingsControlLayout.pomodoroWidth,
            SettingsControlLayout.pomodoroFieldWidth * 4
                + SettingsControlLayout.pomodoroSpacing * 3
        )
    }

    func testDashboardSettingsListFitsThreeRowsWithBalancedInsets() {
        XCTAssertEqual(SettingsControlLayout.dashboardListHeight, 134)
        XCTAssertEqual(SettingsControlLayout.dashboardListCornerRadius, 10)
        XCTAssertLessThan(SettingsControlLayout.dashboardListHeight, 150)
    }

    func testPermanentStatsFitsBesideTotalAtMinimumWindowWidth() {
        XCTAssertEqual(DashboardSummaryLayout.cardSpacing, 20)
        XCTAssertEqual(DashboardSummaryLayout.totalCardWidth, 230)
        XCTAssertEqual(DashboardSummaryLayout.cardMinHeight, 194)
        XCTAssertEqual(DashboardSummaryLayout.metricSpacing, 8)
        XCTAssertLessThan(
            DashboardSummaryLayout.totalCardWidth
                + DashboardSummaryLayout.cardSpacing,
            MainWindowLayout.minimumWidth / 2
        )
    }

    func testGraphAndDistributionPeriodControlsShareMonthRightEdge() {
        XCTAssertEqual(
            DashboardAnalyticsLayout.trailingPeriodControlsWidth,
            308,
            accuracy: 0.001
        )
        XCTAssertEqual(
            DashboardAnalyticsLayout.pickerTrailingInset,
            58,
            accuracy: 0.001
        )
        XCTAssertLessThan(
            DashboardAnalyticsLayout.graphPickerWidth,
            DashboardAnalyticsLayout.distributionPickerWidth
        )
    }
}
