import AppKit
import SwiftUI

enum ActivitiesPageLayout {
    static let newActivityPlaceholder = "e.g. Thesis, Client work"
    static let contentMargin = MainPageLayout.contentInset
    static let autohidesVerticalScroller = false
    static let reservedVerticalScrollerWidth = NSScroller.scrollerWidth(
        for: .regular,
        scrollerStyle: .legacy
    )
    static let maximumContentWidth =
        MainPageLayout.standardMaximumContentWidth - reservedVerticalScrollerWidth
    static let nativeListLeadingInset: CGFloat = 8
    static let nativeListTrailingInset: CGFloat = 9

    static var appliedLeadingContentMargin: CGFloat {
        contentMargin - nativeListLeadingInset
    }

    static var appliedTrailingContentMargin: CGFloat {
        contentMargin - nativeListTrailingInset
    }
}

struct TasksView: View {
    @EnvironmentObject private var store: WorkTimerStore
    @State private var newTaskName = ""
    @State private var itemEditor: ActivityItemEditorRequest?

    var body: some View {
        List {
            ActivitiesAlignedRow {
                newActivityCard
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

            Section {
                if store.availableTasks.isEmpty {
                    ActivitiesAlignedRow {
                        EmptyTasksRow(
                            systemImage: "tray",
                            message: "Add an activity or restore one from the archive."
                        )
                        .padding(22)
                        .workCard()
                    }
                    .listRowInsets(
                        EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.availableTasks) { task in
                        ActivitiesAlignedRow {
                            ActivityManagementRow(
                                task: task,
                                addItem: { kind in
                                    itemEditor = ActivityItemEditorRequest(
                                        activityID: task.id,
                                        kind: kind
                                    )
                                },
                                editItem: { item in
                                    itemEditor = ActivityItemEditorRequest(
                                        activityID: task.id,
                                        kind: item.kind,
                                        item: item
                                    )
                                }
                            )
                            .padding(22)
                            .workCard()
                        }
                        .listRowInsets(
                            EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove(perform: store.moveTasks)
                }
            } header: {
                ActivitiesAlignedRow {
                    HStack {
                        Text("Active")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text("\(store.availableTasks.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .textCase(nil)
                }
            }

            if !store.archivedTasks.isEmpty {
                ActivitiesAlignedRow {
                    archivedActivitiesCard
                }
                .listRowInsets(
                    EdgeInsets(top: 14, leading: 0, bottom: 0, trailing: 0)
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Activities")
        .sheet(item: $itemEditor) { request in
            ActivityItemEditorSheet(request: request)
                .environmentObject(store)
        }
    }

    private var newActivityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("New Activity", systemImage: "plus.circle.fill")
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                TextField(
                    ActivitiesPageLayout.newActivityPlaceholder,
                    text: $newTaskName
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTask)

                Button(action: addTask) {
                    Label("Add Activity", systemImage: "plus")
                }
                .workProminentButtonStyle()
                .tint(.indigo)
                .disabled(cleanedNewTaskName.isEmpty)
            }
        }
        .padding(22)
        .workCard()
    }

    private var archivedActivitiesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Archived")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(store.archivedTasks.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ForEach(store.archivedTasks) { task in
                ArchivedTaskRow(task: task)

                if task.id != store.archivedTasks.last?.id {
                    Divider()
                }
            }
        }
        .padding(22)
        .workCard()
    }

    private var cleanedNewTaskName: String {
        newTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addTask() {
        guard store.addTask(named: newTaskName) != nil else {
            return
        }
        newTaskName = ""
    }
}

struct ActivitiesAlignedRow<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            content.frame(maxWidth: ActivitiesPageLayout.maximumContentWidth)
            Spacer(minLength: 0)
        }
        .padding(
            .leading,
            ActivitiesPageLayout.appliedLeadingContentMargin
        )
        .padding(
            .trailing,
            ActivitiesPageLayout.appliedTrailingContentMargin
        )
    }
}

