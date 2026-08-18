import AppKit
import SwiftUI

struct WorkAppearanceStyle {
    static let cardCornerRadius: CGFloat = 20
    static let cardBorderWidth: CGFloat = 1
}

struct MainPageLayout {
    static let contentInset: CGFloat = 28
    static let standardMaximumContentWidth: CGFloat = 900
    static let dashboardMaximumContentWidth: CGFloat = 1_060

    static func trailingContentInset(
        for availableWidth: CGFloat,
        maximumContentWidth: CGFloat
    ) -> CGFloat {
        max(
            contentInset,
            availableWidth - contentInset - maximumContentWidth
        )
    }
}

struct MainPageScrollContainer<Content: View>: View {
    let maximumContentWidth: CGFloat
    private let content: Content

    init(
        maximumContentWidth: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.maximumContentWidth = maximumContentWidth
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 14.0, *) {
            GeometryReader { geometry in
                ScrollView {
                    content
                }
                .contentMargins(
                    .all,
                    EdgeInsets(
                        top: MainPageLayout.contentInset,
                        leading: MainPageLayout.contentInset,
                        bottom: MainPageLayout.contentInset,
                        trailing: MainPageLayout.trailingContentInset(
                            for: geometry.size.width,
                            maximumContentWidth: maximumContentWidth
                        )
                    ),
                    for: .scrollContent
                )
            }
        } else {
            ScrollView {
                HStack(spacing: 0) {
                    content.frame(maxWidth: maximumContentWidth)
                    Spacer(minLength: 0)
                }
                .padding(MainPageLayout.contentInset)
            }
        }
    }
}

struct WorkSegmentedPickerMotion {
    static let response = 0.28
    static let dampingFraction = 0.86

    static var animation: Animation {
        .spring(
            response: response,
            dampingFraction: dampingFraction
        )
    }
}

struct WorkSegmentedPickerStyle {
    static let selectedFillOpacity = 0.24
    static let selectedStrokeOpacity = 0.62
}

struct WorkSegmentedPicker<Option: Hashable>: View {
    @Namespace private var selectionNamespace
    @State private var highlightedSelection: Option?

    let accessibilityName: String
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    var tint: Color = .indigo
    var height: CGFloat = 32

    var body: some View {
        let visualSelection = highlightedSelection ?? selection
        let track = RoundedRectangle(
            cornerRadius: height * 0.24,
            style: .continuous
        )

        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = visualSelection == option

                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(
                            .system(
                                size: 12,
                                weight: isSelected ? .semibold : .medium
                            )
                        )
                        .foregroundStyle(
                            isSelected ? Color.primary : Color.secondary
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .background {
                            if isSelected {
                                ClassicSegmentSelectionSurface(
                                    tint: tint,
                                    cornerRadius: height * 0.18
                                )
                                .matchedGeometryEffect(
                                    id: "selection",
                                    in: selectionNamespace
                                )
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(option))
                .accessibilityValue(
                    selection == option ? "Selected" : "Not selected"
                )
            }
        }
        .padding(3)
        .frame(height: height)
        .background(Color.primary.opacity(0.075), in: track)
        .overlay {
            track.stroke(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .clipShape(track)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityName)
        .onAppear {
            highlightedSelection = selection
        }
        .onChange(of: selection) { newSelection in
            withAnimation(WorkSegmentedPickerMotion.animation) {
                highlightedSelection = newSelection
            }
        }
    }
}

private struct ClassicSegmentSelectionSurface: View {
    let tint: Color
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )

        shape
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.96))
            .overlay {
                shape.fill(
                    tint.opacity(
                        WorkSegmentedPickerStyle.selectedFillOpacity
                    )
                )
            }
            .overlay {
                shape.stroke(
                    tint.opacity(
                        WorkSegmentedPickerStyle.selectedStrokeOpacity
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
    }
}

struct RootView: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences
    @State private var selection: AppSection? = .dashboard

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: {
                preferences.isPrepared && preferences.needsOnboarding
            },
            set: { _ in }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
                    .padding(.vertical, 4)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 240)
            .safeAreaInset(edge: .bottom) {
                SidebarStatusView()
                    .environmentObject(store)
                    .padding(12)
            }
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard:
                    DashboardView()
                case .tasks:
                    TasksView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsPageView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
        }
        .frame(
            minWidth: MainWindowLayout.minimumWidth,
            minHeight: MainWindowLayout.minimumHeight
        )
        .overlay(alignment: .bottom) {
            if let persistenceError = store.persistenceError {
                Label(persistenceError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.red.opacity(0.92), in: Capsule())
                    .padding(.bottom, 12)
                }
        }
        .overlay(alignment: .top) {
            if preferences.showsNotchIntroduction {
                NotchIntroductionBanner {
                    preferences.completeNotchIntroduction()
                }
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: onboardingBinding) {
            OnboardingView()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .workIslandNotchDidExpand
            )
        ) { _ in
            if preferences.showsNotchIntroduction {
                preferences.completeNotchIntroduction()
            }
        }
        .animation(.easeOut(duration: 0.18), value: preferences.showsNotchIntroduction)
    }
}

