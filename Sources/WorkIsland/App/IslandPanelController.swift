import AppKit
import Combine
import SwiftUI

protocol IslandPanelPresenting: AnyObject {
    func show()
}

final class IslandPanelController: IslandPanelPresenting {
    private let store: WorkTimerStore
    private let panel: IslandPanel
    private let statusIndicatorPanel: IslandPanel
    private let presentation = IslandPresentationState()
    private let preferences: AppPreferences
    private let expandedSize = NSSize(width: 500, height: 190)
    private let pointerVerificationInterval: TimeInterval = 1.0 / 60.0
    private var cancellables = Set<AnyCancellable>()
    private var pointerVerificationTimer: Timer?
    private var panelFrameAnimationTimer: Timer?
    private var timedCompletionTimer: Timer?
    private var completionRevealTimer: Timer?
    private var menuTrackingDepth = 0

    init(
        store: WorkTimerStore,
        preferences: AppPreferences,
        openMainWindow: @escaping () -> Void
    ) {
        self.store = store
        self.preferences = preferences
        panel = IslandPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        statusIndicatorPanel = IslandPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.clickHandler = { [weak presentation, weak preferences] clickCount in
            guard let presentation,
                  let preferences,
                  IslandClickPolicy.shouldExpand(
                      mode: preferences.notchOpenMode,
                      clickCount: clickCount
                  ),
                  !presentation.isExpanded else {
                return
            }
            presentation.isExpanded = true
        }

        let rootView = TimerIslandView(
            presentation: presentation,
            openMainWindow: openMainWindow
        )
        .environmentObject(store)
        .environmentObject(preferences)

        let hostingView = IslandHostingView(rootView: rootView)
        hostingView.hoverChanged = { [weak self] isHovering in
            self?.handleHover(isHovering)
        }
        panel.contentView = hostingView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false

        statusIndicatorPanel.contentView = NSHostingView(
            rootView: IslandCompactStatusIndicator(presentation: presentation)
        )
        statusIndicatorPanel.backgroundColor = .clear
        statusIndicatorPanel.isOpaque = false
        statusIndicatorPanel.hasShadow = false
        statusIndicatorPanel.isFloatingPanel = true
        statusIndicatorPanel.hidesOnDeactivate = false
        statusIndicatorPanel.becomesKeyOnlyIfNeeded = true
        statusIndicatorPanel.ignoresMouseEvents = true
        statusIndicatorPanel.level = .statusBar
        statusIndicatorPanel.collectionBehavior = panel.collectionBehavior
        statusIndicatorPanel.animationBehavior = .none
        statusIndicatorPanel.isReleasedWhenClosed = false

        store.$activeWork
            .map { activeWork -> IslandCompactStatus? in
                IslandCompactStatus.resolve(
                    hasActiveWork: activeWork != nil,
                    isRunning: activeWork?.isRunning == true
                )
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else {
                    return
                }
                presentation.updateCompactStatus(status)
                updateStatusIndicatorVisibility()
            }
            .store(in: &cancellables)

        store.$activeWork
            .receive(on: RunLoop.main)
            .sink { [weak self] activeWork in
                self?.scheduleTimedCompletion(for: activeWork)
                self?.positionPanel(animated: true)
            }
            .store(in: &cancellables)

        preferences.$showsCompactProgress
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.positionPanel(animated: true)
            }
            .store(in: &cancellables)