struct ActivitiesScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> ScrollViewProbe {
        ScrollViewProbe()
    }

    func updateNSView(_ view: ScrollViewProbe, context: Context) {
        view.configureEnclosingScrollView()
    }

    final class ScrollViewProbe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureEnclosingScrollView()
        }

        func configureEnclosingScrollView() {
            DispatchQueue.main.async { [weak self] in
                guard let scrollView = self?.enclosingScrollView else {
                    return
                }
                scrollView.hasVerticalScroller = true
                scrollView.autohidesScrollers = ActivitiesPageLayout
                    .autohidesVerticalScroller
            }
        }
    }
}

private struct ActivityManagementRow: View {
    @EnvironmentObject private var store: WorkTimerStore
    let task: WorkTask
    let addItem: (ActivityItemKind) -> Void
    let editItem: (ActivityItem) -> Void
    @State private var isEditingName = false

    init(
        task: WorkTask,
        addItem: @escaping (ActivityItemKind) -> Void,
        editItem: @escaping (ActivityItem) -> Void
    ) {
        self.task = task
        self.addItem = addItem
        self.editItem = editItem
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 14, height: 22)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Drag to reorder")
                        .hoverHelp("Drag to reorder")

                    Button {
                        store.selectTask(id: task.id)
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? Color.indigo : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.activeWork != nil)
                    .help(isSelected ? "Selected for the next activity" : "Select this activity")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        HStack(spacing: 7) {
                            Text(
                                WorkFormatting.readable(
                                    store.totalDuration(forTaskID: task.id, at: context.date)
                                )
                            )
                            .monospacedDigit()
                            Text("•")
                        Text(recordCountLabel)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    if isSelected {
                        Text("NEXT")
                            .font(.caption2.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.11), in: Capsule())
                    }

                    Button {
                        isEditingName = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit")
                    .hoverHelp("Edit")

                    Button {
                        store.archiveTask(id: task.id)
                    } label: {
                        Image(systemName: "archivebox")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(store.activeWork?.taskID == task.id)
                    .accessibilityLabel("Archive")
                    .hoverHelp("Archive")
                }

                ActivityItemsSection(
                    activityID: task.id,
                    date: context.date,
                    addItem: addItem,
                    editItem: editItem
                )
                .padding(.leading, 50)
            }
            .padding(.vertical, 7)
        }
        .sheet(isPresented: $isEditingName) {
            ActivityNameEditorSheet(task: task)
                .environmentObject(store)
        }
    }

    private var isSelected: Bool {
        store.selectedTaskID == task.id
    }

    private var recordCountLabel: String {
        let count = store.sessionCount(forTaskID: task.id)
        return "\(count) \(count == 1 ? "record" : "records")"
    }
}

private struct ActivityNameEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkTimerStore
    let task: WorkTask

    @State private var name: String
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    init(task: WorkTask) {
        self.task = task
        _name = State(initialValue: task.name)
    }

    private var cleanedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Activity")
                .font(.title3.weight(.semibold))

            TextField("Activity name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)
                .onSubmit(save)
                .onChange(of: name) { _ in
                    errorMessage = nil
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .workGlassSecondaryButtonStyle()

                Button("Save", action: save)
                    .workProminentButtonStyle()
                    .tint(.indigo)
                    .keyboardShortcut(.defaultAction)
                    .disabled(cleanedName.isEmpty || cleanedName == task.name)
            }
        }
        .padding(22)
        .frame(width: 380)
        .onAppear {
            isNameFocused = true
        }
    }

    private func save() {
        guard store.renameTask(id: task.id, to: cleanedName) else {
            errorMessage = "Choose a unique activity name."
            return
        }
        dismiss()
    }
}

private struct ActivityItemsSection: View {
    @EnvironmentObject private var store: WorkTimerStore
    let activityID: UUID
    let date: Date
    let addItem: (ActivityItemKind) -> Void
    let editItem: (ActivityItem) -> Void

