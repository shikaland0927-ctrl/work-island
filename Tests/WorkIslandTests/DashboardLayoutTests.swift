import AppKit
import SwiftUI
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

    func testActivitiesContentKeepsItsMarginAndWidthCap() {
        XCTAssertEqual(
            ActivitiesPageLayout.newActivityPlaceholder,
            "e.g. Thesis, Client work"
        )
        XCTAssertEqual(MainPageLayout.contentInset, 28)
        XCTAssertEqual(MainPageLayout.standardMaximumContentWidth, 900)
        XCTAssertEqual(MainPageLayout.dashboardMaximumContentWidth, 1_060)
        XCTAssertEqual(
            ActivitiesPageLayout.contentMargin,
            MainPageLayout.contentInset
        )
        XCTAssertEqual(
            ActivitiesPageLayout.maximumContentWidth
                + ActivitiesPageLayout.reservedVerticalScrollerWidth,
            MainPageLayout.standardMaximumContentWidth
        )
        XCTAssertEqual(ActivitiesPageLayout.reservedVerticalScrollerWidth, 17)
        XCTAssertEqual(ActivitiesPageLayout.nativeListLeadingInset, 8)
        XCTAssertEqual(ActivitiesPageLayout.nativeListTrailingInset, 9)
        XCTAssertEqual(
            ActivitiesPageLayout.appliedLeadingContentMargin
                + ActivitiesPageLayout.nativeListLeadingInset,
            MainPageLayout.contentInset
        )
        XCTAssertEqual(
            ActivitiesPageLayout.appliedTrailingContentMargin
                + ActivitiesPageLayout.nativeListTrailingInset,
            MainPageLayout.contentInset
        )
        XCTAssertFalse(ActivitiesPageLayout.autohidesVerticalScroller)
    }

    @MainActor
    func testRenderedActivitiesRowMatchesStandardPageEdges() throws {
        for containerWidth: CGFloat in [800, 1_200] {
            let frames = try renderedAlignmentFrames(
                containerWidth: containerWidth
            )

            XCTAssertEqual(
                frames.activities.minX,
                frames.standard.minX,
                accuracy: 0.5,
                "Leading edge at width \(containerWidth)"
            )
            XCTAssertEqual(
                frames.activities.maxX,
                frames.standard.maxX,
                accuracy: 0.5,
                "Trailing edge at width \(containerWidth)"
            )
            XCTAssertEqual(
                frames.activities.maxY,
                frames.standard.maxY,
                accuracy: 0.5,
                "Top edge at width \(containerWidth)"
            )
        }
    }

    @MainActor
    private func renderedAlignmentFrames(
        containerWidth: CGFloat
    ) throws -> (standard: CGRect, activities: CGRect) {
        let standardRecorder = RenderedFrameRecorder()
        let activitiesRecorder = RenderedFrameRecorder()
        let containerHeight: CGFloat = 420

        let standardRoot = MainPageScrollContainer(
            maximumContentWidth: MainPageLayout.standardMaximumContentWidth
        ) {
            renderedAlignmentContent(recorder: standardRecorder)
        }
        .frame(width: containerWidth, height: containerHeight)

        let activitiesRoot = List {
            ActivitiesAlignedRow {
                renderedAlignmentContent(recorder: activitiesRecorder)
            }
            .background(ActivitiesScrollViewConfigurator())
            .listRowInsets(
                EdgeInsets(
                    top: ActivitiesPageLayout.contentMargin,
                    leading: 0,
                    bottom: 0,
                    trailing: 0
                )
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(width: containerWidth, height: containerHeight)

        let standardFrame = try renderFrame(
            root: standardRoot,
            recorder: standardRecorder,
            containerWidth: containerWidth,
            containerHeight: containerHeight
        )
        let activitiesFrame = try renderFrame(
            root: activitiesRoot,
            recorder: activitiesRecorder,
            containerWidth: containerWidth,
            containerHeight: containerHeight
        )

        return (standard: standardFrame, activities: activitiesFrame)
    }

    @MainActor
    private func renderFrame<Content: View>(
        root: Content,
        recorder: RenderedFrameRecorder,
        containerWidth: CGFloat,
        containerHeight: CGFloat
    ) throws -> CGRect {
        let hostingView = NSHostingView(rootView: root)
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: containerWidth,
            height: containerHeight
        )
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView

        let deadline = Date().addingTimeInterval(0.3)
        repeat {
            hostingView.layoutSubtreeIfNeeded()
            _ = RunLoop.main.run(
                mode: .default,
                before: Date().addingTimeInterval(0.01)
            )
        } while Date() < deadline

        return try XCTUnwrap(recorder.frame)
    }

    private func renderedAlignmentContent(
        recorder: RenderedFrameRecorder
    ) -> some View {
        VStack(spacing: 0) {
            RenderedFrameProbe(recorder: recorder)
                .frame(maxWidth: .infinity)
                .frame(height: 80)

            Color.clear.frame(height: 500)
        }
        .frame(maxWidth: .infinity)
    }

    func testClassicWindowKeepsTheExistingCardGeometryAndSmoothSelection() {
        XCTAssertEqual(WorkAppearanceStyle.cardCornerRadius, 20)
        XCTAssertEqual(WorkAppearanceStyle.cardBorderWidth, 1)
        XCTAssertEqual(WorkSegmentedPickerMotion.response, 0.28)
        XCTAssertEqual(WorkSegmentedPickerMotion.dampingFraction, 0.86)
        XCTAssertGreaterThan(WorkSegmentedPickerStyle.selectedFillOpacity, 0)
        XCTAssertGreaterThan(WorkSegmentedPickerStyle.selectedStrokeOpacity, 0)
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
        XCTAssertEqual(DurationPickerLayout.contentWidth, 186)
        XCTAssertNotEqual(
            DurationPickerLayout.triggerWidth,
            SessionDurationLayout.width
        )
    }

    func testSettingsUsesOneTrailingWidthForRemainingMenus() {
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
        XCTAssertEqual(DashboardAnalyticsLayout.navigationWidth, 44)
        XCTAssertLessThan(
            DashboardAnalyticsLayout.graphPickerWidth,
            DashboardAnalyticsLayout.distributionPickerWidth
        )
        XCTAssertEqual(
            DashboardAnalyticsLayout.distributionLegendActivityMaximumWidth,
            180
        )
        XCTAssertEqual(
            DashboardAnalyticsLayout.distributionLegendColumnSpacing,
            16
        )
    }
}

private final class RenderedFrameRecorder {
    var frame: CGRect?
}

private struct RenderedFrameProbe: NSViewRepresentable {
    let recorder: RenderedFrameRecorder

    func makeNSView(context: Context) -> RenderedFrameProbeView {
        RenderedFrameProbeView(recorder: recorder)
    }

    func updateNSView(_ view: RenderedFrameProbeView, context: Context) {
        view.reportFrame()
    }
}

private final class RenderedFrameProbeView: NSView {
    let recorder: RenderedFrameRecorder

    init(recorder: RenderedFrameRecorder) {
        self.recorder = recorder
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportFrame()
    }

    override func layout() {
        super.layout()
        reportFrame()
    }

    func reportFrame() {
        guard window != nil else {
            return
        }
        recorder.frame = convert(bounds, to: nil)
    }
}
