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

    func testActivityIdentityKeepsOneRowHeightWhenRecordingStarts() {
        XCTAssertEqual(
            IslandSessionIdentityLayout.idleRowHeight,
            IslandSessionIdentityLayout.activeRowHeight
        )
        XCTAssertEqual(IslandSessionIdentityLayout.idleRowHeight, 34)
    }

    func testDetailsAndBackShareOneStableTrailingControlSlot() {
        XCTAssertEqual(IslandDetailsToggleLayout.rowSpacing, 10)
        XCTAssertEqual(
            IslandDetailsToggleLayout.actionSpacing,
            IslandDetailsToggleLayout.rowSpacing
        )
        XCTAssertEqual(
            IslandDetailsToggleLayout.controlSize,
            IslandSessionIdentityLayout.idleRowHeight
        )
        XCTAssertLessThan(
            IslandDetailsToggleLayout.symbolCanvasSize,
            IslandDetailsToggleLayout.controlSize
        )
        XCTAssertEqual(
            IslandDetailsToggleLayout.systemImage(isShowingDetails: false),
            "list.bullet.rectangle"
        )
        XCTAssertEqual(
            IslandDetailsToggleLayout.systemImage(isShowingDetails: true),
            "chevron.backward"
        )
    }

    func testManualAddFeedbackMorphsBeforeAStableCollapse() {
        XCTAssertEqual(
            ManualAddFeedbackTiming.labelFadeOutDuration,
            0.18,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            ManualAddFeedbackTiming.labelFadeInDuration,
            0.24,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(
            ManualAddFeedbackTiming.confirmationDuration,
            ManualAddFeedbackTiming.labelMorphDuration
        )
        XCTAssertEqual(
            ManualAddFeedbackTiming.confirmedHoldDuration,
            1,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            ManualAddFeedbackTiming.confirmationDuration,
            ManualAddFeedbackTiming.labelMorphDuration + 1,
            accuracy: 0.000_001
        )
        XCTAssertEqual(ManualAddFeedbackPhase.idle.title, "Add")
        XCTAssertEqual(ManualAddFeedbackPhase.idle.systemName, "plus")
        XCTAssertEqual(ManualAddFeedbackPhase.fadingOut.labelOpacity, 0)
        XCTAssertEqual(ManualAddFeedbackPhase.confirmed.title, "Added")
        XCTAssertEqual(
            ManualAddFeedbackPhase.confirmed.systemName,
            "checkmark"
        )
        XCTAssertFalse(ManualAddFeedbackPhase.idle.locksInteraction)
        XCTAssertTrue(ManualAddFeedbackPhase.confirmed.locksInteraction)
        XCTAssertGreaterThanOrEqual(
            ManualAddFeedbackTiming.resetDelayAfterCollapse,
            NotchAnimationTiming.movementDuration
        )
        XCTAssertGreaterThanOrEqual(
            ManualAddFeedbackTiming.resetDelayAfterCollapse,
            NotchAnimationTiming.contentResponse
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

    func testPanelFramesKeepThePhysicalNotchTopCenterAsTheyResize() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1_470, height: 956)
        let leftArea = NSRect(x: 0, y: 924, width: 646, height: 32)
        let rightArea = NSRect(x: 825, y: 924, width: 645, height: 32)
        let anchor = IslandPanelLayout.horizontalAnchor(
            screenFrame: screenFrame,
            auxiliaryTopLeftArea: leftArea,
            auxiliaryTopRightArea: rightArea
        )
        let collapsedFrame = IslandPanelLayout.topAnchoredFrame(
            size: NSSize(width: 177, height: 31),
            centerX: anchor,
            topY: screenFrame.maxY
        )
        let expandedFrame = IslandPanelLayout.topAnchoredFrame(
            size: NSSize(width: 500, height: 190),
            centerX: anchor,
            topY: screenFrame.maxY
        )

        XCTAssertEqual(anchor, 735.5, accuracy: 0.001)
        XCTAssertEqual(collapsedFrame.midX, anchor, accuracy: 0.001)
        XCTAssertEqual(expandedFrame.midX, anchor, accuracy: 0.001)
        XCTAssertEqual(collapsedFrame.maxY, screenFrame.maxY, accuracy: 0.001)
        XCTAssertEqual(expandedFrame.maxY, screenFrame.maxY, accuracy: 0.001)

        for progress in stride(from: 0.0, through: 1.0, by: 0.01) {
            let frame = IslandPanelLayout.interpolatedTopAnchoredFrame(
                from: collapsedFrame,
                to: expandedFrame,
                progress: progress
            )
            XCTAssertEqual(frame.midX, anchor, accuracy: 0.001)
            XCTAssertEqual(frame.maxY, screenFrame.maxY, accuracy: 0.001)
            XCTAssertEqual(frame.minX, frame.minX.rounded(), accuracy: 0.001)
            XCTAssertEqual(frame.maxX, frame.maxX.rounded(), accuracy: 0.001)
            XCTAssertEqual(
                collapsedFrame.minX - frame.minX,
                frame.maxX - collapsedFrame.maxX,
                accuracy: 0.001
            )
        }

        let interruptedFrame = collapsedFrame.offsetBy(dx: 7, dy: -3)
        let normalizedFrame = IslandPanelLayout.interpolatedTopAnchoredFrame(
            from: interruptedFrame,
            to: expandedFrame,
            progress: 0.4
        )
        XCTAssertEqual(normalizedFrame.midX, anchor, accuracy: 0.001)
        XCTAssertEqual(normalizedFrame.maxY, screenFrame.maxY, accuracy: 0.001)
    }

    func testPanelAnchorFallsBackToScreenCenterWithoutAPhysicalNotch() {
        let screenFrame = NSRect(x: 120, y: 80, width: 1_470, height: 956)

        XCTAssertEqual(
            IslandPanelLayout.horizontalAnchor(
                screenFrame: screenFrame,
                auxiliaryTopLeftArea: nil,
                auxiliaryTopRightArea: nil
            ),
            screenFrame.midX,
            accuracy: 0.001
        )
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

    func testLiquidGlassNotchUsesClearerShellAndVividActionTints() {
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
        XCTAssertGreaterThan(
            IslandLiquidGlassStyle.vividActionTintOpacity,
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
        XCTAssertEqual(
            IslandLiquidGlassStyle.resumeActionRGB.red,
            IslandLiquidGlassStyle.primaryActionRGB.red
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.resumeActionRGB.green,
            IslandLiquidGlassStyle.primaryActionRGB.green
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.resumeActionRGB.blue,
            IslandLiquidGlassStyle.primaryActionRGB.blue
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.resumeActionTintOpacity,
            IslandLiquidGlassStyle.primaryActionTintOpacity
        )
        XCTAssertGreaterThan(
            IslandLiquidGlassStyle.pauseActionRGB.red
                - IslandLiquidGlassStyle.pauseActionRGB.blue,
            0.90
        )
        XCTAssertGreaterThan(
            IslandLiquidGlassStyle.finishActionRGB.blue
                - max(
                    IslandLiquidGlassStyle.finishActionRGB.red,
                    IslandLiquidGlassStyle.finishActionRGB.green
                ),
            0.70
        )
        XCTAssertGreaterThan(
            IslandLiquidGlassStyle.discardActionRGB.red
                - max(
                    IslandLiquidGlassStyle.discardActionRGB.green,
                    IslandLiquidGlassStyle.discardActionRGB.blue
                ),
            0.80
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
            pow(8.0 / 12.0, 2.4),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.nativeGlassOpacity(
                for: configuration
            ),
            pow(8.0 / 12.0, 1.55),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.fallbackBaseMaterialOpacity(
                for: configuration
            ),
            pow(8.0 / 12.0, 1.55),
            accuracy: 0.000_001
        )
        XCTAssertEqual(configuration.frost, 6)
        XCTAssertEqual(configuration.bezelDepth, 0)
        XCTAssertEqual(configuration.refractiveIndex, 1, accuracy: 0.000_001)
    }

    func testBlurUsesTheFixedEightOfTwelveGlassRamp() {
        let configuration = NotchGlassConfiguration.standard

        XCTAssertEqual(configuration.blur, 8)
        XCTAssertEqual(NotchGlassConfiguration.fixedBlur, 8)
        XCTAssertEqual(NotchGlassConfiguration.blurScaleMaximum, 12)
        XCTAssertEqual(
            IslandLiquidGlassStyle.nativeGlassOpacity(for: configuration),
            pow(8.0 / 12.0, 1.55),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.additionalBlurOpacity(for: configuration),
            pow(8.0 / 12.0, 2.4),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            IslandLiquidGlassStyle.fallbackBaseMaterialOpacity(
                for: configuration
            ),
            pow(8.0 / 12.0, 1.55),
            accuracy: 0.000_001
        )
    }

    func testRefractionRemainsFixedAtTheNeutralIndex() {
        let configuration = NotchGlassConfiguration.standard

        XCTAssertEqual(
            NotchGlassConfiguration.fixedRefractiveIndexHundredths,
            100
        )
        XCTAssertEqual(configuration.refractiveIndexHundredths, 100)
        XCTAssertEqual(configuration.refractiveIndex, 1, accuracy: 0.000_001)
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
        let configuration = NotchGlassConfiguration.standard

        XCTAssertEqual(configuration.frost, 6)
        XCTAssertEqual(configuration.bezelDepth, 0)
        XCTAssertEqual(
            IslandLiquidGlassStyle.shellBlackOpacity(for: configuration),
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