        presentation.$isExpanded
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isExpanded in
                self?.updatePointerVerification(isExpanded: isExpanded)
                self?.positionPanel(animated: true)
                self?.updateStatusIndicatorVisibility()
                if isExpanded {
                    NotificationCenter.default.post(
                        name: .workIslandNotchDidExpand,
                        object: nil
                    )
                }
            }
            .store(in: &cancellables)

        preferences.$notchOpenMode
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.presentation.isExpanded = false
            }
            .store(in: &cancellables)

        presentation.$interactionDepth
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] depth in
                if depth == 0 {
                    self?.collapseIfPointerIsOutside()
                }
            }
            .store(in: &cancellables)

        presentation.$isCompletionRevealPinned
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] isPinned in
                guard !isPinned else {
                    return
                }
                self?.completionRevealTimer?.invalidate()
                self?.completionRevealTimer = nil
                self?.collapseIfPointerIsOutside()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.positionPanel(animated: false)
            self?.updateStatusIndicatorVisibility()
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.menuTrackingDepth += 1
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                menuTrackingDepth = max(0, menuTrackingDepth - 1)
                if menuTrackingDepth == 0 {
                    collapseIfPointerIsOutside()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        pointerVerificationTimer?.invalidate()
        panelFrameAnimationTimer?.invalidate()
        timedCompletionTimer?.invalidate()
        completionRevealTimer?.invalidate()
    }

    func show() {
        positionPanel(animated: false)
        panel.orderFrontRegardless()
        updateStatusIndicatorVisibility()
    }

    private func handleHover(_ isHovering: Bool) {
        if isHovering {
            guard preferences.notchOpenMode == .hover else {
                return
            }
            guard !presentation.isExpanded else {
                return
            }
            presentation.isExpanded = true
            return
        }

        collapseIfPointerIsOutside()
    }

    private func updatePointerVerification(isExpanded: Bool) {
        if isExpanded {
            startPointerVerification()
        } else {
            stopPointerVerification()
        }
    }

    private func startPointerVerification() {
        guard pointerVerificationTimer == nil else {
            return
        }

        let timer = Timer(
            timeInterval: pointerVerificationInterval,
            repeats: true
        ) { [weak self] _ in
            self?.collapseIfPointerIsOutside()
        }
        pointerVerificationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPointerVerification() {
        pointerVerificationTimer?.invalidate()
        pointerVerificationTimer = nil
    }

    private func collapseIfPointerIsOutside() {
        guard presentation.isExpanded else {
            stopPointerVerification()
            return
        }

        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            presentation.isExpanded = false
            return
        }

        let expandedFrame = IslandPanelLayout.topCenteredFrame(
            size: expandedSize,
            screenFrame: screen.frame
        )
        guard IslandHoverPolicy.shouldCollapse(
            pointerLocation: NSEvent.mouseLocation,
            expandedFrame: expandedFrame,
            isInteractionActive: menuTrackingDepth > 0
                || presentation.isInteractionActive
                || presentation.isCompletionRevealPinned
        ) else {
            return
        }

        presentation.isExpanded = false
    }

    private func scheduleTimedCompletion(for activeWork: ActiveWork?) {
        timedCompletionTimer?.invalidate()
        timedCompletionTimer = nil

        guard activeWork?.isRunning == true,
              let delay = activeWork?.remainingDuration(at: Date()) else {
            return
        }

        let timer = Timer(
            timeInterval: max(0.01, delay),
            repeats: false
        ) { [weak self] _ in
            self?.handleTimedCompletion()
        }
        timedCompletionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleTimedCompletion() {
        timedCompletionTimer?.invalidate()
        timedCompletionTimer = nil

        guard let notice = store.completeTimedActivity(at: Date()) else {
            scheduleTimedCompletion(for: store.activeWork)
            return
        }

        completionRevealTimer?.invalidate()
        completionRevealTimer = nil
        presentation.presentCompletion(notice)
        panel.orderFrontRegardless()

        guard let timeout = preferences.completionRevealMode.timeout else {
            return
        }

        let timer = Timer(
            timeInterval: timeout,
            repeats: false
        ) { [weak self] _ in
            guard let self else {
                return
            }
            completionRevealTimer = nil
            presentation.dismissCompletion()
            collapseIfPointerIsOutside()
        }
        completionRevealTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func positionPanel(animated: Bool) {
        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let collapsedSize = IslandPanelLayout.collapsedSize(on: screen)
        let collapsedFrame = IslandPanelLayout.topCenteredFrame(
            size: collapsedSize,
            screenFrame: screen.frame
        )
        let showsCompactProgress = preferences.showsCompactProgress
            && store.activeWork?.progress(at: Date()) != nil
        let size: NSSize
        if presentation.isExpanded {
            size = expandedSize
        } else if showsCompactProgress {
            size = IslandPanelLayout.compactProgressSize(
                collapsedSize: collapsedSize
            )
        } else {
            size = collapsedSize
        }

        let frame = IslandPanelLayout.topCenteredFrame(
            size: size,
            screenFrame: screen.frame
        )
        statusIndicatorPanel.setFrame(
            IslandPanelLayout.statusIndicatorFrame(notchFrame: collapsedFrame),
            display: true
        )
        panel.hasShadow = presentation.isExpanded
        if animated {
            animatePanel(
                to: frame,
                duration: presentation.isExpanded ? 0.18 : 0.08
            )
        } else {
            panelFrameAnimationTimer?.invalidate()
            panelFrameAnimationTimer = nil
            panel.setFrame(frame, display: true)
        }
    }

    private func animatePanel(to targetFrame: NSRect, duration: TimeInterval) {
        panelFrameAnimationTimer?.invalidate()
        panelFrameAnimationTimer = nil

        let startFrame = panel.frame
        guard startFrame != targetFrame, duration > 0 else {
            panel.setFrame(targetFrame, display: true)
            return
        }

        let startedAt = ProcessInfo.processInfo.systemUptime
        let timer = Timer(
            timeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
            let progress = min(1, max(0, elapsed / duration))
            let easedProgress = 1 - pow(1 - progress, 3)
            let frame = IslandPanelLayout.interpolatedTopCenteredFrame(
                from: startFrame,
                to: targetFrame,
                progress: easedProgress
            )
            panel.setFrame(frame, display: true)

            if progress >= 1 {
                timer.invalidate()
                panelFrameAnimationTimer = nil
                panel.setFrame(targetFrame, display: true)
            }
        }
        panelFrameAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func updateStatusIndicatorVisibility() {
        guard presentation.compactStatus != nil,
              !presentation.isExpanded else {
            statusIndicatorPanel.orderOut(nil)
            return
        }

        statusIndicatorPanel.orderFrontRegardless()
    }

}

enum IslandCompactStatus: Equatable {
    case running
    case paused

    static func resolve(
        hasActiveWork: Bool,
        isRunning: Bool
    ) -> IslandCompactStatus? {
        guard hasActiveWork else {
            return nil
        }
        return isRunning ? .running : .paused
    }

    var color: Color {
        switch self {
        case .running:
            return .green
        case .paused:
            return .orange
        }
    }

    var accessibilityValue: String {
        switch self {
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        }
    }
}

private struct IslandCompactStatusIndicator: View {
    @ObservedObject var presentation: IslandPresentationState

    var body: some View {
        ZStack {
            if let status = presentation.compactStatus {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.72), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.45), radius: 1, y: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

enum IslandPanelLayout {
    static let fallbackCollapsedSize = NSSize(width: 176, height: 32)
    static let physicalNotchInset: CGFloat = 1
    static let compactProgressHorizontalInset: CGFloat = 4
    static let compactProgressBottomInset: CGFloat = 4
    static let statusIndicatorGap: CGFloat = 3
    static let statusIndicatorWidth: CGFloat = 14

    static func topCenteredFrame(
        size: NSSize,
        screenFrame: NSRect
    ) -> NSRect {
        NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    static func interpolatedTopCenteredFrame(
        from startFrame: NSRect,
        to endFrame: NSRect,
        progress: Double
    ) -> NSRect {
        let amount = CGFloat(min(1, max(0, progress)))
        let width = interpolate(
            from: startFrame.width,
            to: endFrame.width,
            amount: amount
        )
        let height = interpolate(
            from: startFrame.height,
            to: endFrame.height,
            amount: amount
        )
        let centerX = interpolate(
            from: startFrame.midX,
            to: endFrame.midX,
            amount: amount
        )
        let topY = interpolate(
            from: startFrame.maxY,
            to: endFrame.maxY,
            amount: amount
        )

        return NSRect(
            x: centerX - width / 2,
            y: topY - height,
            width: width,
            height: height
        )
    }

    private static func interpolate(
        from start: CGFloat,
        to end: CGFloat,
        amount: CGFloat
    ) -> CGFloat {
        start + (end - start) * amount
    }

    static func collapsedSize(on screen: NSScreen) -> NSSize {
        collapsedSize(
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea
        )
    }

    static func collapsedSize(
        safeAreaTop: CGFloat,
        auxiliaryTopLeftArea: NSRect?,
        auxiliaryTopRightArea: NSRect?
    ) -> NSSize {
        guard safeAreaTop > 0,
              let auxiliaryTopLeftArea,
              let auxiliaryTopRightArea else {
            return fallbackCollapsedSize
        }

        let physicalNotchWidth = auxiliaryTopRightArea.minX
            - auxiliaryTopLeftArea.maxX
        guard physicalNotchWidth > physicalNotchInset * 2 else {
            return fallbackCollapsedSize
        }

        return NSSize(
            width: physicalNotchWidth - physicalNotchInset * 2,
            height: max(1, safeAreaTop - physicalNotchInset)
        )
    }

    static func statusIndicatorFrame(notchFrame: NSRect) -> NSRect {
        NSRect(
            x: notchFrame.maxX + statusIndicatorGap,
            y: notchFrame.minY,
            width: statusIndicatorWidth,
            height: notchFrame.height
        )
    }

    static func compactProgressSize(collapsedSize: NSSize) -> NSSize {
        NSSize(
            width: collapsedSize.width + compactProgressHorizontalInset * 2,
            height: collapsedSize.height + compactProgressBottomInset
        )
    }
}

enum IslandHoverPolicy {
    static let edgeTolerance: CGFloat = 1

    static func shouldCollapse(
        pointerLocation: NSPoint,
        expandedFrame: NSRect,
        isInteractionActive: Bool = false
    ) -> Bool {
        guard !isInteractionActive else {
            return false
        }

        let stableHitArea = expandedFrame.insetBy(
            dx: -edgeTolerance,
            dy: -edgeTolerance
        )
        return !stableHitArea.contains(pointerLocation)
    }
}

enum IslandClickPolicy {
    static func shouldExpand(
        mode: NotchOpenMode,
        clickCount: Int
    ) -> Bool {
        switch mode {
        case .hover:
            return false
        case .singleClick:
            return clickCount == 1
        case .doubleClick:
            return clickCount == 2
        }
    }
}

private final class IslandPanel: NSPanel {
    var clickHandler: ((Int) -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            clickHandler?(event.clickCount)
        }
        super.sendEvent(event)
    }
}

private final class IslandHostingView<Content: View>: NSHostingView<Content> {
    var hoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea,
           trackingAreas.contains(where: { $0 === hoverTrackingArea }) {
            return
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [
                .mouseEnteredAndExited,
                .mouseMoved,
                .activeAlways,
                .inVisibleRect
            ],
            owner: self,
            userInfo: nil
        )
        hoverTrackingArea = trackingArea
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        hoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        hoverChanged?(false)
    }

    override func mouseMoved(with event: NSEvent) {
        hoverChanged?(true)
    }
}
