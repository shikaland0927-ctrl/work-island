import AppKit
import ServiceManagement
import SwiftUI

struct SettingsControlLayout {
    static let standardTrailingWidth: CGFloat = 220
    static let notchOpenWidth: CGFloat = 300
    static let notchGlassControlWidth: CGFloat = 300
    static let notchGlassSliderWidth: CGFloat = 246
    static let notchGlassValueWidth: CGFloat = 36
    static let pomodoroMenuWidth: CGFloat = 76
    static let pomodoroMenuHeight: CGFloat = 24
    static let pomodoroFieldWidth = pomodoroMenuWidth
    static let pomodoroSpacing: CGFloat = 10
    static let pomodoroWidth = pomodoroFieldWidth * 4 + pomodoroSpacing * 3
    static let dashboardListHeight: CGFloat = 134
    static let dashboardListCornerRadius: CGFloat = 10
}

struct SettingsView: View {
    var body: some View {
        ScrollView {
            SettingsContent()
                .padding(20)
        }
        .frame(width: 800, height: 620)
        .background(AppBackground())
    }
}

struct SettingsPageView: View {
    var body: some View {
        ScrollView {
            SettingsContent()
                .padding(28)
                .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle("Settings")
    }
}

private struct SettingsContent: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "General", systemImage: "gearshape") {
                GeneralSettingsView()
            }

            SettingsCard(title: "Notch Glass", systemImage: "drop") {
                NotchGlassSettingsView {
                    preferences.beginNotchGlassPreview()
                }
            }

            SettingsCard(title: "Timing", systemImage: "timer") {
                TimingSettingsView()
            }

            SettingsCard(
                title: "Dashboard",
                systemImage: "rectangle.3.group"
            ) {
                DashboardSettingsView()
            }
        }
        .onDisappear {
            preferences.endNotchGlassPreview()
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))

            content
        }
        .padding(22)
        .workCard()
    }
}

private struct SettingsRow<Label: View, Control: View>: View {
    let label: Label
    let control: Control

    init(
        @ViewBuilder label: () -> Label,
        @ViewBuilder control: () -> Control
    ) {
        self.label = label()
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            label

            Spacer(minLength: 20)

            control
                .frame(alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SettingsControlLabel: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginController

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { _ = launchAtLogin.setEnabled($0) }
        )
    }

