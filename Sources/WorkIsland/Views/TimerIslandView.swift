import AppKit
import SwiftUI

final class IslandPresentationState: ObservableObject {
    @Published var isExpanded = false
    @Published private(set) var interactionDepth = 0
    @Published private(set) var compactStatus: IslandCompactStatus?
    @Published private(set) var completionNotice: TimedActivityCompletion?
    @Published private(set) var isCompletionRevealPinned = false

    var isInteractionActive: Bool {
        interactionDepth > 0
    }

    func beginInteraction() {
        interactionDepth += 1
    }

    func endInteraction() {
        interactionDepth = max(0, interactionDepth - 1)
    }

    func updateCompactStatus(_ status: IslandCompactStatus?) {
        compactStatus = status
    }

    func presentCompletion(_ notice: TimedActivityCompletion) {
        completionNotice = notice
        isCompletionRevealPinned = true
        isExpanded = true
    }

    func dismissCompletion() {
        completionNotice = nil
        isCompletionRevealPinned = false
    }
}

struct IslandActionLayout {
    static let runningSpacing: CGFloat = 9
    static let pausedSpacing: CGFloat = runningSpacing / 2
    static let completionSpacing: CGFloat = runningSpacing / 3

    static func runningButtonWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, (totalWidth - runningSpacing) / 2)
    }

    static func pausedUnitWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, (totalWidth - pausedSpacing * 2) / 4)
    }

    static func completionUnitWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, (totalWidth - completionSpacing * 3) / 4)
    }

    static func runningCompletionPauseWidth(totalWidth: CGFloat) -> CGFloat {
        completionUnitWidth(totalWidth: totalWidth) * 2 + completionSpacing
    }
}

struct IslandHeaderLayout {
    static let openWindowSystemImage = "macwindow"
}

struct IslandDigitalClockLayout {
    static let idleFontSize: CGFloat = 18
    static let activeFontSize: CGFloat = 27
    static let fontWeight = Font.Weight.bold
    static let idleWidth: CGFloat = 108
    static let idleTextHorizontalOffset: CGFloat = -6
    static let timerChevronTrailingInset: CGFloat = 4
}

struct IslandCompletionMotion {
    static let cycleDuration: TimeInterval = 0.95
    static let ringingDuration: TimeInterval = 0.54
    static let oscillationCount = 4.0
    static let horizontalAmplitude: CGFloat = 2.0
    static let rotationAmplitude = 0.45

    static func amount(at elapsed: TimeInterval) -> Double {
        guard elapsed >= 0, cycleDuration > 0 else {
            return 0
        }

        let cycleTime = elapsed.truncatingRemainder(
            dividingBy: cycleDuration
        )
        guard cycleTime < ringingDuration else {
            return 0
        }

        let progress = cycleTime / ringingDuration
        let envelope = sin(.pi * progress)
        return sin(progress * .pi * 2 * oscillationCount) * envelope
    }
}

struct IslandAppearancePolicy {
    static func usesLiquidNotchBackground(
        isExpanded: Bool,
        appearance: WorkIslandAppearance
    ) -> Bool {
        isExpanded && appearance == .liquidGlass
    }
}

struct IslandLiquidGlassStyle {
    static let shellBlackOpacity = 0.12
    static let shellTintOpacity = 0.14
    static let primaryActionTintOpacity = 0.70
    static let selectedActivityTintOpacity = 0.76
    static let controlWhiteOverlayOpacity = 0.025
    static let controlHighlightOpacity = 0.10
    static let controlTintReflectionOpacity = 0.24
    static let controlTintBorderOpacity = 0.40

    static let primaryActionRGB = (red: 0.05, green: 0.92, blue: 0.28)
    static let selectedActivityRGB = (red: 0.32, green: 0.18, blue: 1.00)

    static var primaryActionTint: Color {
        Color(
            red: primaryActionRGB.red,
            green: primaryActionRGB.green,
            blue: primaryActionRGB.blue
        )
    }

    static var selectedActivityTint: Color {
        Color(
            red: selectedActivityRGB.red,
            green: selectedActivityRGB.green,
            blue: selectedActivityRGB.blue
        )
    }
}

private struct IslandNotchBackground: View {
    let isExpanded: Bool
    let appearance: WorkIslandAppearance

