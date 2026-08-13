import SwiftUI

struct SessionInputLayout {
    static let fieldSpacing: CGFloat = 10
    static let groupSpacing: CGFloat = 28

    static let dateWidth: CGFloat = 96
    static let timeWidth: CGFloat = 108
    static let anchorWidth: CGFloat = 140

    static var timestampWidth: CGFloat {
        dateWidth + timeWidth + anchorWidth + fieldSpacing * 2
    }

    static var durationWidth: CGFloat {
        SessionDurationLayout.width
    }

    static var combinedWidth: CGFloat {
        timestampWidth + groupSpacing + durationWidth
    }
}

struct SessionDurationLayout {
    static let hoursWidth: CGFloat = 76
    static let minutesWidth: CGFloat = 76
    static let fieldSpacing: CGFloat = 10
    static let minuteStepSpacing: CGFloat = 8
    static let stepButtonWidth: CGFloat = 32

    static var width: CGFloat {
        hoursWidth + fieldSpacing + minutesWidth
            + minuteStepSpacing + stepButtonWidth
    }
}

struct DurationPickerLayout {
    static let columnWidth: CGFloat = 88
    static let columnHeight: CGFloat = 168
    static let columnSpacing: CGFloat = 10
    static let triggerWidth: CGFloat = 118

    static var contentWidth: CGFloat {
        columnWidth * 3 + columnSpacing * 2
    }
}

enum SessionInputTime {
    static func minutePrecision(_ date: Date) -> Date {
        let minute = floor(date.timeIntervalSinceReferenceDate / 60) * 60
        return Date(timeIntervalSinceReferenceDate: minute)
    }

    static func replacingDate(in timestamp: Date, with date: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let clock = calendar.dateComponents([.hour, .minute], from: timestamp)
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = clock.hour
        components.minute = clock.minute
        return calendar.date(from: components) ?? minutePrecision(date)
    }

    static func replacingHour(in timestamp: Date, with hour: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: hour,
            minute: calendar.component(.minute, from: timestamp),
            second: 0,
            of: timestamp
        ) ?? timestamp
    }

    static func replacingMinute(in timestamp: Date, with minute: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: timestamp),
            minute: minute,
            second: 0,
            of: timestamp
        ) ?? timestamp
    }
}

struct SessionInputControls: View {
    @Binding var timestamp: Date
    @Binding var anchor: SessionTimeAnchor
    @Binding var hours: Int
    @Binding var minutes: Int