    private var dayStartBinding: Binding<Int> {
        Binding(
            get: { preferences.dayStartHour },
            set: { preferences.setDayStartHour($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsRow {
                SettingsControlLabel(
                    title: "Appearance",
                    detail: appearanceDetail,
                    systemImage: "circle.lefthalf.filled"
                )
            } control: {
                WorkSegmentedPicker(
                    accessibilityName: "Appearance",
                    selection: $preferences.appearance,
                    options: WorkIslandAppearance.allCases,
                    title: { $0.title }
                )
                .frame(
                    width: SettingsControlLayout.standardTrailingWidth,
                    alignment: .trailing
                )
            }

            Divider()

            SettingsRow {
                SettingsControlLabel(
                    title: "Launch at Login",
                    detail: launchDetail,
                    systemImage: "power"
                )
            } control: {
                Toggle("Launch at Login", isOn: launchBinding)
                    .labelsHidden()
                    .disabled(!launchAtLogin.canManage)
                    .accessibilityLabel("Launch at Login")
                    .frame(
                        width: SettingsControlLayout.standardTrailingWidth,
                        alignment: .trailing
                    )
            }

            Divider()

            SettingsRow {
                SettingsControlLabel(
                    title: "Day Starts",
                    detail: "Earlier work belongs to the previous Dashboard day.",
                    systemImage: "sunrise"
                )
            } control: {
                Picker("Day Starts", selection: dayStartBinding) {
                    ForEach(WorkdayCalendar.validStartHours, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour))
                            .tag(hour)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(
                    width: SettingsControlLayout.standardTrailingWidth,
                    alignment: .trailing
                )
                .accessibilityLabel("Day Starts")
            }

            Divider()

            SettingsRow {
                SettingsControlLabel(
                    title: "Notch",
                    detail: notchOpenDescription,
                    systemImage: "macbook"
                )
            } control: {
                WorkSegmentedPicker(
                    accessibilityName: "Open Notch",
                    selection: $preferences.notchOpenMode,
                    options: NotchOpenMode.allCases,
                    title: { $0.title }
                )
                .frame(
                    width: SettingsControlLayout.notchOpenWidth,
                    alignment: .trailing
                )
            }
        }
        .onAppear {
            launchAtLogin.refresh()
        }
    }

    private var launchDetail: String {
        if let message = launchAtLogin.errorMessage {
            return message
        }
        if launchAtLogin.requiresApproval {
            return "Allow it in System Settings > General > Login Items."
        }
        if !launchAtLogin.canManage {
            return "Move Work Island to Applications to change this."
        }
        return "Open Work Island automatically after login."
    }

    private var appearanceDetail: String {
        switch preferences.appearance {
        case .classic:
            return "Keep the original Work Island style."
        case .liquidGlass:
            return "Add translucent glass while keeping the current colors."
        }
    }

    private var notchOpenDescription: String {
        switch preferences.notchOpenMode {
        case .hover:
            return "Move the pointer onto the notch to open it."
        case .singleClick:
            return "Click the notch once to open it."
        case .doubleClick:
            return "Double-click the notch to open it."
        }
    }
}

private struct NotchGlassSettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let onAdjustment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Expanded notch in Liquid Glass only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Reset") {
                    preferences.resetNotchGlassConfiguration()
                }
                .buttonStyle(.borderless)
                .disabled(
                    preferences.notchGlassConfiguration == .standard
                )
            }

            Divider()

            sliderRow(
                title: "Frost",
                detail: "Adjust the glass density.",
                systemImage: "cloud.fog",
                value: preferences.notchGlassConfiguration.frost,
                range: NotchGlassConfiguration.frostRange,
                onChange: {
                    onAdjustment()
                    preferences.setNotchGlassConfiguration(frost: $0)
                }
            )

            Divider()

            sliderRow(
                title: "Blur",
                detail: "Soften the desktop behind the notch.",
                systemImage: "drop",
                value: preferences.notchGlassConfiguration.blur,
                range: NotchGlassConfiguration.blurRange,
                onChange: {
                    onAdjustment()
                    preferences.setNotchGlassConfiguration(blur: $0)
                }
            )

            Divider()

            sliderRow(
                title: "Refraction",
                detail: "Strengthen the even edge lens.",
                systemImage: "sparkles",
                value: preferences.notchGlassConfiguration.refraction,
                range: NotchGlassConfiguration.refractionRange,
                onChange: {
                    onAdjustment()
                    preferences.setNotchGlassConfiguration(refraction: $0)
                }
            )

            Divider()

            sliderRow(
                title: "Bezel Depth",
                detail: "Strengthen the inner glass rim.",
                systemImage: "square.on.square",
                value: preferences.notchGlassConfiguration.bezelDepth,
                range: NotchGlassConfiguration.bezelDepthRange,
                onChange: {
                    onAdjustment()
                    preferences.setNotchGlassConfiguration(bezelDepth: $0)
                }
            )
        }
    }

    private func sliderRow(
        title: String,
        detail: String,
        systemImage: String,
        value: Int,
        range: ClosedRange<Int>,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        SettingsRow {
            SettingsControlLabel(
                title: title,
                detail: detail,
                systemImage: systemImage
            )
        } control: {
            HStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { onChange(Int($0.rounded())) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                )
                .frame(width: SettingsControlLayout.notchGlassSliderWidth)
                .accessibilityLabel(title)
                .accessibilityValue("\(value)")

                Text("\(value)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(
                        width: SettingsControlLayout.notchGlassValueWidth,
                        alignment: .trailing
                    )
            }
            .frame(
                width: SettingsControlLayout.notchGlassControlWidth,
                alignment: .trailing
            )
        }
    }
}