    private var tasks: [ActivityItem] {
        store.openActivityTasks(for: activityID)
    }

    private var routines: [ActivityItem] {
        store.routines(for: activityID)
    }

    private var completed: [ActivityItem] {
        store.completedActivityTasks(for: activityID)
    }

    private var orderedItems: [ActivityItem] {
        store.reorderableActivityItems(for: activityID)
    }

    private var itemListHeight: CGFloat {
        let contentHeight = orderedItems.reduce(CGFloat.zero) { height, item in
            height + (item.schedule == nil ? 38 : 52)
        }
        return min(240, max(38, contentHeight + 4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack(spacing: 8) {
                Text("\(tasks.count) Tasks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("\(routines.count) Routines")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    addItem(.task)
                } label: {
                    Label("Task", systemImage: "plus")
                }
                .workSecondaryButtonStyle()
                .controlSize(.small)

                Button {
                    addItem(.routine)
                } label: {
                    Label("Routine", systemImage: "plus")
                }
                .workSecondaryButtonStyle()
                .controlSize(.small)
            }

            if !orderedItems.isEmpty {
                List {
                    ForEach(orderedItems) { item in
                        ActivityItemRow(
                            item: item,
                            date: date,
                            edit: { editItem(item) }
                        )
                        .listRowInsets(
                            EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove { sourceOffsets, destination in
                        store.moveActivityItems(
                            for: activityID,
                            fromOffsets: sourceOffsets,
                            toOffset: destination
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: itemListHeight)
            }

            if tasks.isEmpty && routines.isEmpty && completed.isEmpty {
                Text("No tasks or routines")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 3)
            }

            if !completed.isEmpty {
                DisclosureGroup("Completed \(completed.count)") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(completed) { item in
                            CompletedActivityTaskRow(item: item, date: date)
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ActivityItemRow: View {
    @EnvironmentObject private var store: WorkTimerStore
    let item: ActivityItem
    let date: Date
    let edit: () -> Void
    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 14, height: 22)
                .contentShape(Rectangle())
                .accessibilityLabel("Drag to reorder")
                .hoverHelp("Drag to reorder")

            Button {
                toggleCompletion()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canToggleCompletion)
            .accessibilityLabel(completionActionTitle)
            .hoverHelp(completionActionTitle)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    Text(item.kind.title.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(item.kind == .task ? Color.secondary : Color.indigo)
                }

                if let schedule = item.schedule {
                    Text(schedule.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if item.kind == .routine {
                Button {
                    store.setRoutinePaused(id: item.id, isPaused: !item.isPaused)
                } label: {
                    Image(systemName: item.isPaused ? "play.circle" : "pause.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(item.isPaused ? "Resume" : "Pause")
                .hoverHelp(item.isPaused ? "Resume" : "Pause")
            }

            Button(action: edit) {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.borderless)
            .disabled(store.activeWork?.activityItemID == item.id)
            .accessibilityLabel("Edit")
            .hoverHelp("Edit")

            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(!store.canDeleteActivityItem(id: item.id))
            .accessibilityLabel("Delete")
            .hoverHelp("Delete")
        }
        .padding(.vertical, 2)
        .confirmationDialog(
            "Delete \(item.title)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.deleteActivityItem(id: item.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Existing History records keep this name.")
        }
    }

    private var isCompleted: Bool {
        switch item.kind {
        case .task:
            return item.completedAt != nil
        case .routine:
            return item.completedOccurrenceKeyForCurrentCycle(at: date) != nil
        }
    }

    private var canToggleCompletion: Bool {
        guard store.activeWork?.activityItemID != item.id else {
            return false
        }

        if isCompleted || item.kind == .task {
            return true
        }
        return item.occurrenceKeyForCurrentCycle(at: date) != nil
    }

    private var completionActionTitle: String {
        isCompleted ? "Restore" : "Complete"
    }

    private func toggleCompletion() {
        if isCompleted {
            store.restoreActivityItem(id: item.id, at: date)
        } else {
            store.completeActivityItem(id: item.id, at: date)
        }
    }
}

private struct CompletedActivityTaskRow: View {
    @EnvironmentObject private var store: WorkTimerStore
    let item: ActivityItem
    let date: Date
    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.restoreActivityItem(id: item.id, at: date)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restore")
            .hoverHelp("Restore")

            Text(item.title)
                .font(.subheadline)
                .strikethrough()
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete")
            .hoverHelp("Delete")
        }
        .confirmationDialog(
            "Delete \(item.title)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.deleteActivityItem(id: item.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Existing History records keep this name.")
        }
    }
}

private struct ActivityItemEditorRequest: Identifiable {
    let id = UUID()
    let activityID: UUID
    let kind: ActivityItemKind
    var item: ActivityItem?
}

private struct ActivityItemEditorSheet: View {
    @EnvironmentObject private var store: WorkTimerStore
    @Environment(\.dismiss) private var dismiss

    let request: ActivityItemEditorRequest
    @State private var title: String
    @State private var schedule: RoutineSchedule
    @State private var saveFailed = false

    init(request: ActivityItemEditorRequest) {
        self.request = request
        _title = State(initialValue: request.item?.title ?? "")
        _schedule = State(
            initialValue: request.item?.schedule
                ?? RoutineSchedule(anchorDate: Date())
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(editorTitle, systemImage: request.kind.systemImage)
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            TextField(request.kind.title, text: $title)
                .textFieldStyle(.roundedBorder)

            if request.kind == .routine {
                Divider()
                RoutineScheduleEditor(schedule: $schedule)
            }

            if saveFailed {
                Text("Not saved")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .workGlassSecondaryButtonStyle()

                Button("Save") {
                    save()
                }
                .workProminentButtonStyle()
                .tint(.indigo)
                .keyboardShortcut(.defaultAction)
                .disabled(cleanedTitle.isEmpty || (request.kind == .routine && !schedule.isValid))
            }
        }
        .padding(24)
        .frame(width: 570)
    }

    private var editorTitle: String {
        "\(request.item == nil ? "New" : "Edit") \(request.kind.title)"
    }

    private var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let didSave: Bool

        if let item = request.item {
            didSave = store.updateActivityItem(
                id: item.id,
                title: title,
                schedule: request.kind == .routine ? schedule : nil
            )
        } else if request.kind == .task {
            didSave = store.addActivityTask(
                named: title,
                to: request.activityID
            ) != nil
        } else {
            didSave = store.addRoutine(
                named: title,
                to: request.activityID,
                schedule: schedule
            ) != nil
        }

        if didSave {
            dismiss()
        } else {
            saveFailed = true
        }
    }
}

private struct RoutineScheduleEditor: View {
    @Binding var schedule: RoutineSchedule

    private let weekdayColumns = Array(
        repeating: GridItem(.flexible(), spacing: 7),
        count: 7
    )
    private let dateColumns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 8
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkSegmentedPicker(
                accessibilityName: "Frequency",
                selection: $schedule.frequency,
                options: RoutineFrequency.allCases,
                title: { $0.title },
                surfaceStyle: .glass
            )

            HStack(spacing: 12) {
                Text("Every")
                    .font(.subheadline.weight(.medium))

                Stepper(value: $schedule.interval, in: 1...24) {
                    Text(intervalLabel)
                        .monospacedDigit()
                        .frame(minWidth: 88, alignment: .leading)
                }
                .fixedSize()

                Spacer()
            }

            switch schedule.frequency {
            case .day:
                EmptyView()
            case .week:
                weekdayPicker(selection: $schedule.weekdays, allowsMultiple: true)
            case .month:
                monthEditor
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Next")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(schedule.nextDates(startingAt: Date()), id: \.self) { date in
                        Text(WorkFormatting.compactDate(date))
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.indigo.opacity(0.1), in: Capsule())
                    }

                    if schedule.nextDates(startingAt: Date()).isEmpty {
                        Text("Choose a date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var intervalLabel: String {
        let unit = schedule.frequency.intervalUnit
        return "\(schedule.interval) \(unit)\(schedule.interval == 1 ? "" : "s")"
    }

    private var monthEditor: some View {
        VStack(alignment: .leading, spacing: 13) {
            WorkSegmentedPicker(
                accessibilityName: "Month",
                selection: $schedule.monthMode,
                options: RoutineMonthMode.allCases,
                title: { $0.title },
                surfaceStyle: .glass
            )

            switch schedule.monthMode {
            case .dates:
                LazyVGrid(columns: dateColumns, spacing: 7) {
                    ForEach(1...31, id: \.self) { day in
                        ScheduleChip(
                            title: "\(day)",
                            isSelected: schedule.monthDates.contains(day)
                        ) {
                            toggle(day, in: &schedule.monthDates)
                        }
                    }

                    ScheduleChip(
                        title: "Last",
                        isSelected: schedule.includesLastDay
                    ) {
                        schedule.includesLastDay.toggle()
                    }
                }

            case .pattern:
                WorkSegmentedPicker(
                    accessibilityName: "Ordinal",
                    selection: $schedule.ordinal,
                    options: RoutineOrdinal.allCases,
                    title: { $0.title },
                    surfaceStyle: .glass
                )

                weekdayPicker(
                    selection: Binding(
                        get: { [schedule.ordinalWeekday] },
                        set: { schedule.ordinalWeekday = $0.first ?? 2 }
                    ),
                    allowsMultiple: false
                )
            }
        }
    }

    private func weekdayPicker(
        selection: Binding<[Int]>,
        allowsMultiple: Bool
    ) -> some View {
        LazyVGrid(columns: weekdayColumns, spacing: 7) {
            ForEach(1...7, id: \.self) { weekday in
                ScheduleChip(
                    title: RoutineSchedule.shortWeekdayName(weekday),
                    isSelected: selection.wrappedValue.contains(weekday)
                ) {
                    if allowsMultiple {
                        var values = selection.wrappedValue
                        toggle(weekday, in: &values)
                        selection.wrappedValue = values
                    } else {
                        selection.wrappedValue = [weekday]
                    }
                }
            }
        }
    }

    private func toggle(_ value: Int, in values: inout [Int]) {
        if let index = values.firstIndex(of: value) {
            values.remove(at: index)
        } else {
            values.append(value)
            values.sort()
        }
    }
}

private struct ScheduleChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.indigo : Color.primary.opacity(0.06),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? Color.indigo : Color.primary.opacity(0.1),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

private struct ArchivedTaskRow: View {
    @EnvironmentObject private var store: WorkTimerStore
    let task: WorkTask
    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "archivebox.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.subheadline.weight(.semibold))

                Text(archiveSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.restoreTask(id: task.id)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Restore")
            .hoverHelp("Restore")

            if store.canDeleteTask(id: task.id) {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete")
                .hoverHelp("Delete")
            }
        }
        .padding(.vertical, 5)
        .alert(
            "Delete \(task.name)?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteTask(id: task.id)
            }
        } message: {
            Text(deleteMessage)
        }
    }

    private var archiveSummary: String {
        let count = store.sessionCount(forTaskID: task.id)
        let itemCount = store.activityItems(for: task.id).count
        let time = WorkFormatting.readable(store.totalDuration(forTaskID: task.id))
        let itemText = itemCount == 1 ? "1 item" : "\(itemCount) items"
        return "\(time) • \(count) \(count == 1 ? "record" : "records") • \(itemText)"
    }

    private var deleteMessage: String {
        let count = store.sessionCount(forTaskID: task.id)
        guard count > 0 else {
            return "This permanently deletes the activity and its tasks and routines."
        }
        return "This permanently deletes the activity and its \(count) work \(count == 1 ? "record" : "records")."
    }
}

private struct EmptyTasksRow: View {
    let systemImage: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }
}
