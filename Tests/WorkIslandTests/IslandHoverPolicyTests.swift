import AppKit
import XCTest
@testable import WorkIsland

final class IslandHoverPolicyTests: XCTestCase {
    func testLeadingOpenWindowControlKeepsTheWindowIcon() {
        XCTAssertEqual(IslandHeaderLayout.openWindowSystemImage, "macwindow")
    }

    func testNotchIncludesManualWithoutTreatingItAsLiveWork() {
        XCTAssertEqual(
            ActivityRecordingMode.notchCases,
            [.stopwatch, .manual, .timer, .pomodoro]
        )
        XCTAssertEqual(ActivityRecordingMode.manual.notchMode, .manual)
        XCTAssertNil(ActivityRecordingMode.manual.activeMode)
    }

    func testNotchDigitalClockUsesReadableWeightInIdleAndActiveStates() {
        XCTAssertEqual(IslandDigitalClockLayout.idleFontSize, 18)
        XCTAssertEqual(IslandDigitalClockLayout.activeFontSize, 27)
        XCTAssertEqual(IslandDigitalClockLayout.fontWeight, .bold)
    }

    func testTimerAndPomodoroUseOneIdleClockAnchor() {
        XCTAssertGreaterThanOrEqual(IslandDigitalClockLayout.idleWidth, 108)
        XCTAssertLessThan(IslandDigitalClockLayout.idleTextHorizontalOffset, 0)
        XCTAssertGreaterThanOrEqual(
            IslandDigitalClockLayout.timerChevronTrailingInset,
            0
        )
    }

    func testExpandedAndCompactProgressPathsBothLeaveTheTopOpen() {
        let rect = CGRect(x: 0, y: 0, width: 460, height: 190)
        let path = OpenNotchProgressShape(cornerRadius: 25).path(in: rect)
        let cgPath = path.cgPath
        var elements: [CGPathElementType] = []
        var points: [CGPoint] = []

        cgPath.applyWithBlock { element in
            elements.append(element.pointee.type)
            if element.pointee.type != .closeSubpath {
                points.append(element.pointee.points[0])
            }
        }

        XCTAssertFalse(elements.contains(.closeSubpath))
        XCTAssertEqual(points.first?.y ?? -1, 1.5, accuracy: 0.001)
        XCTAssertEqual(points.last?.y ?? -1, 1.5, accuracy: 0.001)
        XCTAssertGreaterThan(points.first?.x ?? 0, points.last?.x ?? 0)
    }

    func testClickModesRequireTheirConfiguredClickCount() {
        XCTAssertTrue(
            IslandClickPolicy.shouldExpand(mode: .singleClick, clickCount: 1)
        )
        XCTAssertFalse(
            IslandClickPolicy.shouldExpand(mode: .singleClick, clickCount: 2)
        )
        XCTAssertFalse(
            IslandClickPolicy.shouldExpand(mode: .doubleClick, clickCount: 1)
        )
        XCTAssertTrue(
            IslandClickPolicy.shouldExpand(mode: .doubleClick, clickCount: 2)
        )
        XCTAssertFalse(
            IslandClickPolicy.shouldExpand(mode: .doubleClick, clickCount: 3)
        )
        XCTAssertFalse(
            IslandClickPolicy.shouldExpand(mode: .hover, clickCount: 2)
        )
    }

    private let expandedFrame = NSRect(
        x: 100,
        y: 700,
        width: 500,
        height: 190
    )

    func testPointerInsideFinalExpandedFrameDoesNotCollapse() {
        XCTAssertFalse(
            IslandHoverPolicy.shouldCollapse(
                pointerLocation: NSPoint(x: 350, y: 760),
                expandedFrame: expandedFrame
            )
        )
    }

    func testTransientExitInsideEdgeToleranceDoesNotCollapse() {
        XCTAssertFalse(
            IslandHoverPolicy.shouldCollapse(
                pointerLocation: NSPoint(x: 600.5, y: 760),
                expandedFrame: expandedFrame
            )
        )
    }

    func testPointerOutsideExpandedFrameCollapsesImmediately() {
        XCTAssertTrue(
            IslandHoverPolicy.shouldCollapse(
                pointerLocation: NSPoint(x: 602, y: 760),
                expandedFrame: expandedFrame
            )
        )
    }

    func testActiveMenuKeepsExpandedIslandOpenOutsideItsFrame() {
        XCTAssertFalse(
            IslandHoverPolicy.shouldCollapse(
                pointerLocation: NSPoint(x: 650, y: 760),
                expandedFrame: expandedFrame,
                isInteractionActive: true
            )
        )
    }