private struct TimingSettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsRow {
                SettingsControlLabel(
                    title: "Alert",
                    detail: "Choose whether completion closes automatically.",
                    systemImage: "bell"
                )
            } control: {
                WorkSegmentedPicker(
                    accessibilityName: "Alert",
                    selection: $preferences.completionRevealMode,
                    options: CompletionRevealMode.allCases,
                    title: { $0.title }
                )
                .frame(
                    width: SettingsControlLayout.standardTrailingWidth,
                    alignment: .trailing
                )
            }

            Divider()

            SettingsRow {
                SettingsControlLabel(
                    title: "Progress",
                    detail: "Show Timer and Pomodoro progress while closed.",
                    systemImage: "circle.dashed"
                )
            } control: {
                Toggle(
                    "Progress",
                    isOn: $preferences.showsCompactProgress
                )
                .labelsHidden()
                .accessibilityLabel("Show progress while closed")
                .frame(
                    width: SettingsControlLayout.standardTrailingWidth,
                    alignment: .trailing
                )
            }

            Divider()

            SettingsRow {
                SettingsControlLabel(
                    title: "Set As",
                    detail: "Treat now as the start or end of Manual work.",
                    systemImage: "clock.arrow.circlepath"
                )
            } control: {
                WorkSegmentedPicker(
                    accessibilityName: "Manual Set As",
                    selection: $preferences.manualTimeAnchor,
                    options: SessionTimeAnchor.allCases,
                    title: { $0.rawValue }
                )
                .frame(
                    width: SettingsControlLayout.standardTrailingWidth,
                    alignment: .trailing
                )
            }

            Divider()

            SettingsRow {
                SettingsControlLabel(
                    title: "Pomodoro",
                    detail: "Set focus and break lengths used by the notch.",
                    systemImage: "repeat.circle"
                )
            } control: {
                PomodoroSettingsControls()
            }
        }
    }
}

private struct SettingsPopUpButton: NSViewRepresentable {
    let title: String
    let values: [Int]
    @Binding var selection: Int
    let suffix: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> FixedContainer {
        let container = FixedContainer(
            width: SettingsControlLayout.pomodoroMenuWidth,
            height: SettingsControlLayout.pomodoroMenuHeight
        )
        container.button.target = context.coordinator
        container.button.action = #selector(Coordinator.selectionChanged(_:))
        container.button.setAccessibilityLabel(title)
        return container
    }

    func updateNSView(_ container: FixedContainer, context: Context) {
        context.coordinator.parent = self
        let button = container.button

        let titles = values.map { "\($0)\(suffix)" }
        if button.itemTitles != titles {
            button.removeAllItems()
            button.addItems(withTitles: titles)
        }

        if let selectedIndex = values.firstIndex(of: selection),
           button.indexOfSelectedItem != selectedIndex {
            button.selectItem(at: selectedIndex)
        }

        button.setAccessibilityLabel(title)
        button.setAccessibilityValue("\(selection)\(suffix)")
    }

    final class FixedContainer: NSView {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        private let fixedSize: NSSize

        init(width: CGFloat, height: CGFloat) {
            fixedSize = NSSize(width: width, height: height)
            super.init(frame: NSRect(origin: .zero, size: fixedSize))

            button.isBordered = true
            button.bezelStyle = .rounded
            button.controlSize = .regular
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setContentCompressionResistancePriority(
                .defaultLow,
                for: .horizontal
            )
            addSubview(button)

            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: leadingAnchor),
                button.trailingAnchor.constraint(equalTo: trailingAnchor),
                button.topAnchor.constraint(equalTo: topAnchor),
                button.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var intrinsicContentSize: NSSize {
            fixedSize
        }
    }

    final class Coordinator: NSObject {
        var parent: SettingsPopUpButton

        init(parent: SettingsPopUpButton) {
            self.parent = parent
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            let selectedIndex = sender.indexOfSelectedItem
            guard parent.values.indices.contains(selectedIndex) else {
                return
            }
            parent.selection = parent.values[selectedIndex]
        }
    }
}