    var body: some View {
        HStack(alignment: .top, spacing: SessionInputLayout.groupSpacing) {
            SessionTimestampControls(
                timestamp: $timestamp,
                anchor: $anchor
            )

            SessionDurationControls(
                hours: $hours,
                minutes: $minutes
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct SessionTimestampControls: View {
    @Binding var timestamp: Date
    @Binding var anchor: SessionTimeAnchor

    @State private var isChoosingDate = false
    @State private var isChoosingHour = false
    @State private var isChoosingMinute = false

    private var hour: Int {
        Calendar.current.component(.hour, from: timestamp)
    }

    private var minute: Int {
        Calendar.current.component(.minute, from: timestamp)
    }

    var body: some View {
        HStack(alignment: .top, spacing: SessionInputLayout.fieldSpacing) {
            compactField(title: "Date", width: SessionInputLayout.dateWidth) {
                Button {
                    isChoosingDate.toggle()
                } label: {
                    Text(WorkFormatting.compactDate(timestamp))
                        .fixedSize()
                }
                .workSecondaryButtonStyle()
                .accessibilityLabel("Date")
                .accessibilityValue(WorkFormatting.compactDate(timestamp))
                .popover(isPresented: $isChoosingDate, arrowEdge: .bottom) {
                    DatePicker(
                        "Date",
                        selection: dateBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(12)
                }
            }

            compactField(title: "Time", width: SessionInputLayout.timeWidth) {
                HStack(spacing: 6) {
                    ZStack {
                        Text(String(format: "%02d:%02d", hour, minute))
                            .font(.body.monospacedDigit())

                        HStack(spacing: 0) {
                            Button {
                                isChoosingHour.toggle()
                            } label: {
                                Color.clear
                                    .frame(width: 25, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Hour")
                            .accessibilityValue("\(hour)")
                            .popover(isPresented: $isChoosingHour, arrowEdge: .bottom) {
                                ClockValuePicker(
                                    values: Array(0..<24),
                                    selection: hourBinding,
                                    accessibilityName: "Hour"
                                )
                                .padding(8)
                            }

                            Button {
                                isChoosingMinute.toggle()
                            } label: {
                                Color.clear
                                    .frame(width: 25, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Minute")
                            .accessibilityValue("\(minute)")
                            .popover(isPresented: $isChoosingMinute, arrowEdge: .bottom) {
                                ClockValuePicker(
                                    values: Array(0..<60),
                                    selection: minuteBinding,
                                    accessibilityName: "Minute"
                                )
                                .padding(8)
                            }
                        }
                    }
                    .frame(height: 28)
                    .background(
                        Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                    }

                    Button("Now") {
                        timestamp = SessionInputTime.minutePrecision(Date())
                    }
                    .workSecondaryButtonStyle()
                    .help("Use the current date and time")
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            compactField(title: "Set As", width: SessionInputLayout.anchorWidth) {
                WorkSegmentedPicker(
                    accessibilityName: "Set As",
                    selection: $anchor,
                    options: SessionTimeAnchor.allCases,
                    title: { $0.rawValue },
                    height: 28
                )
            }

        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { timestamp },
            set: { date in
                timestamp = SessionInputTime.replacingDate(in: timestamp, with: date)
            }
        )
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { hour },
            set: { value in
                timestamp = SessionInputTime.replacingHour(in: timestamp, with: value)
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { minute },
            set: { value in
                timestamp = SessionInputTime.replacingMinute(in: timestamp, with: value)
            }
        )
    }

    private func compactField<Content: View>(
        title: String,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
        }
        .frame(width: width, alignment: .leading)
    }
}

struct SessionDurationControls: View {
    @Binding var hours: Int
    @Binding var minutes: Int

    @AppStorage(ManualDurationOptions.stepPreferenceKey)
    private var step = ManualDurationOptions.defaultMinuteStep
    @State private var isChoosingStep = false

    var body: some View {
        HStack(alignment: .bottom, spacing: SessionDurationLayout.fieldSpacing) {
            durationField(
                title: "Hours",
                width: SessionDurationLayout.hoursWidth
            ) {
                Picker("Hours", selection: $hours) {
                    ForEach(ManualDurationOptions.hours, id: \.self) { value in
                        Text("\(value) h").tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            HStack(alignment: .bottom, spacing: SessionDurationLayout.minuteStepSpacing) {
                durationField(
                    title: "Minutes",
                    width: SessionDurationLayout.minutesWidth
                ) {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(minuteChoices, id: \.self) { value in
                            Text("\(value) min").tag(value)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                Button {
                    isChoosingStep.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: SessionDurationLayout.stepButtonWidth)
                }
                .workSecondaryButtonStyle()
                .accessibilityLabel("Minute step")
                .accessibilityValue("\(step) minutes")
                .help("Sets the interval shown in Minutes.")
                .popover(isPresented: $isChoosingStep, arrowEdge: .bottom) {
                    MinuteStepEditor(step: $step)
                        .padding(12)
                }
            }
        }
        .frame(width: SessionDurationLayout.width, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear(perform: normalizeStep)
        .onChange(of: step) { newStep in
            let normalized = ManualDurationOptions.normalizedStep(newStep)
            guard normalized == newStep else {
                step = normalized
                return
            }
            minutes = ManualDurationOptions.snappedMinute(
                minutes,
                step: normalized
            )
        }
    }

    private var minuteChoices: [Int] {
        let choices = ManualDurationOptions.minutes(for: step)
        guard (0..<60).contains(minutes), !choices.contains(minutes) else {
            return choices
        }
        return (choices + [minutes]).sorted()
    }

    private func normalizeStep() {
        let normalized = ManualDurationOptions.normalizedStep(step)
        if step != normalized {
            step = normalized
        }
    }

    private func durationField<Content: View>(
        title: String,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct MinuteStepEditor: View {
    @Binding var step: Int
    @State private var draftStep: Int

    init(step: Binding<Int>) {
        _step = step
        _draftStep = State(
            initialValue: ManualDurationOptions.normalizedStep(
                step.wrappedValue
            )
        )
    }

    private var enteredStep: Int? {
        guard ManualDurationOptions.minuteStepRange.contains(draftStep) else {
            return nil
        }
        return draftStep
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Minute Step")
                .font(.headline)

            Text("Sets the interval shown in Minutes.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("Step", value: $draftStep, format: .number)
                    .frame(width: 54)
                    .onSubmit(commitDraft)

                Text("min")
                    .foregroundStyle(.secondary)

                Stepper(
                    "Step",
                    value: $draftStep,
                    in: ManualDurationOptions.minuteStepRange
                )
                    .labelsHidden()
            }

            HStack {
                Text("1–59 min")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Set", action: commitDraft)
                    .disabled(enteredStep == nil)
            }
        }
        .frame(width: 190)
        .onChange(of: step) { value in
            draftStep = ManualDurationOptions.normalizedStep(value)
        }
    }

    private func commitDraft() {
        guard let enteredStep else {
            return
        }
        step = enteredStep
    }
}

struct DurationPicker: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var step: Int

    var body: some View {
        HStack(alignment: .top, spacing: DurationPickerLayout.columnSpacing) {
            DurationValueColumn(
                title: "Hours",
                values: ManualDurationOptions.hours,
                selection: $hours,
                suffix: "h"
            )

            DurationValueColumn(
                title: "Minutes",
                values: minuteChoices,
                selection: $minutes,
                suffix: "min"
            )

            DurationValueColumn(
                title: "Step",
                values: Array(ManualDurationOptions.minuteStepRange),
                selection: $step,
                suffix: "min"
            )
        }
        .frame(width: DurationPickerLayout.contentWidth)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Duration")
        .onAppear(perform: normalizeStep)
        .onChange(of: step) { newStep in
            let normalized = ManualDurationOptions.normalizedStep(newStep)
            guard normalized == newStep else {
                step = normalized
                return
            }
            minutes = ManualDurationOptions.snappedMinute(
                minutes,
                step: normalized
            )
        }
    }

    private var minuteChoices: [Int] {
        let choices = ManualDurationOptions.minutes(for: step)
        guard (0..<60).contains(minutes), !choices.contains(minutes) else {
            return choices
        }
        return (choices + [minutes]).sorted()
    }

    private func normalizeStep() {
        let normalized = ManualDurationOptions.normalizedStep(step)
        if step != normalized {
            step = normalized
        }
    }
}

private struct DurationValueColumn: View {
    let title: String
    let values: [Int]
    @Binding var selection: Int
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
                        ForEach(values, id: \.self) { value in
                            Button {
                                selection = value
                            } label: {
                                Text("\(value) \(suffix)")
                                    .font(.body.monospacedDigit().weight(
                                        selection == value
                                            ? .semibold
                                            : .regular
                                    ))
                                    .foregroundStyle(
                                        selection == value
                                            ? Color.white
                                            : Color.primary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 28)
                                    .background(
                                        selection == value
                                            ? Color.indigo
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6)
                                    )
                            }
                            .buttonStyle(.plain)
                            .id(value)
                            .accessibilityLabel("\(title) \(value)")
                        }
                    }
                    .padding(4)
                }
                .frame(
                    width: DurationPickerLayout.columnWidth,
                    height: DurationPickerLayout.columnHeight
                )
                .background(
                    Color(nsColor: .textBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 9)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo(selection, anchor: .center)
                    }
                }
                .onChange(of: selection) { value in
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(value, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct ClockValuePicker: View {
    let values: [Int]
    @Binding var selection: Int
    let accessibilityName: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 2) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            selection = value
                        } label: {
                            Text(String(format: "%02d", value))
                                .font(.body.monospacedDigit().weight(
                                    selection == value ? .semibold : .regular
                                ))
                                .foregroundStyle(
                                    selection == value ? Color.white : Color.primary
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 28)
                                .background(
                                    selection == value ? Color.indigo : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                        }
                        .buttonStyle(.plain)
                        .id(value)
                        .accessibilityLabel("\(accessibilityName) \(value)")
                    }
                }
                .padding(4)
            }
            .frame(width: 78, height: 168)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .onAppear {
                scroll(to: selection, using: proxy, animated: false)
            }
            .onChange(of: selection) { value in
                scroll(to: value, using: proxy, animated: true)
            }
        }
    }

    private func scroll(
        to value: Int,
        using proxy: ScrollViewProxy,
        animated: Bool
    ) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(value, anchor: .center)
                }
            } else {
                proxy.scrollTo(value, anchor: .center)
            }
        }
    }
}