    func testExplicitInteractionRemainsActiveUntilNestedTrackingEnds() {
        let presentation = IslandPresentationState()

        presentation.beginInteraction()
        presentation.beginInteraction()
        XCTAssertTrue(presentation.isInteractionActive)

        presentation.endInteraction()
        XCTAssertTrue(presentation.isInteractionActive)

        presentation.endInteraction()
        presentation.endInteraction()
        XCTAssertFalse(presentation.isInteractionActive)
        XCTAssertEqual(presentation.interactionDepth, 0)
    }

    func testCompletionRevealPinsTheIslandUntilItIsDismissed() {
        let presentation = IslandPresentationState()
        let notice = TimedActivityCompletion(
            kind: .timer,
            activityTitle: "Writing",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        presentation.presentCompletion(notice)

        XCTAssertTrue(presentation.isExpanded)
        XCTAssertTrue(presentation.isCompletionRevealPinned)
        XCTAssertEqual(presentation.completionNotice, notice)
        XCTAssertFalse(
            IslandHoverPolicy.shouldCollapse(
                pointerLocation: NSPoint(x: 650, y: 760),
                expandedFrame: expandedFrame,
                isInteractionActive: presentation.isCompletionRevealPinned
            )
        )

        presentation.dismissCompletion()

        XCTAssertFalse(presentation.isCompletionRevealPinned)
        XCTAssertNil(presentation.completionNotice)
    }

    func testNotchGlassPreviewStaysOpenUntilPointerVisitsAndLeaves() {
        let presentation = IslandPresentationState()

        presentation.beginNotchGlassPreview()

        XCTAssertTrue(presentation.isExpanded)
        XCTAssertTrue(presentation.isNotchGlassPreviewPinned)
        XCTAssertFalse(presentation.hasNotchGlassPreviewBeenTouched)
        XCTAssertFalse(
            presentation.dismissNotchGlassPreviewAfterPointerExit()
        )

        presentation.noteNotchGlassPreviewPointerEntered()
        XCTAssertTrue(presentation.hasNotchGlassPreviewBeenTouched)
        XCTAssertTrue(
            presentation.dismissNotchGlassPreviewAfterPointerExit()
        )
        XCTAssertFalse(presentation.isExpanded)
        XCTAssertFalse(presentation.isNotchGlassPreviewPinned)
    }

    func testCompletionRevealOutlivesNotchGlassPreview() {
        let presentation = IslandPresentationState()
        let notice = TimedActivityCompletion(
            kind: .timer,
            activityTitle: "Writing",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        presentation.beginNotchGlassPreview()
        presentation.presentCompletion(notice)
        presentation.endNotchGlassPreview()

        XCTAssertTrue(presentation.isExpanded)
        XCTAssertTrue(presentation.isCompletionRevealPinned)
        XCTAssertFalse(presentation.isNotchGlassPreviewPinned)
    }

    func testEndingAnInactivePreviewDoesNotCollapseNormalExpansion() {
        let presentation = IslandPresentationState()
        presentation.isExpanded = true

        presentation.endNotchGlassPreview()

        XCTAssertTrue(presentation.isExpanded)
        XCTAssertFalse(presentation.isNotchGlassPreviewPinned)
    }

    func testCompletionRevealModesUseTheRequestedLifetime() {
        XCTAssertEqual(
            CompletionRevealMode.allCases,
            [.fiveSeconds, .untilClosed]
        )
        XCTAssertEqual(CompletionRevealMode.fiveSeconds.title, "Temporary")
        XCTAssertEqual(CompletionRevealMode.untilClosed.title, "Persistent")
        XCTAssertNil(CompletionRevealMode.untilClosed.timeout)
        XCTAssertEqual(CompletionRevealMode.fiveSeconds.timeout, 5)
    }

    func testCompletionMotionRingsInSilentBursts() {
        XCTAssertGreaterThan(
            IslandCompletionMotion.cycleDuration,
            IslandCompletionMotion.ringingDuration
        )
        XCTAssertGreaterThan(IslandCompletionMotion.horizontalAmplitude, 0)
        XCTAssertGreaterThan(IslandCompletionMotion.rotationAmplitude, 0)

        let ringingSamples = stride(
            from: 0.0,
            to: IslandCompletionMotion.ringingDuration,
            by: 0.005
        ).map(IslandCompletionMotion.amount(at:))

        XCTAssertGreaterThan(
            ringingSamples.map(abs).max() ?? 0,
            0.8
        )
        XCTAssertLessThanOrEqual(
            ringingSamples.map(abs).max() ?? 0,
            1.001
        )
        XCTAssertEqual(
            IslandCompletionMotion.amount(
                at: IslandCompletionMotion.ringingDuration + 0.1
            ),
            0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandCompletionMotion.amount(at: 0.137),
            IslandCompletionMotion.amount(
                at: IslandCompletionMotion.cycleDuration + 0.137
            ),
            accuracy: 0.000_001
        )
    }

    func testRepeatedVerificationCatchesFastExitAfterTransientExitWasIgnored() {
        XCTAssertFalse(
            IslandHoverPolicy.shouldCollapse(
                pointerLocation: NSPoint(x: 599, y: 760),
                expandedFrame: expandedFrame
            )
        )
        XCTAssertTrue(
            IslandHoverPolicy.shouldCollapse(
                pointerLocation: NSPoint(x: 650, y: 760),
                expandedFrame: expandedFrame
            )
        )
    }

    func testPausedFinishKeepsTheRunningFinishWidth() {
        let totalWidth: CGFloat = 460
        let runningFinishWidth = IslandActionLayout.runningButtonWidth(
            totalWidth: totalWidth
        )
        let pausedFinishWidth = IslandActionLayout.pausedUnitWidth(
            totalWidth: totalWidth
        ) * 2

        XCTAssertEqual(pausedFinishWidth, runningFinishWidth, accuracy: 0.001)
    }

    func testCompleteKeepsFinishFixedWithoutChangingTotalWidth() {
        let totalWidth: CGFloat = 460
        let unit = IslandActionLayout.completionUnitWidth(totalWidth: totalWidth)
        let spacing = IslandActionLayout.completionSpacing
        let runningPauseWidth = IslandActionLayout.runningCompletionPauseWidth(
            totalWidth: totalWidth
        )
        let runningFinishOrigin = runningPauseWidth + spacing
        let pausedFinishOrigin = unit * 2 + spacing * 2

        XCTAssertEqual(runningPauseWidth + (unit * 2) + (spacing * 2), totalWidth, accuracy: 0.001)
        XCTAssertEqual((unit * 4) + (spacing * 3), totalWidth, accuracy: 0.001)
        XCTAssertEqual(unit * 2, IslandActionLayout.runningButtonWidth(totalWidth: totalWidth), accuracy: 0.001)
        XCTAssertEqual(runningFinishOrigin, pausedFinishOrigin, accuracy: 0.001)
    }

    func testCollapsedPanelFitsInsideThePhysicalNotch() {
        let size = IslandPanelLayout.collapsedSize(
            safeAreaTop: 32,
            auxiliaryTopLeftArea: NSRect(x: 0, y: 924, width: 646, height: 32),
            auxiliaryTopRightArea: NSRect(x: 825, y: 924, width: 645, height: 32)
        )

        XCTAssertEqual(size.width, 177, accuracy: 0.001)
        XCTAssertEqual(size.height, 31, accuracy: 0.001)
    }

    func testPanelFramesKeepTheScreenTopCenterAsTheyResize() {
        let screenFrame = NSRect(x: 120, y: 80, width: 1_470, height: 956)
        let collapsedFrame = IslandPanelLayout.topCenteredFrame(
            size: NSSize(width: 177, height: 31),
            screenFrame: screenFrame
        )
        let expandedFrame = IslandPanelLayout.topCenteredFrame(
            size: NSSize(width: 500, height: 190),
            screenFrame: screenFrame
        )

        XCTAssertEqual(collapsedFrame.midX, screenFrame.midX, accuracy: 0.001)
        XCTAssertEqual(expandedFrame.midX, screenFrame.midX, accuracy: 0.001)
        XCTAssertEqual(collapsedFrame.maxY, screenFrame.maxY, accuracy: 0.001)
        XCTAssertEqual(expandedFrame.maxY, screenFrame.maxY, accuracy: 0.001)

        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            let frame = IslandPanelLayout.interpolatedTopCenteredFrame(
                from: collapsedFrame,
                to: expandedFrame,
                progress: progress
            )
            XCTAssertEqual(frame.midX, screenFrame.midX, accuracy: 0.001)
            XCTAssertEqual(frame.maxY, screenFrame.maxY, accuracy: 0.001)
        }
    }

    func testCollapsedPanelUsesSmallerFallbackWithoutANotch() {
        let size = IslandPanelLayout.collapsedSize(
            safeAreaTop: 0,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )

        XCTAssertEqual(size, IslandPanelLayout.fallbackCollapsedSize)
    }

    func testLiquidGlassNeverChangesTheCollapsedBlackNotch() {
        XCTAssertFalse(
            IslandAppearancePolicy.usesLiquidNotchBackground(
                isExpanded: false,
                appearance: .liquidGlass
            )
        )
        XCTAssertFalse(
            IslandAppearancePolicy.usesLiquidNotchBackground(
                isExpanded: true,
                appearance: .classic
            )
        )
        XCTAssertTrue(
            IslandAppearancePolicy.usesLiquidNotchBackground(
                isExpanded: true,
                appearance: .liquidGlass
            )
        )
    }

    func testLiquidGlassNotchUsesClearerShellAndVividPrimaryTints() {
        XCTAssertLessThan(IslandLiquidGlassStyle.shellBlackOpacity, 0.15)
        XCTAssertLessThanOrEqual(IslandLiquidGlassStyle.shellTintOpacity, 0.15)
        XCTAssertGreaterThan(
            IslandLiquidGlassStyle.primaryActionTintOpacity,
            0.65
        )
        XCTAssertGreaterThan(
            IslandLiquidGlassStyle.selectedActivityTintOpacity,
            IslandLiquidGlassStyle.primaryActionTintOpacity
        )
        XCTAssertLessThan(
            IslandLiquidGlassStyle.controlWhiteOverlayOpacity,
            0.04
        )
        XCTAssertGreaterThan(
            IslandLiquidGlassStyle.primaryActionRGB.green
                - max(
                    IslandLiquidGlassStyle.primaryActionRGB.red,
                    IslandLiquidGlassStyle.primaryActionRGB.blue
                ),
            0.55
        )
        XCTAssertGreaterThan(
            IslandLiquidGlassStyle.selectedActivityRGB.blue
                - max(
                    IslandLiquidGlassStyle.selectedActivityRGB.red,
                    IslandLiquidGlassStyle.selectedActivityRGB.green
                ),
            0.60
        )
    }

    func testStandardNotchGlassParametersKeepTheBaseOpticalConstants() {
        let configuration = NotchGlassConfiguration.standard

        XCTAssertEqual(
            IslandLiquidGlassStyle.shellBlackOpacity(for: configuration),
            IslandLiquidGlassStyle.shellBlackOpacity,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.shellTintOpacity(for: configuration),
            IslandLiquidGlassStyle.shellTintOpacity,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.shellReflectionTintOpacity(
                for: configuration
            ),
            IslandLiquidGlassStyle.shellReflectionTintOpacity,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.additionalBlurOpacity(for: configuration),
            pow(2.0 / 12.0, 2.4),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.nativeGlassOpacity(
                for: configuration
            ),
            pow(2.0 / 12.0, 1.55),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.fallbackBaseMaterialOpacity(
                for: configuration
            ),
            pow(2.0 / 12.0, 1.55),
            accuracy: 0.000_001
        )
        XCTAssertEqual(configuration.frost, 6)
        XCTAssertEqual(configuration.bezelDepth, 0)
        XCTAssertEqual(configuration.refractiveIndex, 1.5, accuracy: 0.000_001)
    }

    func testBlurUsesOneContinuousNativeGlassRamp() {
        let minimum = NotchGlassConfiguration(
            blur: 0,
            refractiveIndexHundredths: 150
        )
        let one = NotchGlassConfiguration(
            blur: 1,
            refractiveIndexHundredths: 150
        )
        let standard = NotchGlassConfiguration(
            blur: 2,
            refractiveIndexHundredths: 150
        )
        let maximum = NotchGlassConfiguration(
            blur: 12,
            refractiveIndexHundredths: 150
        )

        XCTAssertEqual(
            IslandLiquidGlassStyle.nativeGlassOpacity(for: minimum),
            0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.nativeGlassOpacity(for: one),
            pow(1.0 / 12.0, 1.55),
            accuracy: 0.000_001
        )
        XCTAssertLessThan(
            IslandLiquidGlassStyle.nativeGlassOpacity(for: one),
            0.025
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.nativeGlassOpacity(for: standard),
            pow(2.0 / 12.0, 1.55),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.nativeGlassOpacity(for: maximum),
            1,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.additionalBlurOpacity(for: maximum),
            1,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.fallbackBaseMaterialOpacity(for: minimum),
            0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.fallbackBaseMaterialOpacity(for: one),
            pow(1.0 / 12.0, 1.55),
            accuracy: 0.000_001
        )
        XCTAssertLessThan(
            IslandLiquidGlassStyle.nativeGlassOpacity(for: one)
                - IslandLiquidGlassStyle.nativeGlassOpacity(for: minimum),
            IslandLiquidGlassStyle.nativeGlassOpacity(for: standard)
                - IslandLiquidGlassStyle.nativeGlassOpacity(for: one)
        )
    }

    func testRefractiveIndexChangesNativeOpticsWithoutChangingBaseStyle() {
        let minimum = NotchGlassConfiguration(
            blur: 0,
            refractiveIndexHundredths: 100
        )
        let maximum = NotchGlassConfiguration(
            blur: 0,
            refractiveIndexHundredths: 300
        )

        XCTAssertEqual(
            IslandLiquidGlassStyle.shellBlackOpacity(for: minimum),
            IslandLiquidGlassStyle.shellBlackOpacity(for: maximum),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.nativeGlassOpacity(for: minimum),
            IslandLiquidGlassStyle.nativeGlassOpacity(for: maximum),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.shellTintOpacity(for: maximum),
            IslandLiquidGlassStyle.shellTintOpacity(for: minimum),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.shellReflectionTintOpacity(for: maximum),
            IslandLiquidGlassStyle.shellReflectionTintOpacity(for: minimum),
            accuracy: 0.000_001
        )

        let standard = NotchGlassConfiguration.standard
        XCTAssertEqual(
            IslandLiquidGlassStyle.nativeRefractionOpacity(for: minimum),
            0,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(
            IslandLiquidGlassStyle.nativeRefractionOpacity(for: standard),
            0
        )
        XCTAssertLessThan(
            IslandLiquidGlassStyle.nativeRefractionOpacity(for: standard),
            IslandLiquidGlassStyle.nativeRefractionOpacity(for: maximum)
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.nativeRefractionOpacity(for: maximum),
            0.45,
            accuracy: 0.000_001
        )
    }

    func testConvexSquircleReferenceProfileAndMapStaySymmetric() throws {
        XCTAssertEqual(
            IslandConvexSquircleLens.profileHeight(at: 0),
            0,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandConvexSquircleLens.profileHeight(at: 1),
            1,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(
            IslandConvexSquircleLens.profileHeight(at: 0.5),
            0.98
        )

        let size = CGSize(width: 500, height: 190)
        let left = try XCTUnwrap(
            IslandConvexSquircleLens.normalizedDisplacement(
                at: CGPoint(x: 4, y: 80),
                in: size,
                cornerRadius: 25,
                refractiveIndex: 1.5
            )
        )
        let right = try XCTUnwrap(
            IslandConvexSquircleLens.normalizedDisplacement(
                at: CGPoint(x: 496, y: 80),
                in: size,
                cornerRadius: 25,
                refractiveIndex: 1.5
            )
        )
        let top = try XCTUnwrap(
            IslandConvexSquircleLens.normalizedDisplacement(
                at: CGPoint(x: 250, y: 4),
                in: size,
                cornerRadius: 25,
                refractiveIndex: 1.5
            )
        )
        let bottom = try XCTUnwrap(
            IslandConvexSquircleLens.normalizedDisplacement(
                at: CGPoint(x: 250, y: 186),
                in: size,
                cornerRadius: 25,
                refractiveIndex: 1.5
            )
        )

        XCTAssertEqual(
            left.dx,
            -right.dx,
            accuracy: 0.000_001
        )
        XCTAssertEqual(left.dy, 0, accuracy: 0.000_001)
        XCTAssertEqual(right.dy, 0, accuracy: 0.000_001)
        XCTAssertEqual(top.dx, 0, accuracy: 0.000_001)
        XCTAssertEqual(bottom.dx, 0, accuracy: 0.000_001)
        XCTAssertEqual(top.dy, -bottom.dy, accuracy: 0.000_001)
        XCTAssertGreaterThan(left.dx, 0)
        XCTAssertGreaterThan(top.dy, 0)
        XCTAssertLessThan(bottom.dy, 0)
        XCTAssertNil(
            IslandConvexSquircleLens.normalizedDisplacement(
                at: CGPoint(x: 250, y: 95),
                in: size,
                cornerRadius: 25,
                refractiveIndex: 1.5
            )
        )
    }

    func testConvexSquircleReferenceMapUsesIndexOneAsNeutral() throws {
        let size = CGSize(width: 500, height: 190)

        XCTAssertNil(
            IslandConvexSquircleLens.renderedMap(
                size: size,
                cornerRadius: 25,
                refractiveIndex: 1
            )
        )

        let map = try XCTUnwrap(
            IslandConvexSquircleLens.renderedMap(
                size: size,
                cornerRadius: 25,
                refractiveIndex: 1.5
            )
        )
        XCTAssertEqual(map.image.extent.size, size)
        XCTAssertGreaterThan(map.maximumDisplacement, 25)
    }

    func testFrostAndBezelAreFixedOutsideTheSettingsModel() {
        let minimum = NotchGlassConfiguration(
            blur: 0,
            refractiveIndexHundredths: 100
        )
        let maximum = NotchGlassConfiguration(
            blur: 12,
            refractiveIndexHundredths: 300
        )

        XCTAssertEqual(minimum.frost, 6)
        XCTAssertEqual(maximum.frost, 6)
        XCTAssertEqual(minimum.bezelDepth, 0)
        XCTAssertEqual(maximum.bezelDepth, 0)
        XCTAssertEqual(
            IslandLiquidGlassStyle.shellBlackOpacity(for: minimum),
            0.06,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.shellBlackOpacity(for: maximum),
            0.06,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.shellBlackOpacity,
            0.06,
            accuracy: 0.000_001
        )
    }

    func testCompactProgressAddsOnlySideAndBottomSpaceAroundTheNotch() {
        let collapsedSize = NSSize(width: 177, height: 31)
        let progressSize = IslandPanelLayout.compactProgressSize(
            collapsedSize: collapsedSize
        )

        XCTAssertEqual(progressSize.width, 185, accuracy: 0.001)
        XCTAssertEqual(progressSize.height, 35, accuracy: 0.001)
        XCTAssertEqual(
            progressSize.width - collapsedSize.width,
            IslandPanelLayout.compactProgressHorizontalInset * 2,
            accuracy: 0.001
        )
        XCTAssertEqual(
            progressSize.height - collapsedSize.height,
            IslandPanelLayout.compactProgressBottomInset,
            accuracy: 0.001
        )
    }

    func testStatusIndicatorSitsOnlyToTheRightOfThePhysicalNotch() {
        let notchFrame = NSRect(x: 646, y: 924, width: 177, height: 31)
        let indicatorFrame = IslandPanelLayout.statusIndicatorFrame(
            notchFrame: notchFrame
        )

        XCTAssertEqual(
            indicatorFrame.minX,
            notchFrame.maxX + IslandPanelLayout.statusIndicatorGap,
            accuracy: 0.001
        )
        XCTAssertEqual(indicatorFrame.width, IslandPanelLayout.statusIndicatorWidth)
        XCTAssertEqual(indicatorFrame.height, notchFrame.height)
        XCTAssertEqual(indicatorFrame.midY, notchFrame.midY, accuracy: 0.001)
    }

    func testCompactStatusOnlyExistsForRunningOrPausedWork() {
        XCTAssertNil(
            IslandCompactStatus.resolve(
                hasActiveWork: false,
                isRunning: false
            )
        )
        XCTAssertEqual(
            IslandCompactStatus.resolve(
                hasActiveWork: true,
                isRunning: true
            ),
            .running
        )
        XCTAssertEqual(
            IslandCompactStatus.resolve(
                hasActiveWork: true,
                isRunning: false
            ),
            .paused
        )
        XCTAssertEqual(IslandCompactStatus.running.accessibilityValue, "Running")
        XCTAssertEqual(IslandCompactStatus.paused.accessibilityValue, "Paused")
    }

    func testImmediateHelpUsesAnActiveAlwaysAppKitTrackingArea() throws {
        let view = ActiveHoverTrackingNSView(
            frame: NSRect(x: 0, y: 0, width: 30, height: 30)
        )
        var changes: [Bool] = []
        view.onHoverChanged = { changes.append($0) }

        view.updateTrackingAreas()

        let trackingArea = try XCTUnwrap(view.trackingAreas.first)
        XCTAssertTrue(trackingArea.options.contains(.mouseEnteredAndExited))
        XCTAssertTrue(trackingArea.options.contains(.mouseMoved))
        XCTAssertTrue(trackingArea.options.contains(.activeAlways))
        XCTAssertTrue(trackingArea.options.contains(.inVisibleRect))

        view.setHovering(true)
        view.setHovering(true)
        view.setHovering(false)

        XCTAssertEqual(changes, [true, false])
    }
}