    @ViewBuilder
    var body: some View {
        let cornerRadius: CGFloat = isExpanded ? 25 : 14
        let shape = NotchShape(cornerRadius: cornerRadius)

        if IslandAppearancePolicy.usesLiquidNotchBackground(
            isExpanded: isExpanded,
            appearance: appearance
        ) {
            if #available(macOS 26.0, *) {
                shape
                    .fill(
                        Color.black.opacity(
                            IslandLiquidGlassStyle.shellBlackOpacity
                        )
                    )
                    .glassEffect(
                        .regular.tint(
                            IslandLiquidGlassStyle.selectedActivityTint.opacity(
                                IslandLiquidGlassStyle.shellTintOpacity
                            )
                        ),
                        in: shape
                    )
                    .overlay { liquidReflection(shape: shape) }
                    .overlay { liquidBorder(shape: shape) }
            } else {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.fill(Color.black.opacity(0.40))
                    }
                    .overlay { liquidReflection(shape: shape) }
                    .overlay { liquidBorder(shape: shape) }
            }
        } else {
            shape.fill(Color.black)
        }
    }

    private func liquidBorder(shape: NotchShape) -> some View {
        shape.stroke(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.56),
                    Color.white.opacity(0.14),
                    IslandLiquidGlassStyle.selectedActivityTint.opacity(0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
    }

    private func liquidReflection(shape: NotchShape) -> some View {
        shape
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.18), location: 0),
                        .init(color: Color.white.opacity(0.04), location: 0.24),
                        .init(color: .clear, location: 0.58),
                        .init(
                            color: IslandLiquidGlassStyle.selectedActivityTint.opacity(0.14),
                            location: 1
                        )
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
    }
}