private struct PomodoroSettingsControls: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        HStack(
            alignment: .bottom,
            spacing: SettingsControlLayout.pomodoroSpacing
        ) {
            minuteField(
                title: "Focus",
                values: PomodoroConfiguration.focusRange,
                selection: focusBinding
            )
            minuteField(
                title: "Break",
                values: PomodoroConfiguration.shortBreakRange,
                selection: shortBreakBinding
            )
            minuteField(
                title: "Long",
                values: PomodoroConfiguration.longBreakRange,
                selection: longBreakBinding
            )
            pomodoroField(
                title: "Sessions",
                values: PomodoroConfiguration.sessionsRange,
                selection: sessionsBinding
            )
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(
            width: SettingsControlLayout.pomodoroWidth,
            alignment: .trailing
        )
    }

    private func minuteField(
        title: String,
        values: ClosedRange<Int>,
        selection: Binding<Int>
    ) -> some View {
        pomodoroField(
            title: title,
            values: values,
            selection: selection,
            suffix: " min"
        )
    }

    private func pomodoroField(
        title: String,
        values: ClosedRange<Int>,
        selection: Binding<Int>,
        suffix: String = ""
    ) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            SettingsPopUpButton(
                title: title,
                values: Array(values),
                selection: selection,
                suffix: suffix
            )
            .frame(
                width: SettingsControlLayout.pomodoroMenuWidth,
                height: SettingsControlLayout.pomodoroMenuHeight
            )
        }
        .frame(
            width: SettingsControlLayout.pomodoroFieldWidth,
            alignment: .trailing
        )
    }

    private var focusBinding: Binding<Int> {
        Binding(
            get: { preferences.pomodoroConfiguration.focusMinutes },
            set: { preferences.setPomodoroConfiguration(focusMinutes: $0) }
        )
    }

    private var shortBreakBinding: Binding<Int> {
        Binding(
            get: { preferences.pomodoroConfiguration.shortBreakMinutes },
            set: { preferences.setPomodoroConfiguration(shortBreakMinutes: $0) }
        )
    }

    private var longBreakBinding: Binding<Int> {
        Binding(
            get: { preferences.pomodoroConfiguration.longBreakMinutes },
            set: { preferences.setPomodoroConfiguration(longBreakMinutes: $0) }
        )
    }

    private var sessionsBinding: Binding<Int> {
        Binding(
            get: { preferences.pomodoroConfiguration.sessionsBeforeLongBreak },
            set: {
                preferences.setPomodoroConfiguration(
                    sessionsBeforeLongBreak: $0
                )
            }
        )
    }
}

private struct DashboardSettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Cards")
                    .font(.headline)

                Spacer()

                Button("Reset") {
                    preferences.resetDashboard()
                }
                .buttonStyle(.borderless)
            }

            List {
                ForEach(preferences.dashboardOrder) { card in
                    HStack(spacing: 12) {
                        Image(systemName: card.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        Toggle(
                            card.title,
                            isOn: Binding(
                                get: {
                                    preferences.isDashboardCardVisible(card)
                                },
                                set: {
                                    preferences.setDashboardCard(
                                        card,
                                        isVisible: $0
                                    )
                                }
                            )
                        )

                        Spacer()

                        Image(systemName: "line.3.horizontal")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 18, height: 22)
                            .contentShape(Rectangle())
                            .accessibilityLabel("Drag to reorder")
                            .hoverHelp("Drag to reorder")
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: preferences.moveDashboardCards)
            }
            .listStyle(.inset)
            .frame(height: SettingsControlLayout.dashboardListHeight)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: SettingsControlLayout.dashboardListCornerRadius,
                    style: .continuous
                )
            )

            HStack(spacing: 14) {
                Text("Heatmap")
                    .font(.headline)

                Spacer()

                Picker("Color", selection: $preferences.heatmapTint) {
                    ForEach(HeatmapTint.allCases) { tint in
                        Label {
                            Text(tint.title)
                        } icon: {
                            Circle()
                                .fill(tint.color)
                        }
                        .tag(tint)
                    }
                }
                .labelsHidden()
                .frame(
                    width: SettingsControlLayout.standardTrailingWidth,
                    alignment: .trailing
                )
            }
        }
    }
}