private struct NotchIntroductionBanner: View {
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up")
                .foregroundStyle(.indigo)

            Text("Move your pointer to the notch.")
                .font(.subheadline.weight(.medium))

            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss")
            .hoverHelp("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case tasks
    case history
    case settings

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .tasks:
            return "Activities"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "rectangle.3.group.fill"
        case .tasks:
            return "checklist"
        case .history:
            return "calendar"
        case .settings:
            return "gearshape"
        }
    }
}

private struct SidebarStatusView: View {
    @EnvironmentObject private var store: WorkTimerStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 9) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(statusTitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    if let activeWork = store.activeWork {
                        Text(
                            WorkFormatting.clock(
                                activeWork.displayedDuration(at: context.date)
                            )
                        )
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Saved locally")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(10)
        }
        .modifier(SidebarStatusBackground())
    }

    private var statusTitle: String {
        if store.isRunning {
            return "Running"
        }
        if store.isPaused {
            return "Paused"
        }
        return "Ready"
    }

    private var statusColor: Color {
        if store.isRunning {
            return .green
        }
        if store.isPaused {
            return .orange
        }
        return .secondary
    }

}

private struct SidebarStatusBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            .quaternary.opacity(0.45),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

struct AppBackground: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor)
            .ignoresSafeArea()
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(
                    cornerRadius: WorkAppearanceStyle.cardCornerRadius,
                    style: .continuous
                )
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                .overlay(
                    RoundedRectangle(
                        cornerRadius: WorkAppearanceStyle.cardCornerRadius,
                        style: .continuous
                    )
                    .stroke(
                        Color.primary.opacity(0.08),
                        lineWidth: WorkAppearanceStyle.cardBorderWidth
                    )
                )
            )
    }
}

private struct WorkSecondaryButtonStyleModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        content.buttonStyle(.bordered)
    }
}

private struct WorkProminentButtonStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.buttonStyle(.borderedProminent)
    }
}

enum HoverHelpPlacement {
    case above
    case below

    var alignment: Alignment {
        switch self {
        case .above:
            return .top
        case .below:
            return .bottom
        }
    }

    var verticalOffset: CGFloat {
        switch self {
        case .above:
            return -30
        case .below:
            return 30
        }
    }
}

struct HoverHelpLabel: ViewModifier {
    let text: String
    let placement: HoverHelpPlacement
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                ActiveHoverTrackingView { hovering in
                    isHovering = hovering
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            .overlay(alignment: placement.alignment) {
                if isHovering {
                    Text(text)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                        .fixedSize()
                        .offset(y: placement.verticalOffset)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .help(text)
            .zIndex(isHovering ? 100 : 0)
            .onDisappear {
                isHovering = false
            }
    }
}

struct ActiveHoverTrackingView: NSViewRepresentable {
    let onHoverChanged: (Bool) -> Void

    func makeNSView(context: Context) -> ActiveHoverTrackingNSView {
        let view = ActiveHoverTrackingNSView()
        view.onHoverChanged = onHoverChanged
        return view
    }

    func updateNSView(_ nsView: ActiveHoverTrackingNSView, context: Context) {
        nsView.onHoverChanged = onHoverChanged
    }
}

final class ActiveHoverTrackingNSView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovering = false

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

        DispatchQueue.main.async { [weak self] in
            self?.reconcilePointerLocation()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        setHovering(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovering(false)
    }

    override func mouseMoved(with event: NSEvent) {
        setHovering(true)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            setHovering(false)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.reconcilePointerLocation()
            }
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func setHovering(_ hovering: Bool) {
        guard isHovering != hovering else {
            return
        }
        isHovering = hovering
        onHoverChanged?(hovering)
    }

    private func reconcilePointerLocation() {
        guard let window else {
            return
        }

        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let localPoint = convert(windowPoint, from: nil)
        setHovering(bounds.contains(localPoint))
    }
}

extension View {
    func workCard() -> some View {
        modifier(CardBackground())
    }

    func workSecondaryButtonStyle() -> some View {
        modifier(WorkSecondaryButtonStyleModifier())
    }

    func workProminentButtonStyle() -> some View {
        modifier(WorkProminentButtonStyleModifier())
    }

    func hoverHelp(
        _ text: String,
        placement: HoverHelpPlacement = .above
    ) -> some View {
        modifier(HoverHelpLabel(text: text, placement: placement))
    }
}