struct TimerIslandView: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject var presentation: IslandPresentationState
    let openMainWindow: () -> Void
    @State private var isShowingDetails = false

    private var islandRecordingMode: ActivityRecordingMode {
        preferences.recordingMode.notchMode
    }

    var body: some View {
        ZStack(alignment: .top) {
            IslandNotchBackground(
                isExpanded: presentation.isExpanded,
                appearance: preferences.appearance
            )

            TimelineView(.periodic(from: .now, by: 1)) { context in
                ZStack(alignment: .top) {
                    progressOverlay(at: context.date)

                    if presentation.isExpanded {
                        expandedContent(at: context.date)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(
                                        with: .scale(scale: 0.97)
                                    ),
                                    removal: .opacity
                                )
                            )
                    } else {
                        Group {
                            if preferences.notchOpenMode != .doubleClick {
                                Button {
                                    presentation.isExpanded = true
                                } label: {
                                    compactContent
                                        .frame(
                                            maxWidth: .infinity,
                                            maxHeight: .infinity
                                        )
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Expand Work Island")
                                .accessibilityValue(
                                    presentation.compactStatus?.accessibilityValue
                                        ?? "Idle"
                                )
                            } else {
                                compactContent
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: .infinity
                                    )
                                    .contentShape(Rectangle())
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Expand Work Island")
                                    .accessibilityValue(
                                        presentation.compactStatus?.accessibilityValue
                                            ?? "Idle"
                                    )
                                    .onTapGesture(count: 2) {
                                        presentation.isExpanded = true
                                    }
                                    .accessibilityAction {
                                        presentation.isExpanded = true
                                    }
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .animation(
            presentation.isExpanded
                ? .spring(response: 0.24, dampingFraction: 0.86)
                : .easeOut(duration: 0.08),
            value: presentation.isExpanded
        )
        .onChange(of: preferences.recordingMode) { _ in
            isShowingDetails = false
        }
    }

    private var compactContent: some View {
        Color.clear
    }

    @ViewBuilder
    private func progressOverlay(at date: Date) -> some View {
        if let activeWork = store.activeWork,
           let progress = activeWork.progress(at: date),
           presentation.isExpanded || preferences.showsCompactProgress {
            if presentation.isExpanded {
                OpenNotchProgressShape(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)

                OpenNotchProgressShape(cornerRadius: 25)
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressColor(for: activeWork),
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            } else {
                OpenNotchProgressShape(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)

                OpenNotchProgressShape(cornerRadius: 16)
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressColor(for: activeWork),
                        style: StrokeStyle(
                            lineWidth: 2.5,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        } else if presentation.isExpanded {
            NotchShape(cornerRadius: 25)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
    }

    private func expandedContent(at date: Date) -> some View {
        VStack(spacing: 13) {
            HStack(spacing: 10) {
                Button(action: openMainWindow) {
                    Image(systemName: IslandHeaderLayout.openWindowSystemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 30, height: 30)
                        .islandSurface(
                            in: Circle(),
                            classicFill: Color.white.opacity(0.08),
                            classicStroke: .clear,
                            liquidTint: .white
                        )
                }
                .buttonStyle(IslandButtonStyle())
                .accessibilityLabel("Open window")

                Text("Work Island")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                statusBadge

                Spacer()

                IslandRecordingModeMenu(presentation: presentation)

                if presentation.completionNotice != nil {
                    Button {
                        presentation.dismissCompletion()
                        presentation.isExpanded = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: 30, height: 30)
                            .islandSurface(
                                in: Circle(),
                                classicFill: Color.white.opacity(0.08),
                                classicStroke: .clear,
                                liquidTint: .white
                            )
                    }
                    .buttonStyle(IslandButtonStyle())
                    .accessibilityLabel("Dismiss")
                }
            }

            if let activeWork = store.activeWork {
                IslandCompletionRingingMotion(
                    isActive: presentation.completionNotice != nil,
                    trigger: presentation.completionNotice?.id
                ) {
                    HStack(alignment: .center, spacing: 14) {
                        IslandSessionIdentity(
                            eyebrow: activeEyebrow(activeWork),
                            title: activeWork.activityItemTitle.map {
                                "\(activeWork.subject) · \($0)"
                            } ?? activeWork.subject
                        )

                        Spacer()

                        Text(
                            WorkFormatting.clock(
                                activeWork.displayedDuration(at: date)
                            )
                        )
                        .font(
                            .system(
                                size: IslandDigitalClockLayout.activeFontSize,
                                weight: IslandDigitalClockLayout.fontWeight,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }

                if activeWork.isRunning {
                    if store.canCompleteActiveItem {
                        GeometryReader { geometry in
                            let unitWidth = IslandActionLayout.completionUnitWidth(
                                totalWidth: geometry.size.width
                            )

                            HStack(
                                spacing: IslandActionLayout.completionSpacing
                            ) {
                                IslandActionButton(
                                    title: "Pause",
                                    systemName: "pause.fill",
                                    action: { pause(at: date) }
                                )
                                .frame(
                                    width: IslandActionLayout.runningCompletionPauseWidth(
                                        totalWidth: geometry.size.width
                                    )
                                )

                                IslandActionButton(
                                    title: "Finish",
                                    systemName: "stop.fill",
                                    tint: .indigo,
                                    action: { finish(at: date) }
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Complete",
                                    systemName: "checkmark",
                                    tint: .green,
                                    action: { finish(at: date, completingItem: true) }
                                )
                                .frame(width: unitWidth)
                            }
                        }
                        .frame(height: 34)
                    } else {
                        HStack(spacing: IslandActionLayout.runningSpacing) {
                            IslandActionButton(
                                title: "Pause",
                                systemName: "pause.fill",
                                action: { pause(at: date) }
                            )

                            IslandActionButton(
                                title: "Finish",
                                systemName: "checkmark",
                                tint: .indigo,
                                action: { finish(at: date) }
                            )
                        }
                        .frame(height: 34)
                    }
                } else {
                    if store.canCompleteActiveItem {
                        GeometryReader { geometry in
                            let unitWidth = IslandActionLayout.completionUnitWidth(
                                totalWidth: geometry.size.width
                            )

                            HStack(
                                spacing: IslandActionLayout.completionSpacing
                            ) {
                                IslandActionButton(
                                    title: "Resume",
                                    systemName: "play.fill",
                                    tint: .green,
                                    action: { resume(at: date) }
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Discard",
                                    systemName: "trash.fill",
                                    tint: .red,
                                    action: discard
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Finish",
                                    systemName: "stop.fill",
                                    tint: .indigo,
                                    action: { finish(at: date) }
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Complete",
                                    systemName: "checkmark",
                                    tint: .green,
                                    action: { finish(at: date, completingItem: true) }
                                )
                                .frame(width: unitWidth)
                            }
                        }
                        .frame(height: 34)
                    } else {
                        GeometryReader { geometry in
                            let unitWidth = IslandActionLayout.pausedUnitWidth(
                                totalWidth: geometry.size.width
                            )

                            HStack(spacing: IslandActionLayout.pausedSpacing) {
                                IslandActionButton(
                                    title: "Resume",
                                    systemName: "play.fill",
                                    tint: .green,
                                    action: { resume(at: date) }
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Discard",
                                    systemName: "trash.fill",
                                    tint: .red,
                                    action: discard
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Finish",
                                    systemName: "checkmark",
                                    tint: .indigo,
                                    action: { finish(at: date) }
                                )
                                .frame(width: unitWidth * 2)
                            }
                        }
                        .frame(height: 34)
                    }
                }
            } else if let notice = presentation.completionNotice {
                completionContent(notice)
            } else {
                if isShowingDetails {
                    idleDetails(at: date)
                } else {
                    idleActivityPicker(at: date)
                }
            }
        }
        .padding(.top, 36)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func idleActivityPicker(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IslandSessionIdentity(
                    eyebrow: idleEyebrow,
                    title: store.selectedTask?.name ?? "Choose an activity"
                )

                Spacer()

                switch islandRecordingMode {
                case .timer:
                    IslandDurationControl(
                        kind: .timer,
                        presentation: presentation
                    )
                case .manual:
                    IslandDurationControl(
                        kind: .manual,
                        presentation: presentation
                    )
                case .stopwatch, .pomodoro:
                    if let idleDigitalTime {
                        IslandIdleDigitalClock(value: idleDigitalTime)
                    }
                }

                Button {
                    isShowingDetails = true
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .frame(width: 34, height: 34)
                        .islandSurface(
                            in: Circle(),
                            classicFill: Color.white.opacity(0.09),
                            classicStroke: .clear,
                            liquidTint: .white
                        )
                }
                .buttonStyle(IslandButtonStyle())
                .accessibilityLabel("Details")

                idlePrimaryButton(at: date)
            }

            if store.availableTasks.isEmpty {
                Text("Open the main window and create an activity first.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(store.availableTasks) { task in
                            IslandTaskChip(
                                task: task,
                                isSelected: store.selectedTaskID == task.id
                            ) {
                                store.selectTask(id: task.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private func idleDetails(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                IslandActivityItemMenu(
                    presentation: presentation,
                    date: date
                )

                Spacer(minLength: 8)

                Button {
                    isShowingDetails = false
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .frame(width: 34, height: 34)
                        .islandSurface(
                            in: Circle(),
                            classicFill: Color.white.opacity(0.09),
                            classicStroke: .clear,
                            liquidTint: .white
                        )
                }
                .buttonStyle(IslandButtonStyle())
                .accessibilityLabel("Activities")

                idlePrimaryButton(at: date)
            }

            TextField(
                "Note",
                text: Binding(
                    get: { store.draftNote },
                    set: { store.updateNote($0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .islandSurface(
                in: RoundedRectangle(cornerRadius: 8),
                classicFill: Color.white.opacity(0.08),
                classicStroke: Color.white.opacity(0.12),
                liquidTint: .white
            )
        }
    }

    private func finish(at date: Date, completingItem: Bool = false) {
        presentation.dismissCompletion()
        if completingItem {
            _ = store.finishAndComplete(at: date)
        } else {
            _ = store.finish(at: date)
        }
        if store.activeWork == nil {
            isShowingDetails = false
        }
    }

    private func pause(at date: Date) {
        presentation.dismissCompletion()
        store.pause(at: date)
    }

    private func resume(at date: Date) {
        presentation.dismissCompletion()
        store.resume(at: date)
    }

    private func discard() {
        presentation.dismissCompletion()
        if store.discardPausedWork() {
            isShowingDetails = false
        }
    }

    private func startSelectedMode(at date: Date) {
        presentation.dismissCompletion()
        let mode = islandRecordingMode
        if preferences.recordingMode != mode {
            preferences.recordingMode = mode
        }

        switch mode {
        case .stopwatch:
            store.start(at: date)
        case .timer:
            _ = store.startTimer(
                duration: TimeInterval(
                    preferences.timerDurationMinutes * 60
                ),
                at: date
            )
        case .pomodoro:
            _ = store.startPomodoro(
                configuration: preferences.pomodoroConfiguration,
                at: date
            )
        case .manual:
            break
        }
    }

    @ViewBuilder
    private func idlePrimaryButton(at date: Date) -> some View {
        if islandRecordingMode == .manual {
            IslandActionButton(
                title: "Add",
                systemName: "plus",
                tint: .green,
                liquidTint: IslandLiquidGlassStyle.primaryActionTint,
                liquidTintOpacity: IslandLiquidGlassStyle.primaryActionTintOpacity,
                usesHighContrastLiquidLabel: true,
                isDisabled: !store.canStart,
                action: { addManualSession(at: date) }
            )
            .frame(width: 112)
        } else {
            IslandActionButton(
                title: "Start",
                systemName: "play.fill",
                tint: .green,
                liquidTint: IslandLiquidGlassStyle.primaryActionTint,
                liquidTintOpacity: IslandLiquidGlassStyle.primaryActionTintOpacity,
                usesHighContrastLiquidLabel: true,
                isDisabled: !store.canStart,
                action: { startSelectedMode(at: date) }
            )
            .frame(width: 112)
        }
    }

    private func addManualSession(at date: Date) {
        guard store.addManualSession(
            duration: TimeInterval(preferences.manualDurationMinutes * 60),
            anchorDate: date,
            anchor: preferences.manualTimeAnchor,
            taskID: store.selectedTaskID,
            activityItemID: store.selectedActivityItemID,
            usesSelectedActivityItemWhenNil: false,
            note: store.draftNote
        ) != nil else {
            return
        }

        isShowingDetails = false
        presentation.isExpanded = false
    }

    private func completionContent(
        _ notice: TimedActivityCompletion
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            IslandCompletionRingingMotion(
                isActive: true,
                trigger: notice.id
            ) {
                HStack(alignment: .center, spacing: 14) {
                    IslandSessionIdentity(
                        eyebrow: notice.title.uppercased(),
                        title: notice.activityTitle
                    )

                    Spacer()

                    Text("0:00")
                        .font(
                            .system(
                                size: IslandDigitalClockLayout.activeFontSize,
                                weight: IslandDigitalClockLayout.fontWeight,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(.white)
                }
            }

            IslandActionButton(
                title: "Done",
                systemName: "checkmark",
                tint: .green
            ) {
                presentation.dismissCompletion()
                presentation.isExpanded = false
            }
            .frame(height: 34)
        }
    }

    private var idleEyebrow: String {
        switch islandRecordingMode {
        case .stopwatch:
            return "STOPWATCH"
        case .manual:
            return "MANUAL"
        case .timer:
            return "TIMER"
        case .pomodoro:
            return "POMODORO"
        }
    }

    private var idleDigitalTime: String? {
        switch islandRecordingMode {
        case .pomodoro:
            return WorkFormatting.clock(
                TimeInterval(
                    preferences.pomodoroConfiguration.focusMinutes * 60
                )
            )
        case .stopwatch, .manual, .timer:
            return nil
        }
    }

    private func activeEyebrow(_ activeWork: ActiveWork) -> String {
        if let notice = presentation.completionNotice,
           let nextTitle = notice.nextTitle {
            return "\(notice.title.uppercased()) · \(nextTitle.uppercased())"
        }
        return activeWork.modeTitle.uppercased()
    }

    private func progressColor(for activeWork: ActiveWork) -> Color {
        switch activeWork.resolvedMode {
        case .stopwatch:
            return .indigo
        case .timer:
            return .indigo
        case .pomodoro:
            return activeWork.pomodoroPhase == .focus ? .green : .cyan
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let text = presentation.completionNotice != nil && store.activeWork == nil
            ? "DONE"
            : (store.isRunning ? "RUNNING" : (store.isPaused ? "PAUSED" : "READY"))
        let color: Color = presentation.completionNotice != nil && store.activeWork == nil
            ? .green
            : (store.isRunning ? .green : (store.isPaused ? .orange : .secondary))

        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.7)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .islandSurface(
                in: Capsule(),
                classicFill: color.opacity(0.13),
                classicStroke: .clear,
                liquidTint: color,
                isInteractive: false
            )
    }
}

private struct IslandCompletionRingingMotion<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    let isActive: Bool
    let trigger: UUID?
    let content: Content

    init(
        isActive: Bool,
        trigger: UUID?,
        @ViewBuilder content: () -> Content
    ) {
        self.isActive = isActive
        self.trigger = trigger
        self.content = content()
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: reduceMotion || !isActive
            )
        ) { context in
            let amount = motionAmount(at: context.date)

            content
                .offset(
                    x: IslandCompletionMotion.horizontalAmplitude
                        * CGFloat(amount)
                )
                .rotationEffect(
                    .degrees(
                        IslandCompletionMotion.rotationAmplitude * amount
                    )
                )
        }
        .onAppear(perform: restart)
        .onChange(of: trigger) { _ in
            restart()
        }
    }

    private func motionAmount(at date: Date) -> Double {
        guard isActive, !reduceMotion else {
            return 0
        }
        return IslandCompletionMotion.amount(
            at: date.timeIntervalSince(startedAt)
        )
    }

    private func restart() {
        startedAt = Date()
    }
}

private enum IslandDurationKind {
    case timer
    case manual

    var accessibilityLabel: String {
        switch self {
        case .timer:
            return "Timer duration"
        case .manual:
            return "Manual duration"
        }
    }
}

private struct IslandDurationControl: View {
    @EnvironmentObject private var preferences: AppPreferences
    let kind: IslandDurationKind
    @ObservedObject var presentation: IslandPresentationState
    @AppStorage(ManualDurationOptions.stepPreferenceKey)
    private var step = ManualDurationOptions.defaultMinuteStep
    @State private var isChoosingDuration = false
    @State private var isHoldingInteraction = false

    private var durationMinutes: Int {
        switch kind {
        case .timer:
            return preferences.timerDurationMinutes
        case .manual:
            return preferences.manualDurationMinutes
        }
    }

    private func setDuration(hours: Int, minutes: Int) {
        switch kind {
        case .timer:
            preferences.setTimerDuration(hours: hours, minutes: minutes)
        case .manual:
            preferences.setManualDuration(hours: hours, minutes: minutes)
        }
    }

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { durationMinutes / 60 },
            set: { hours in
                setDuration(
                    hours: hours,
                    minutes: durationMinutes % 60
                )
            }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { durationMinutes % 60 },
            set: { minutes in
                setDuration(
                    hours: durationMinutes / 60,
                    minutes: minutes
                )
            }
        )
    }

    var body: some View {
        Button(action: presentPicker) {
            ZStack(alignment: .trailing) {
                IslandIdleDigitalClock(
                    value: WorkFormatting.clock(
                        TimeInterval(durationMinutes * 60)
                    )
                )

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.46))
                    .padding(
                        .trailing,
                        IslandDigitalClockLayout.timerChevronTrailingInset
                    )
            }
            .frame(width: IslandDigitalClockLayout.idleWidth)
        }
        .buttonStyle(IslandButtonStyle())
        .accessibilityLabel(kind.accessibilityLabel)
        .accessibilityValue(
            WorkFormatting.clock(
                TimeInterval(durationMinutes * 60)
            )
        )
        .popover(isPresented: $isChoosingDuration, arrowEdge: .bottom) {
            DurationPicker(
                hours: hoursBinding,
                minutes: minutesBinding,
                step: $step
            )
            .padding(12)
            .onDisappear(perform: releaseInteraction)
        }
        .onDisappear(perform: releaseInteraction)
    }

    private func presentPicker() {
        guard !isChoosingDuration else {
            return
        }
        if !isHoldingInteraction {
            presentation.beginInteraction()
            isHoldingInteraction = true
        }
        isChoosingDuration = true
    }

    private func releaseInteraction() {
        guard isHoldingInteraction else {
            return
        }
        isHoldingInteraction = false
        presentation.endInteraction()
    }
}

private struct IslandIdleDigitalClock: View {
    let value: String

    var body: some View {
        Text(value)
            .font(
                .system(
                    size: IslandDigitalClockLayout.idleFontSize,
                    weight: IslandDigitalClockLayout.fontWeight,
                    design: .monospaced
                )
            )
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(width: IslandDigitalClockLayout.idleWidth)
            .offset(x: IslandDigitalClockLayout.idleTextHorizontalOffset)
    }
}

private struct IslandRecordingModeMenu: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject var presentation: IslandPresentationState

    private var currentMode: ActivityRecordingMode {
        guard let activeWork = store.activeWork else {
            return preferences.recordingMode.notchMode
        }
        switch activeWork.resolvedMode {
        case .stopwatch:
            return .stopwatch
        case .timer:
            return .timer
        case .pomodoro:
            return .pomodoro
        }
    }

    var body: some View {
        Button(action: showMenu) {
            HStack(spacing: 6) {
                Image(systemName: currentMode.systemImage)
                Text(currentMode.title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.46))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .islandSurface(
                in: Capsule(),
                classicFill: Color.white.opacity(0.08),
                classicStroke: Color.white.opacity(0.1),
                liquidTint: .white
            )
        }
        .buttonStyle(IslandButtonStyle())
        .disabled(store.activeWork != nil)
        .opacity(store.activeWork == nil ? 1 : 0.58)
        .accessibilityLabel("Method")
    }

    private func showMenu() {
        guard store.activeWork == nil else {
            return
        }

        presentation.beginInteraction()
        defer { presentation.endInteraction() }

        let menu = NSMenu(title: "Method")
        menu.autoenablesItems = false
        menu.minimumWidth = 150
        var positioningItem: NSMenuItem?

        for mode in ActivityRecordingMode.notchCases {
            let item = IslandSelectionMenuItem(
                title: mode.title,
                systemName: mode.systemImage,
                isSelected: currentMode == mode
            ) {
                preferences.recordingMode = mode
            }
            menu.addItem(item)
            if currentMode == mode {
                positioningItem = item
            }
        }

        _ = menu.popUp(
            positioning: positioningItem,
            at: NSEvent.mouseLocation,
            in: nil
        )
    }
}

private struct IslandActivityItemMenu: View {
    @EnvironmentObject private var store: WorkTimerStore
    @ObservedObject var presentation: IslandPresentationState
    let date: Date

    private var tasks: [ActivityItem] {
        guard let activityID = store.selectedTaskID else {
            return []
        }
        return store.selectableTasks(for: activityID, at: date)
    }

    private var routines: [ActivityItem] {
        guard let activityID = store.selectedTaskID else {
            return []
        }
        return store.selectableRoutines(for: activityID, at: date)
    }

    var body: some View {
        Button(action: showMenu) {
            HStack(spacing: 7) {
                Image(
                    systemName: store.selectedActivityItem?.kind.islandSystemImage
                        ?? "minus.circle"
                )
                Text(store.selectedActivityItem?.title ?? "None")
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.46))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(width: 232, height: 34)
            .islandSurface(
                in: Capsule(),
                classicFill: Color.white.opacity(0.08),
                classicStroke: Color.white.opacity(0.12),
                liquidTint: .white
            )
        }
        .buttonStyle(IslandButtonStyle())
        .accessibilityLabel("Item")
    }

    private func showMenu() {
        presentation.beginInteraction()
        defer { presentation.endInteraction() }

        let menu = NSMenu(title: "Item")
        menu.autoenablesItems = false
        menu.minimumWidth = 232
        var positioningItem: NSMenuItem?

        let noneItem = IslandSelectionMenuItem(
            title: "None",
            systemName: "minus.circle",
            isSelected: store.selectedActivityItemID == nil
        ) {
            store.selectActivityItem(id: nil, at: date)
        }
        menu.addItem(noneItem)
        if store.selectedActivityItemID == nil {
            positioningItem = noneItem
        }

        if !tasks.isEmpty || !routines.isEmpty {
            menu.addItem(.separator())
        }

        addSection(
            title: "Tasks",
            items: tasks,
            to: menu,
            positioningItem: &positioningItem
        )

        if !tasks.isEmpty && !routines.isEmpty {
            menu.addItem(.separator())
        }

        addSection(
            title: "Routines",
            items: routines,
            to: menu,
            positioningItem: &positioningItem
        )

        _ = menu.popUp(
            positioning: positioningItem,
            at: NSEvent.mouseLocation,
            in: nil
        )
    }

    private func addSection(
        title: String,
        items: [ActivityItem],
        to menu: NSMenu,
        positioningItem: inout NSMenuItem?
    ) {
        guard !items.isEmpty else {
            return
        }

        let header = NSMenuItem(
            title: title,
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)

        for item in items {
            let menuItem = IslandSelectionMenuItem(
                title: item.title,
                systemName: item.kind.islandSystemImage,
                isSelected: store.selectedActivityItemID == item.id
            ) {
                store.selectActivityItem(id: item.id, at: date)
            }
            menu.addItem(menuItem)
            if store.selectedActivityItemID == item.id {
                positioningItem = menuItem
            }
        }
    }
}

private final class IslandSelectionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(
        title: String,
        systemName: String,
        isSelected: Bool,
        handler: @escaping () -> Void
    ) {
        self.handler = handler
        super.init(title: title, action: nil, keyEquivalent: "")
        target = self
        action = #selector(performSelection(_:))
        state = isSelected ? .on : .off
        image = NSImage(
            systemSymbolName: systemName,
            accessibilityDescription: title
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func performSelection(_ sender: NSMenuItem) {
        handler()
    }
}

private struct IslandSessionIdentity: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eyebrow)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.42))

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

private struct IslandActionButton: View {
    @EnvironmentObject private var preferences: AppPreferences

    let title: String
    let systemName: String
    var tint: Color = .white
    var liquidTint: Color? = nil
    var liquidTintOpacity = 0.52
    var usesHighContrastLiquidLabel = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .islandSurface(
                    in: Capsule(),
                    classicFill: tint.opacity(0.13),
                    classicStroke: tint.opacity(0.18),
                    liquidTint: liquidTint ?? tint,
                    liquidTintOpacity: liquidTintOpacity
                )
        }
        .buttonStyle(IslandButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
    }

    private var labelColor: Color {
        usesHighContrastLiquidLabel && preferences.appearance == .liquidGlass
            ? .white
            : tint
    }
}

private struct IslandTaskChip: View {
    let task: WorkTask
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }

                Text(task.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.64))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
                .islandSurface(
                    in: Capsule(),
                    classicFill: isSelected
                        ? Color.indigo.opacity(0.76)
                        : Color.white.opacity(0.08),
                    classicStroke: isSelected
                        ? Color.indigo.opacity(0.9)
                        : Color.white.opacity(0.1),
                    liquidTint: isSelected
                        ? IslandLiquidGlassStyle.selectedActivityTint
                        : .white,
                    liquidTintOpacity: isSelected
                        ? IslandLiquidGlassStyle.selectedActivityTintOpacity
                        : 0.07
                )
        }
        .buttonStyle(IslandButtonStyle())
        .accessibilityLabel(isSelected ? "Selected activity, \(task.name)" : "Select activity, \(task.name)")
    }
}

private struct IslandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.76 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct IslandAdaptiveSurface<S: Shape>: ViewModifier {
    @EnvironmentObject private var preferences: AppPreferences

    let shape: S
    let classicFill: Color
    let classicStroke: Color
    let liquidTint: Color
    let liquidTintOpacity: Double
    let isInteractive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if preferences.appearance == .liquidGlass {
            content
                .background(
                    Color.white.opacity(
                        IslandLiquidGlassStyle.controlWhiteOverlayOpacity
                    ),
                    in: shape
                )
                .background(liquidTint.opacity(liquidTintOpacity), in: shape)
                .background(
                    LinearGradient(
                        stops: [
                            .init(
                                color: Color.white.opacity(
                                    IslandLiquidGlassStyle.controlHighlightOpacity
                                ),
                                location: 0
                            ),
                            .init(color: .clear, location: 0.48),
                            .init(
                                color: liquidTint.opacity(
                                    IslandLiquidGlassStyle.controlTintReflectionOpacity
                                ),
                                location: 1
                            )
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: shape
                )
                .overlay { liquidBorder }
                .shadow(
                    color: .black.opacity(isInteractive ? 0.14 : 0.08),
                    radius: isInteractive ? 3 : 2,
                    y: 1
                )
        } else {
            content
                .background(classicFill, in: shape)
                .overlay {
                    shape.stroke(classicStroke, lineWidth: 1)
                }
        }
    }

    private var liquidBorder: some View {
        shape.stroke(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.44),
                    Color.white.opacity(0.09),
                    liquidTint.opacity(
                        IslandLiquidGlassStyle.controlTintBorderOpacity
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
    }
}

private extension View {
    func islandSurface<S: Shape>(
        in shape: S,
        classicFill: Color,
        classicStroke: Color,
        liquidTint: Color,
        liquidTintOpacity: Double = 0.16,
        isInteractive: Bool = true
    ) -> some View {
        modifier(
            IslandAdaptiveSurface(
                shape: shape,
                classicFill: classicFill,
                classicStroke: classicStroke,
                liquidTint: liquidTint,
                liquidTintOpacity: liquidTintOpacity,
                isInteractive: isInteractive
            )
        )
    }
}

private struct NotchShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

struct OpenNotchProgressShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: 1.5, dy: 1.5)
        let radius = min(
            cornerRadius,
            min(insetRect.width, insetRect.height) / 2
        )
        var path = Path()

        path.move(to: CGPoint(x: insetRect.maxX, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.maxX - radius, y: insetRect.maxY),
            control: CGPoint(x: insetRect.maxX, y: insetRect.maxY)
        )
        path.addLine(to: CGPoint(x: insetRect.minX + radius, y: insetRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.minX, y: insetRect.maxY - radius),
            control: CGPoint(x: insetRect.minX, y: insetRect.maxY)
        )
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.minY))
        return path
    }
}
