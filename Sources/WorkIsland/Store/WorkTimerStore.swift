import Combine
import Foundation

enum WorkDataTransferError: LocalizedError {
    case activeTimer
    case unsupportedSchema(Int)
    case invalidFile(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .activeTimer:
            return "Pause and finish or discard the current timer before importing data."
        case let .unsupportedSchema(version):
            return "This backup uses unsupported data version \(version)."
        case let .invalidFile(message):
            return "The selected file is not a valid Work Island backup. \(message)"
        case let .writeFailed(message):
            return "Work Island could not save the imported data. \(message)"
        }
    }
}

final class WorkTimerStore: ObservableObject {
    @Published private(set) var sessions: [WorkSession] = []
    @Published private(set) var tasks: [WorkTask] = []
    @Published private(set) var activityItems: [ActivityItem] = []
    @Published private(set) var selectedTaskID: UUID?
    @Published private(set) var selectedActivityItemID: UUID?
    @Published private(set) var activeWork: ActiveWork?
    @Published private(set) var draftSubject = ""
    @Published private(set) var draftNote = ""
    @Published private(set) var persistenceError: String?

    let storageURL: URL
    let startedWithExistingData: Bool

    var importBackupURL: URL {
        storageURL
            .deletingLastPathComponent()
            .appendingPathComponent("work-data-before-import.json")
    }

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        startedWithExistingData = FileManager.default.fileExists(
            atPath: self.storageURL.path
        )

        if startedWithExistingData {
            if let schemaVersion = load(),
               migrateTaskLibrary(from: schemaVersion) {
                persist()
            }
        } else {
            seedDefaultTask()
            persist()
        }
    }

    var isRunning: Bool {
        activeWork?.isRunning == true
    }

    var isPaused: Bool {
        activeWork != nil && activeWork?.isRunning == false
    }

    var availableTasks: [WorkTask] {
        tasks
            .filter { !$0.isArchived }
            .sorted(by: taskSort)
    }

    var archivedTasks: [WorkTask] {
        tasks
            .filter(\.isArchived)
            .sorted(by: taskSort)
    }

    var historyTasks: [WorkTask] {
        tasks.sorted {
            if $0.isArchived != $1.isArchived {
                return !$0.isArchived
            }
            return taskSort($0, $1)
        }
    }

    var selectedTask: WorkTask? {
        guard let selectedTaskID else {
            return nil
        }
        return task(id: selectedTaskID)
    }

    var selectedActivityItem: ActivityItem? {
        guard let selectedActivityItemID else {
            return nil
        }
        return activityItem(id: selectedActivityItemID)
    }

    var activeActivityItem: ActivityItem? {
        guard let id = activeWork?.activityItemID else {
            return nil
        }
        return activityItem(id: id)
    }

    var canCompleteActiveItem: Bool {
        activeActivityItem != nil && activeWork?.countsAsWork == true
    }

    var canStart: Bool {
        activeWork == nil && selectedTask?.isArchived == false
    }

    func task(id: UUID) -> WorkTask? {
        tasks.first { $0.id == id }
    }

    func activityItem(id: UUID) -> ActivityItem? {
        activityItems.first { $0.id == id }
    }

    func activityItems(for activityID: UUID) -> [ActivityItem] {
        activityItems
            .filter { $0.activityID == activityID }
            .sorted(by: activityItemSort)
    }

    func reorderableActivityItems(for activityID: UUID) -> [ActivityItem] {
        activityItems(for: activityID).filter {
            $0.kind == .routine || $0.completedAt == nil
        }
    }

    func openActivityTasks(for activityID: UUID) -> [ActivityItem] {
        activityItems(for: activityID).filter {
            $0.kind == .task && $0.completedAt == nil
        }
    }

    func completedActivityTasks(for activityID: UUID) -> [ActivityItem] {
        activityItems(for: activityID)
            .filter { $0.kind == .task && $0.completedAt != nil }
            .sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
    }

    func routines(for activityID: UUID) -> [ActivityItem] {
        activityItems(for: activityID).filter { $0.kind == .routine }
    }

    func openRoutines(
        for activityID: UUID,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> [ActivityItem] {
        routines(for: activityID).filter {
            $0.completedOccurrenceKeyForCurrentCycle(
                at: date,
                calendar: calendar
            ) == nil
        }
    }

    func completedActivityItems(
        for activityID: UUID,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> [ActivityItem] {
        activityItems(for: activityID)
            .filter { item in
                switch item.kind {
                case .task:
                    return item.completedAt != nil
                case .routine:
                    return item.completedOccurrenceKeyForCurrentCycle(
                        at: date,
                        calendar: calendar
                    ) != nil
                }
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.completedAt
                    ?? lhs.completionDateForCurrentCycle(
                        at: date,
                        calendar: calendar
                    )
                    ?? .distantPast
                let rhsDate = rhs.completedAt
                    ?? rhs.completionDateForCurrentCycle(
                        at: date,
                        calendar: calendar
                    )
                    ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    func selectableActivityItems(
        for activityID: UUID,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> [ActivityItem] {
        activityItems(for: activityID).filter {
            $0.isSelectable(on: date, calendar: calendar)
        }
    }

    func selectableTasks(
        for activityID: UUID,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> [ActivityItem] {
        selectableActivityItems(for: activityID, at: date, calendar: calendar)
            .filter { $0.kind == .task }
    }

    func selectableRoutines(
        for activityID: UUID,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> [ActivityItem] {
        selectableActivityItems(for: activityID, at: date, calendar: calendar)
            .filter { $0.kind == .routine }
    }

    @discardableResult
    func addActivityTask(
        named value: String,
        to activityID: UUID,
        at date: Date = Date()
    ) -> ActivityItem? {
        guard task(id: activityID) != nil else {
            return nil
        }

        let title = cleanedTaskName(value)
        guard !title.isEmpty else {
            return nil
        }

        let item = ActivityItem(
            activityID: activityID,
            title: title,
            kind: .task,
            createdAt: date,
            sortOrder: nextActivityItemSortOrder(for: activityID)
        )
        activityItems.append(item)
        if activeWork == nil, selectedTaskID == activityID {
            selectedActivityItemID = item.id
        }
        persist()
        return item
    }

    @discardableResult
    func addRoutine(
        named value: String,
        to activityID: UUID,
        schedule: RoutineSchedule,
        at date: Date = Date()
    ) -> ActivityItem? {
        guard task(id: activityID) != nil, schedule.isValid else {
            return nil
        }

        let title = cleanedTaskName(value)
        guard !title.isEmpty else {
            return nil
        }

        let item = ActivityItem(
            activityID: activityID,
            title: title,
            kind: .routine,
            createdAt: date,
            sortOrder: nextActivityItemSortOrder(for: activityID),
            schedule: schedule
        )
        activityItems.append(item)
        if activeWork == nil,
           selectedTaskID == activityID,
           item.isSelectable(on: date) {
            selectedActivityItemID = item.id
        }
        persist()
        return item
    }

    @discardableResult
    func updateActivityItem(
        id: UUID,
        title value: String,
        schedule: RoutineSchedule? = nil
    ) -> Bool {
        let title = cleanedTaskName(value)
        guard !title.isEmpty,
              let index = activityItems.firstIndex(where: { $0.id == id }) else {
            return false
        }

        if activityItems[index].kind == .routine {
            guard let schedule, schedule.isValid else {
                return false
            }
            activityItems[index].schedule = schedule
        }
        activityItems[index].title = title

        for sessionIndex in sessions.indices where sessions[sessionIndex].activityItemID == id {
            sessions[sessionIndex].activityItemTitle = title
        }

        if var activeWork, activeWork.activityItemID == id {
            activeWork.activityItemTitle = title
            self.activeWork = activeWork
        }

        persist()
        return true
    }

    func selectActivityItem(
        id: UUID?,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard activeWork == nil else {
            return
        }

        guard let id else {
            selectedActivityItemID = nil
            persist()
            return
        }

        guard let item = activityItem(id: id),
              item.activityID == selectedTaskID,
              item.isSelectable(on: date, calendar: calendar) else {
            return
        }

        selectedActivityItemID = id
        persist()
    }

    func setRoutinePaused(id: UUID, isPaused: Bool) {
        guard let index = activityItems.firstIndex(where: {
            $0.id == id && $0.kind == .routine
        }) else {
            return
        }

        activityItems[index].isPaused = isPaused
        if isPaused, selectedActivityItemID == id {
            selectedActivityItemID = nil
        }
        persist()
    }

    func completeActivityTask(id: UUID, at date: Date = Date()) {
        guard activityItem(id: id)?.kind == .task else {
            return
        }

        _ = completeActivityItem(id: id, at: date)
    }

    @discardableResult
    func completeActivityItem(
        id: UUID,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let index = activityItems.firstIndex(where: { $0.id == id }),
              activeWork?.activityItemID != id else {
            return false
        }

        switch activityItems[index].kind {
        case .task:
            guard activityItems[index].completedAt == nil else {
                return false
            }
            activityItems[index].completedAt = date

        case .routine:
            guard let key = activityItems[index].occurrenceKeyForCurrentCycle(
                at: date,
                calendar: calendar
            ), !activityItems[index].completedOccurrenceKeys.contains(key) else {
                return false
            }
            activityItems[index].completedOccurrenceKeys.append(key)
            activityItems[index].completedOccurrenceKeys.sort()
        }

        if selectedActivityItemID == id {
            selectedActivityItemID = nil
        }
        persist()
        return true
    }

    func restoreActivityTask(id: UUID) {
        _ = restoreActivityItem(id: id)
    }

    @discardableResult
    func restoreActivityItem(
        id: UUID,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let index = activityItems.firstIndex(where: { $0.id == id }) else {
            return false
        }

        switch activityItems[index].kind {
        case .task:
            guard activityItems[index].completedAt != nil else {
                return false
            }
            activityItems[index].completedAt = nil

        case .routine:
            guard let key = activityItems[index]
                .completedOccurrenceKeyForCurrentCycle(
                    at: date,
                    calendar: calendar
                ) else {
                return false
            }
            activityItems[index].completedOccurrenceKeys.removeAll { $0 == key }
        }

        persist()
        return true
    }

    func canDeleteActivityItem(id: UUID) -> Bool {
        activityItem(id: id) != nil && activeWork?.activityItemID != id
    }

    func deleteActivityItem(id: UUID) {
        guard canDeleteActivityItem(id: id) else {
            return
        }

        activityItems.removeAll { $0.id == id }
        if selectedActivityItemID == id {
            selectedActivityItemID = nil
        }
        persist()
    }

    func moveActivityItems(
        for activityID: UUID,
        fromOffsets sourceOffsets: IndexSet,
        toOffset destination: Int
    ) {
        var visibleItems = reorderableActivityItems(for: activityID)
        guard !sourceOffsets.isEmpty,
              sourceOffsets.allSatisfy(visibleItems.indices.contains),
              (0...visibleItems.count).contains(destination) else {
            return
        }

        let movingItems = sourceOffsets.map { visibleItems[$0] }
        for index in sourceOffsets.reversed() {
            visibleItems.remove(at: index)
        }

        let removedBeforeDestination = sourceOffsets.filter {
            $0 < destination
        }.count
        let insertionIndex = min(
            max(0, destination - removedBeforeDestination),
            visibleItems.count
        )
        visibleItems.insert(contentsOf: movingItems, at: insertionIndex)

        var allItems = activityItems(for: activityID)
        let visibleIDs = Set(visibleItems.map(\.id))
        let visibleSlots = allItems.indices.filter {
            visibleIDs.contains(allItems[$0].id)
        }

        for (slot, item) in zip(visibleSlots, visibleItems) {
            allItems[slot] = item
        }

        applyActivityItemOrder(allItems)
        persist()
    }

    @discardableResult
    func addTask(named value: String, at date: Date = Date()) -> WorkTask? {
        let name = cleanedTaskName(value)
        guard !name.isEmpty else {
            return nil
        }

        if let index = tasks.firstIndex(where: {
            normalizedTaskKey($0.name) == normalizedTaskKey(name)
        }) {
            if tasks[index].isArchived {
                tasks[index].isArchived = false
            }
            if activeWork == nil {
                selectedTaskID = tasks[index].id
                selectedActivityItemID = nil
                draftSubject = tasks[index].name
            }
            persist()
            return tasks[index]
        }

        let newTask = WorkTask(
            name: name,
            createdAt: date,
            sortOrder: nextTaskSortOrder
        )
        tasks.append(newTask)
        if activeWork == nil {
            selectedTaskID = newTask.id
            selectedActivityItemID = nil
            draftSubject = newTask.name
        }
        persist()
        return newTask
    }

    @discardableResult
    func renameTask(id: UUID, to value: String) -> Bool {
        let name = cleanedTaskName(value)
        guard !name.isEmpty,
              let index = tasks.firstIndex(where: { $0.id == id }),
              !tasks.contains(where: {
                  $0.id != id && normalizedTaskKey($0.name) == normalizedTaskKey(name)
              }) else {
            return false
        }

        tasks[index].name = name

        for sessionIndex in sessions.indices where sessions[sessionIndex].taskID == id {
            sessions[sessionIndex].subject = name
        }

        if var activeWork, activeWork.taskID == id {
            activeWork.subject = name
            self.activeWork = activeWork
        }

        if selectedTaskID == id {
            draftSubject = name
        }

        persist()
        return true
    }

    func selectTask(id: UUID) {
        guard activeWork == nil,
              let task = task(id: id),
              !task.isArchived else {
            return
        }

        selectedTaskID = task.id
        if selectedActivityItem?.activityID != task.id {
            selectedActivityItemID = nil
        }
        draftSubject = task.name
        persist()
    }

    func archiveTask(id: UUID) {
        guard activeWork?.taskID != id,
              let index = tasks.firstIndex(where: { $0.id == id }) else {
            return
        }

        tasks[index].isArchived = true
        if selectedTaskID == id {
            selectedTaskID = availableTasks.first?.id
            selectedActivityItemID = nil
            draftSubject = selectedTask?.name ?? ""
        }
        persist()
    }

    func restoreTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            return
        }

        tasks[index].isArchived = false
        if selectedTaskID == nil, activeWork == nil {
            selectedTaskID = id
            selectedActivityItemID = nil
            draftSubject = tasks[index].name
        }
        persist()
    }

    func moveTasks(
        fromOffsets sourceOffsets: IndexSet,
        toOffset destination: Int
    ) {
        var orderedTasks = availableTasks
        guard !sourceOffsets.isEmpty,
              sourceOffsets.allSatisfy(orderedTasks.indices.contains),
              (0...orderedTasks.count).contains(destination) else {
            return
        }

        let movingTasks = sourceOffsets.map { orderedTasks[$0] }
        for index in sourceOffsets.reversed() {
            orderedTasks.remove(at: index)
        }

        let removedBeforeDestination = sourceOffsets.filter {
            $0 < destination
        }.count
        let insertionIndex = min(
            max(0, destination - removedBeforeDestination),
            orderedTasks.count
        )
        orderedTasks.insert(contentsOf: movingTasks, at: insertionIndex)
        applyTaskOrder(orderedTasks)
        persist()
    }

    func canDeleteTask(id: UUID) -> Bool {
        guard let task = task(id: id), task.isArchived else {
            return false
        }
        return !activeWorkBelongs(to: id)
    }

    func deleteTask(id: UUID) {
        guard canDeleteTask(id: id) else {
            return
        }

        sessions.removeAll { sessionBelongs($0, to: id) }
        activityItems.removeAll { $0.activityID == id }
        tasks.removeAll { $0.id == id }
        if selectedTaskID == id {
            selectedTaskID = availableTasks.first?.id
            selectedActivityItemID = nil
            draftSubject = selectedTask?.name ?? ""
        }
        persist()
    }

    func updateNote(_ value: String) {
        draftNote = value
        if var activeWork {
            activeWork.note = value
            self.activeWork = activeWork
        }
        persist()
    }

    func start(at date: Date = Date()) {
        _ = startActiveWork(
            mode: .stopwatch,
            plannedDuration: nil,
            pomodoro: nil,
            at: date
        )
    }

    @discardableResult
    func startTimer(
        duration: TimeInterval,
        at date: Date = Date()
    ) -> Bool {
        guard duration.isFinite, duration > 0 else {
            return false
        }
        return startActiveWork(
            mode: .timer,
            plannedDuration: duration,
            pomodoro: nil,
            at: date
        )
    }

    @discardableResult
    func startPomodoro(
        configuration: PomodoroConfiguration,
        at date: Date = Date()
    ) -> Bool {
        let runtime = PomodoroRuntime(configuration: configuration)
        return startActiveWork(
            mode: .pomodoro,
            plannedDuration: configuration.duration(for: .focus),
            pomodoro: runtime,
            at: date
        )
    }

    @discardableResult
    private func startActiveWork(
        mode: ActiveActivityMode,
        plannedDuration: TimeInterval?,
        pomodoro: PomodoroRuntime?,
        at date: Date
    ) -> Bool {
        guard activeWork == nil else {
            return false
        }

        guard let task = selectedTask.flatMap({ $0.isArchived ? nil : $0 })
            ?? availableTasks.first else {
            return false
        }

        if mode != .stopwatch {
            guard let plannedDuration,
                  plannedDuration.isFinite,
                  plannedDuration > 0 else {
                return false
            }
        }

        selectedTaskID = task.id
        draftSubject = task.name
        let item = selectedActivityItem.flatMap { candidate in
            candidate.activityID == task.id && candidate.isSelectable(on: date)
                ? candidate
                : nil
        }
        if selectedActivityItemID != nil, item == nil {
            selectedActivityItemID = nil
        }
        activeWork = ActiveWork(
            id: UUID(),
            taskID: task.id,
            subject: task.name,
            activityItemID: item?.id,
            activityItemTitle: item?.title,
            activityItemKind: item?.kind,
            activityItemOccurrenceKey: item?.kind == .routine
                ? ActivityItem.occurrenceKey(for: date)
                : nil,
            note: draftNote.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: date,
            completedSegments: [],
            runningSince: date,
            activityMode: mode,
            plannedDuration: plannedDuration,
            pomodoro: pomodoro
        )
        persist()
        return true
    }

    func pause(at date: Date = Date()) {
        guard var activeWork, activeWork.isRunning else {
            return
        }

        activeWork.pause(at: date)
        self.activeWork = activeWork
        persist()
    }

    func resume(at date: Date = Date()) {
        guard var activeWork, !activeWork.isRunning else {
            return
        }

        activeWork.resume(at: date)
        self.activeWork = activeWork
        persist()
    }

    @discardableResult
    func discardPausedWork() -> Bool {
        guard activeWork != nil, !isRunning else {
            return false
        }

        activeWork = nil
        draftNote = ""
        persist()
        return true
    }

    @discardableResult
    func finish(at date: Date = Date()) -> WorkSession? {
        finishActiveWork(at: date, completingItem: false)
    }

    @discardableResult
    func finishAndComplete(at date: Date = Date()) -> WorkSession? {
        guard canCompleteActiveItem else {
            return nil
        }
        return finishActiveWork(at: date, completingItem: true)
    }

    @discardableResult
    private func finishActiveWork(
        at date: Date,
        completingItem: Bool
    ) -> WorkSession? {
        guard var activeWork else {
            return nil
        }

        let session: WorkSession?
        if activeWork.countsAsWork {
            let completedSession = activeWork.finish(at: date)
            appendSession(completedSession)
            session = completedSession
        } else {
            session = nil
        }

        if session != nil,
           completingItem,
           let itemID = activeWork.activityItemID,
           let index = activityItems.firstIndex(where: { $0.id == itemID }) {
            switch activityItems[index].kind {
            case .task:
                activityItems[index].completedAt = date
            case .routine:
                let key = activeWork.activityItemOccurrenceKey
                    ?? ActivityItem.occurrenceKey(for: date)
                if !activityItems[index].completedOccurrenceKeys.contains(key) {
                    activityItems[index].completedOccurrenceKeys.append(key)
                    activityItems[index].completedOccurrenceKeys.sort()
                }
            }

            if selectedActivityItemID == itemID {
                selectedActivityItemID = nil
            }
        }

        self.activeWork = nil
        draftNote = ""
        persist()
        return session
    }

    @discardableResult
    func completeTimedActivity(
        at date: Date = Date()
    ) -> TimedActivityCompletion? {
        guard var activeWork,
              activeWork.isRunning,
              let completionDate = activeWork.expectedCompletionDate(),
              date >= completionDate else {
            return nil
        }

        let activityTitle = activeWork.activityItemTitle.map {
            "\(activeWork.subject) · \($0)"
        } ?? activeWork.subject

        switch activeWork.resolvedMode {
        case .stopwatch:
            return nil
        case .timer:
            let session = activeWork.finish(at: completionDate)
            appendSession(session)
            self.activeWork = nil
            draftNote = ""
            persist()
            return TimedActivityCompletion(
                kind: .timer,
                activityTitle: activityTitle,
                completedAt: completionDate
            )
        case .pomodoro:
            guard var runtime = activeWork.pomodoro else {
                return nil
            }

            let completedPhase = runtime.phase
            if completedPhase.countsAsWork {
                let session = activeWork.finish(at: completionDate)
                appendSession(session)
            }

            let nextPhase = runtime.advance()
            self.activeWork = followupPomodoroWork(
                from: activeWork,
                runtime: runtime,
                startedAt: completionDate
            )
            draftNote = activeWork.note
            persist()

            return TimedActivityCompletion(
                kind: completedPhase.countsAsWork
                    ? .focus(next: nextPhase)
                    : .breakTime(next: nextPhase),
                activityTitle: activityTitle,
                completedAt: completionDate
            )
        }
    }

    private func appendSession(_ session: WorkSession) {
        sessions.append(session)
        sessions.sort { $0.endedAt > $1.endedAt }
    }

    private func followupPomodoroWork(
        from previous: ActiveWork,
        runtime: PomodoroRuntime,
        startedAt: Date
    ) -> ActiveWork {
        ActiveWork(
            id: UUID(),
            taskID: previous.taskID,
            subject: previous.subject,
            activityItemID: previous.activityItemID,
            activityItemTitle: previous.activityItemTitle,
            activityItemKind: previous.activityItemKind,
            activityItemOccurrenceKey: previous.activityItemOccurrenceKey,
            note: previous.note,
            startedAt: startedAt,
            completedSegments: [],
            runningSince: startedAt,
            activityMode: .pomodoro,
            plannedDuration: runtime.configuration.duration(
                for: runtime.phase
            ),
            pomodoro: runtime
        )
    }

    @discardableResult
    func addManualSession(
        duration: TimeInterval,
        endedAt: Date = Date(),
        taskID: UUID? = nil,
        activityItemID: UUID? = nil,
        usesSelectedActivityItemWhenNil: Bool = true,
        note: String = ""
    ) -> WorkSession? {
        return addManualSession(
            duration: duration,
            anchorDate: endedAt,
            anchor: .end,
            taskID: taskID,
            activityItemID: activityItemID,
            usesSelectedActivityItemWhenNil: usesSelectedActivityItemWhenNil,
            note: note
        )
    }

    @discardableResult
    func addManualSession(
        duration: TimeInterval,
        anchorDate: Date,
        anchor: SessionTimeAnchor,
        taskID: UUID? = nil,
        activityItemID: UUID? = nil,
        usesSelectedActivityItemWhenNil: Bool = true,
        note: String = ""
    ) -> WorkSession? {
        guard duration.isFinite, duration > 0 else {
            return nil
        }

        switch anchor {
        case .start:
            return addManualSession(
                startedAt: anchorDate,
                endedAt: anchorDate.addingTimeInterval(duration),
                taskID: taskID,
                activityItemID: activityItemID,
                usesSelectedActivityItemWhenNil: usesSelectedActivityItemWhenNil,
                note: note
            )
        case .end:
            return addManualSession(
                startedAt: anchorDate.addingTimeInterval(-duration),
                endedAt: anchorDate,
                taskID: taskID,
                activityItemID: activityItemID,
                usesSelectedActivityItemWhenNil: usesSelectedActivityItemWhenNil,
                note: note
            )
        }
    }

    @discardableResult
    func addManualSession(
        startedAt: Date,
        endedAt: Date,
        taskID: UUID? = nil,
        activityItemID: UUID? = nil,
        usesSelectedActivityItemWhenNil: Bool = true,
        note: String = ""
    ) -> WorkSession? {
        guard endedAt > startedAt else {
            return nil
        }

        let resolvedTask: WorkTask?
        if let taskID {
            resolvedTask = task(id: taskID)
        } else {
            resolvedTask = selectedTask ?? availableTasks.first
        }

        guard let task = resolvedTask, !task.isArchived else {
            return nil
        }

        let candidateItemID = activityItemID
            ?? (usesSelectedActivityItemWhenNil ? selectedActivityItemID : nil)
        let item = candidateItemID
            .flatMap(activityItem(id:))
            .flatMap { $0.activityID == task.id ? $0 : nil }

        let session = WorkSession(
            id: UUID(),
            taskID: task.id,
            subject: task.name,
            activityItemID: item?.id,
            activityItemTitle: item?.title,
            activityItemKind: item?.kind,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: startedAt,
            endedAt: endedAt,
            segments: [
                WorkSegment(startedAt: startedAt, endedAt: endedAt)
            ]
        )

        sessions.append(session)
        sessions.sort { $0.endedAt > $1.endedAt }
        persist()
        return session
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        persist()
    }

    @discardableResult
    func updateSession(id: UUID, note: String) -> Bool {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else {
            return false
        }

        sessions[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
        return true
    }

    @discardableResult
    func updateSession(
        id: UUID,
        note: String,
        anchorDate: Date,
        duration: TimeInterval,
        anchor: SessionTimeAnchor
    ) -> Bool {
        guard duration.isFinite,
              duration > 0,
              let index = sessions.firstIndex(where: { $0.id == id }) else {
            return false
        }

        let existingSession = sessions[index]
        let startedAt: Date
        let endedAt: Date

        switch anchor {
        case .start:
            startedAt = anchorDate
            endedAt = anchorDate.addingTimeInterval(duration)
        case .end:
            startedAt = anchorDate.addingTimeInterval(-duration)
            endedAt = anchorDate
        }

        guard endedAt > startedAt else {
            return false
        }

        sessions[index] = WorkSession(
            id: existingSession.id,
            taskID: existingSession.taskID,
            subject: existingSession.subject,
            activityItemID: existingSession.activityItemID,
            activityItemTitle: existingSession.activityItemTitle,
            activityItemKind: existingSession.activityItemKind,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: startedAt,
            endedAt: endedAt,
            segments: [
                WorkSegment(startedAt: startedAt, endedAt: endedAt)
            ]
        )
        sessions.sort { $0.endedAt > $1.endedAt }
        persist()
        return true
    }

    func exportData(to destinationURL: URL) throws {
        do {
            try Self.write(currentState(), to: destinationURL)
        } catch {
            throw WorkDataTransferError.writeFailed(error.localizedDescription)
        }
    }

    func importData(from sourceURL: URL) throws {
        guard activeWork == nil else {
            throw WorkDataTransferError.activeTimer
        }

        let importedState: PersistedState
        do {
            let data = try Data(contentsOf: sourceURL)
            importedState = try Self.decodeState(from: data)
        } catch let error as WorkDataTransferError {
            throw error
        } catch {
            throw WorkDataTransferError.invalidFile(error.localizedDescription)
        }

        guard (1...PersistedState.currentSchemaVersion).contains(
            importedState.schemaVersion
        ) else {
            throw WorkDataTransferError.unsupportedSchema(importedState.schemaVersion)
        }

        let previousState = currentState()
        let previousError = persistenceError

        do {
            try Self.write(previousState, to: importBackupURL)
            apply(importedState)
            _ = migrateTaskLibrary(from: importedState.schemaVersion)
            try Self.write(currentState(), to: storageURL)
            persistenceError = nil
        } catch {
            apply(previousState)
            persistenceError = previousError
            throw WorkDataTransferError.writeFailed(error.localizedDescription)
        }
    }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        activeWork?.elapsed(at: date) ?? 0
    }

    func displayedDuration(at date: Date = Date()) -> TimeInterval {
        activeWork?.displayedDuration(at: date) ?? 0
    }

    func activeProgress(at date: Date = Date()) -> Double? {
        activeWork?.progress(at: date)
    }

    func timedCompletionDelay(at date: Date = Date()) -> TimeInterval? {
        guard activeWork?.isRunning == true else {
            return nil
        }
        return activeWork?.remainingDuration(at: date)
    }

    func totalDuration(at date: Date = Date()) -> TimeInterval {
        sessions.reduce(0) { $0 + $1.totalDuration }
            + (activeWork?.recordedElapsed(at: date) ?? 0)
    }

    func totalDuration(
        on day: Date,
        at date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> TimeInterval {
        let completed = sessions.reduce(0) {
            $0 + $1.duration(
                on: day,
                calendar: calendar,
                dayStartHour: dayStartHour
            )
        }
        let active = activeWork?.recordedDuration(
            on: day,
            at: date,
            calendar: calendar,
            dayStartHour: dayStartHour
        ) ?? 0
        return completed + active
    }

    func totalDuration(forTaskID id: UUID, at date: Date = Date()) -> TimeInterval {
        let completed = sessions(forTaskID: id).reduce(0) { $0 + $1.totalDuration }
        let active = activeWorkBelongs(to: id)
            ? activeWork?.recordedElapsed(at: date) ?? 0
            : 0
        return completed + active
    }

    func totalDuration(
        forTaskID id: UUID,
        on day: Date,
        at date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> TimeInterval {
        let completed = sessions(forTaskID: id).reduce(0) {
            $0 + $1.duration(
                on: day,
                calendar: calendar,
                dayStartHour: dayStartHour
            )
        }
        let active = activeWorkBelongs(to: id)
            ? activeWork?.recordedDuration(
                on: day,
                at: date,
                calendar: calendar,
                dayStartHour: dayStartHour
            ) ?? 0
            : 0
        return completed + active
    }

    func dashboardStats(
        at date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> DashboardStats {
        let completedSegments = sessions.flatMap(\.segments)
        let activeSegments = activeWork?.recordedSegments(at: date) ?? []
        guard let earliestDate = (
            (completedSegments + activeSegments)
                .filter { $0.duration > 0 }
                .map(\.startedAt)
                .min()
        ) else {
            return DashboardStats(
                currentStreak: 0,
                longestStreak: 0,
                bestDay: nil,
                bestDayDuration: 0
            )
        }

        let firstDay = WorkdayCalendar.day(
            containing: earliestDate,
            startHour: dayStartHour,
            calendar: calendar
        )
        let finalDay = WorkdayCalendar.day(
            containing: date,
            startHour: dayStartHour,
            calendar: calendar
        )
        let dayCount = max(
            1,
            (calendar.dateComponents(
                [.day],
                from: firstDay,
                to: finalDay
            ).day ?? 0) + 1
        )
        let totals = dailyTotals(
            last: dayCount,
            through: finalDay,
            at: date,
            calendar: calendar,
            dayStartHour: dayStartHour
        )
        let best = totals.max {
            if $0.duration != $1.duration {
                return $0.duration < $1.duration
            }
            return $0.day > $1.day
        }

        var longestStreak = 0
        var runningStreak = 0
        for total in totals {
            if total.duration > 0 {
                runningStreak += 1
                longestStreak = max(longestStreak, runningStreak)
            } else {
                runningStreak = 0
            }
        }

        var currentStreak = 0
        var index = totals.count - 1
        if index >= 0, totals[index].duration <= 0 {
            index -= 1
        }
        while index >= 0, totals[index].duration > 0 {
            currentStreak += 1
            index -= 1
        }

        return DashboardStats(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            bestDay: (best?.duration ?? 0) > 0 ? best?.day : nil,
            bestDayDuration: best?.duration ?? 0
        )
    }

    func dailyTotals(
        last numberOfDays: Int,
        through endingDay: Date = Date(),
        forTaskID taskID: UUID? = nil,
        at date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> [DailyWorkTotal] {
        let dayCount = max(1, numberOfDays)
        let finalDay = calendar.startOfDay(for: endingDay)

        return (0..<dayCount).reversed().compactMap { offset in
            guard let day = calendar.date(
                byAdding: .day,
                value: -offset,
                to: finalDay
            ) else {
                return nil
            }

            let duration: TimeInterval
            if let taskID {
                duration = totalDuration(
                    forTaskID: taskID,
                    on: day,
                    at: date,
                    calendar: calendar,
                    dayStartHour: dayStartHour
                )
            } else {
                duration = totalDuration(
                    on: day,
                    at: date,
                    calendar: calendar,
                    dayStartHour: dayStartHour
                )
            }

            return DailyWorkTotal(day: day, duration: duration)
        }
    }

    func dailyTotals(
        in range: HistoryRange,
        through endingDay: Date = Date(),
        forTaskID taskID: UUID? = nil,
        at date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> [DailyWorkTotal] {
        let finalDay = calendar.startOfDay(for: endingDay)
        let startDay = range.startDay(
            through: finalDay,
            earliestHistoryDay: earliestHistoryDay(
                forTaskID: taskID,
                at: date,
                calendar: calendar,
                dayStartHour: dayStartHour
            ),
            calendar: calendar
        )
        let dayCount = max(
            1,
            (calendar.dateComponents([.day], from: startDay, to: finalDay).day ?? 0) + 1
        )

        return dailyTotals(
            last: dayCount,
            through: finalDay,
            forTaskID: taskID,
            at: date,
            calendar: calendar,
            dayStartHour: dayStartHour
        )
    }

    func dailyTaskTotals(
        last numberOfDays: Int,
        through endingDay: Date = Date(),
        at date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> [DailyTaskWorkTotal] {
        historyTasks.flatMap { task in
            dailyTotals(
                last: numberOfDays,
                through: endingDay,
                forTaskID: task.id,
                at: date,
                calendar: calendar,
                dayStartHour: dayStartHour
            )
            .compactMap { point in
                guard point.duration > 0 else {
                    return nil
                }

                return DailyTaskWorkTotal(
                    day: point.day,
                    taskID: task.id,
                    taskName: task.name,
                    duration: point.duration
                )
            }
        }
        .sorted {
            if $0.day != $1.day {
                return $0.day < $1.day
            }
            return $0.taskName.localizedCaseInsensitiveCompare($1.taskName) == .orderedAscending
        }
    }

    func taskTotals(
        last numberOfDays: Int,
        through endingDay: Date = Date(),
        at date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> [TaskWorkTotal] {
        let taskPoints = dailyTaskTotals(
            last: numberOfDays,
            through: endingDay,
            at: date,
            calendar: calendar,
            dayStartHour: dayStartHour
        )
        let durations = Dictionary(grouping: taskPoints, by: \.taskID)
            .mapValues { points in
                points.reduce(0) { $0 + $1.duration }
            }

        return historyTasks
            .compactMap { task in
                let duration = durations[task.id] ?? 0
                guard duration > 0 else {
                    return nil
                }
                return TaskWorkTotal(
                    taskID: task.id,
                    taskName: task.name,
                    duration: duration
                )
            }
            .sorted {
                if $0.duration != $1.duration {
                    return $0.duration > $1.duration
                }
                return $0.taskName.localizedCaseInsensitiveCompare($1.taskName) == .orderedAscending
            }
    }

    func sessionCount(forTaskID id: UUID) -> Int {
        sessions(forTaskID: id).count
    }

    func sessions(
        on day: Date,
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> [WorkSession] {
        sessions
            .filter {
                $0.duration(
                    on: day,
                    calendar: calendar,
                    dayStartHour: dayStartHour
                ) > 0
            }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func sessions(forTaskID id: UUID) -> [WorkSession] {
        sessions
            .filter { sessionBelongs($0, to: id) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func sessions(
        forTaskID id: UUID,
        on day: Date,
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> [WorkSession] {
        sessions(forTaskID: id)
            .filter {
                $0.duration(
                    on: day,
                    calendar: calendar,
                    dayStartHour: dayStartHour
                ) > 0
            }
    }

    func sessions(
        in range: HistoryRange,
        through endingDay: Date = Date(),
        forTaskID taskID: UUID? = nil,
        at date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> [WorkSession] {
        let finalDay = calendar.startOfDay(for: endingDay)
        let startDay = range.startDay(
            through: finalDay,
            earliestHistoryDay: earliestHistoryDay(
                forTaskID: taskID,
                at: date,
                calendar: calendar,
                dayStartHour: dayStartHour
            ),
            calendar: calendar
        )
        let rangeStart = WorkdayCalendar.interval(
            for: startDay,
            startHour: dayStartHour,
            calendar: calendar
        ).start
        let rangeEnd = WorkdayCalendar.interval(
            for: finalDay,
            startHour: dayStartHour,
            calendar: calendar
        ).end

        return sessions
            .filter { session in
                taskID.map { sessionBelongs(session, to: $0) } ?? true
            }
            .filter { session in
                session.segments.contains { segment in
                    segment.duration > 0
                        && segment.startedAt < rangeEnd
                        && segment.endedAt > rangeStart
                }
            }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func historyDays(
        in range: HistoryRange,
        through endingDay: Date = Date(),
        forTaskID taskID: UUID? = nil,
        at date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> [Date] {
        dailyTotals(
            in: range,
            through: endingDay,
            forTaskID: taskID,
            at: date,
            calendar: calendar,
            dayStartHour: dayStartHour
        )
        .filter { $0.duration > 0 }
        .map(\.day)
        .reversed()
    }

    func filteredActiveWork(forTaskID taskID: UUID?) -> ActiveWork? {
        guard let activeWork, activeWork.countsAsWork else {
            return nil
        }
        guard let taskID else {
            return activeWork
        }
        return activeWorkBelongs(to: taskID) ? activeWork : nil
    }

    func historyDays(
        including date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> [Date] {
        var days: Set<Date> = [
            WorkdayCalendar.day(
                containing: date,
                startHour: dayStartHour,
                calendar: calendar
            )
        ]

        for session in sessions {
            for segment in session.segments {
                addDaysCovered(
                    by: segment,
                    to: &days,
                    calendar: calendar,
                    dayStartHour: dayStartHour
                )
            }
        }

        if let activeWork, activeWork.countsAsWork {
            for segment in activeWork.recordedSegments(at: date) {
                addDaysCovered(
                    by: segment,
                    to: &days,
                    calendar: calendar,
                    dayStartHour: dayStartHour
                )
            }
        }

        return days.sorted(by: >)
    }

    func historyDays(
        forTaskID id: UUID,
        including date: Date = Date(),
        calendar: Calendar = .current,
        dayStartHour: Int = 0
    ) -> [Date] {
        var days: Set<Date> = []

        for session in sessions(forTaskID: id) {
            for segment in session.segments {
                addDaysCovered(
                    by: segment,
                    to: &days,
                    calendar: calendar,
                    dayStartHour: dayStartHour
                )
            }
        }

        if activeWorkBelongs(to: id),
           let activeWork,
           activeWork.countsAsWork {
            for segment in activeWork.recordedSegments(at: date) {
                addDaysCovered(
                    by: segment,
                    to: &days,
                    calendar: calendar,
                    dayStartHour: dayStartHour
                )
            }
        }

        return days.sorted(by: >)
    }

    private func activeWorkBelongs(to taskID: UUID) -> Bool {
        guard let activeWork else {
            return false
        }
        if let activeTaskID = activeWork.taskID {
            return activeTaskID == taskID
        }
        guard let task = task(id: taskID) else {
            return false
        }
        return normalizedTaskKey(activeWork.subject) == normalizedTaskKey(task.name)
    }

    private func sessionBelongs(_ session: WorkSession, to taskID: UUID) -> Bool {
        if let sessionTaskID = session.taskID {
            return sessionTaskID == taskID
        }
        guard let task = task(id: taskID) else {
            return false
        }
        return normalizedTaskKey(session.subject) == normalizedTaskKey(task.name)
    }

    private func earliestHistoryDay(
        forTaskID taskID: UUID?,
        at date: Date,
        calendar: Calendar,
        dayStartHour: Int
    ) -> Date? {
        let relevantSessions = sessions.filter { session in
            taskID.map { sessionBelongs(session, to: $0) } ?? true
        }
        var segmentStarts = relevantSessions.flatMap(\.segments)
            .filter { $0.duration > 0 }
            .map(\.startedAt)

        if let activeWork = filteredActiveWork(forTaskID: taskID) {
            segmentStarts.append(
                contentsOf: activeWork.recordedSegments(at: date)
                    .filter { $0.duration > 0 }
                    .map(\.startedAt)
            )
        }

        return segmentStarts.min().map {
            WorkdayCalendar.day(
                containing: $0,
                startHour: dayStartHour,
                calendar: calendar
            )
        }
    }

    private func addDaysCovered(
        by segment: WorkSegment,
        to days: inout Set<Date>,
        calendar: Calendar,
        dayStartHour: Int
    ) {
        guard segment.duration > 0 else {
            return
        }

        var cursor = WorkdayCalendar.day(
            containing: segment.startedAt,
            startHour: dayStartHour,
            calendar: calendar
        )
        let adjustedEnd = segment.endedAt.addingTimeInterval(-0.001)
        let lastDay = WorkdayCalendar.day(
            containing: max(segment.startedAt, adjustedEnd),
            startHour: dayStartHour,
            calendar: calendar
        )

        while cursor <= lastDay {
            days.insert(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
    }

    private func seedDefaultTask() {
        let task = WorkTask(name: "Work", sortOrder: 0)
        tasks = [task]
        selectedTaskID = task.id
        draftSubject = task.name
    }

    @discardableResult
    private func migrateTaskLibrary(from schemaVersion: Int) -> Bool {
        var changed = false

        if draftSubject == "作業" {
            draftSubject = "Work"
            changed = true
        }

        if var activeWork, activeWork.subject == "作業" {
            activeWork.subject = "Work"
            self.activeWork = activeWork
            changed = true
        }

        func ensureTask(named rawName: String, createdAt: Date) -> UUID {
            let cleanedName = cleanedTaskName(rawName == "作業" ? "Work" : rawName)
            let name = cleanedName.isEmpty ? "Work" : cleanedName

            if let existing = tasks.first(where: {
                normalizedTaskKey($0.name) == normalizedTaskKey(name)
            }) {
                return existing.id
            }

            let newTask = WorkTask(name: name, createdAt: createdAt)
            tasks.append(newTask)
            changed = true
            return newTask.id
        }

        for index in sessions.indices {
            if sessions[index].subject == "作業" {
                sessions[index].subject = "Work"
                changed = true
            }

            let taskExists = sessions[index].taskID.flatMap(task(id:)) != nil
            if !taskExists {
                sessions[index].taskID = ensureTask(
                    named: sessions[index].subject,
                    createdAt: sessions[index].startedAt
                )
                changed = true
            }
        }

        if var activeWork {
            let taskExists = activeWork.taskID.flatMap(task(id:)) != nil
            if !taskExists {
                activeWork.taskID = ensureTask(
                    named: activeWork.subject,
                    createdAt: activeWork.startedAt
                )
                self.activeWork = activeWork
                changed = true
            }
        }

        if tasks.isEmpty, schemaVersion < PersistedState.taskLibrarySchemaVersion {
            _ = ensureTask(
                named: draftSubject.isEmpty ? "Work" : draftSubject,
                createdAt: Date()
            )
        } else if selectedTaskID == nil, !draftSubject.isEmpty {
            selectedTaskID = tasks.first {
                normalizedTaskKey($0.name) == normalizedTaskKey(draftSubject)
            }?.id
            changed = true
        }

        if let activeTaskID = activeWork?.taskID,
           let index = tasks.firstIndex(where: { $0.id == activeTaskID }),
           tasks[index].isArchived {
            tasks[index].isArchived = false
            changed = true
        }

        if selectedTaskID.flatMap(task(id:))?.isArchived != false {
            selectedTaskID = activeWork?.taskID ?? availableTasks.first?.id
            changed = true
        }

        if let selectedTask, draftSubject != selectedTask.name {
            draftSubject = selectedTask.name
            changed = true
        }

        let validActivityIDs = Set(tasks.map(\.id))
        let originalItemCount = activityItems.count
        activityItems.removeAll { !validActivityIDs.contains($0.activityID) }
        if activityItems.count != originalItemCount {
            changed = true
        }

        if var activeWork,
           let itemID = activeWork.activityItemID {
            let item = activityItem(id: itemID)
            if item?.activityID != activeWork.taskID {
                activeWork.activityItemID = nil
                activeWork.activityItemTitle = nil
                activeWork.activityItemKind = nil
                activeWork.activityItemOccurrenceKey = nil
                self.activeWork = activeWork
                changed = true
            }
        }

        if let selectedActivityItemID {
            let item = activityItem(id: selectedActivityItemID)
            let isValidSelection: Bool
            if let item {
                if let activeWork {
                    isValidSelection = item.activityID == activeWork.taskID
                } else {
                    isValidSelection = item.activityID == selectedTaskID && item.isSelectable()
                }
            } else {
                isValidSelection = false
            }
            if !isValidSelection {
                self.selectedActivityItemID = nil
                changed = true
            }
        }

        if schemaVersion < PersistedState.currentSchemaVersion {
            changed = true
        }

        if schemaVersion < PersistedState.activityOrderSchemaVersion
            || tasks.contains(where: { $0.sortOrder == nil }) {
            let orderedTasks = tasks.sorted {
                let nameOrder = $0.name.localizedCaseInsensitiveCompare($1.name)
                if nameOrder != .orderedSame {
                    return nameOrder == .orderedAscending
                }
                return $0.createdAt < $1.createdAt
            }
            applyTaskOrder(orderedTasks)
            changed = true
        }

        if schemaVersion < PersistedState.activityItemOrderSchemaVersion
            || activityItems.contains(where: { $0.sortOrder == nil }) {
            for activityID in validActivityIDs {
                let orderedItems = activityItems
                    .filter { $0.activityID == activityID }
                    .sorted(by: activityItemSort)
                applyActivityItemOrder(orderedItems)
            }
            changed = true
        }

        return changed
    }

    private func load() -> Int? {
        do {
            let data = try Data(contentsOf: storageURL)
            let state = try Self.decodeState(from: data)
            apply(state)
            persistenceError = nil
            return state.schemaVersion
        } catch {
            persistenceError = "Could not load saved data: \(error.localizedDescription)"
            return nil
        }
    }

    private func persist() {
        do {
            try Self.write(currentState(), to: storageURL)
            persistenceError = nil
        } catch {
            persistenceError = "Could not save your records: \(error.localizedDescription)"
        }
    }

    private func currentState() -> PersistedState {
        PersistedState(
            schemaVersion: PersistedState.currentSchemaVersion,
            sessions: sessions,
            tasks: tasks,
            activityItems: activityItems,
            selectedTaskID: selectedTaskID,
            selectedActivityItemID: selectedActivityItemID,
            activeWork: activeWork,
            draftSubject: draftSubject,
            draftNote: draftNote
        )
    }

    private func apply(_ state: PersistedState) {
        sessions = state.sessions.sorted { $0.endedAt > $1.endedAt }
        tasks = state.tasks
        activityItems = state.activityItems
        selectedTaskID = state.selectedTaskID
        selectedActivityItemID = state.selectedActivityItemID
        activeWork = state.activeWork
        draftSubject = state.draftSubject
        draftNote = state.draftNote
    }

    private static func decodeState(from data: Data) throws -> PersistedState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersistedState.self, from: data)
    }

    private static func write(_ state: PersistedState, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: .atomic)
    }

    private func cleanedTaskName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedTaskKey(_ value: String) -> String {
        cleanedTaskName(value)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }

    private func activityItemSort(_ lhs: ActivityItem, _ rhs: ActivityItem) -> Bool {
        let lhsOrder = lhs.sortOrder ?? Int.max
        let rhsOrder = rhs.sortOrder ?? Int.max
        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }

        return legacyActivityItemSort(lhs, rhs)
    }

    private func legacyActivityItemSort(
        _ lhs: ActivityItem,
        _ rhs: ActivityItem
    ) -> Bool {
        if lhs.kind != rhs.kind {
            return lhs.kind == .task
        }
        let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if titleOrder != .orderedSame {
            return titleOrder == .orderedAscending
        }
        return lhs.createdAt < rhs.createdAt
    }

    private func nextActivityItemSortOrder(for activityID: UUID) -> Int {
        let orders = activityItems
            .filter { $0.activityID == activityID }
            .compactMap(\.sortOrder)
        return (orders.max() ?? -1) + 1
    }

    private var nextTaskSortOrder: Int {
        (tasks.compactMap(\.sortOrder).max() ?? -1) + 1
    }

    private func taskSort(_ lhs: WorkTask, _ rhs: WorkTask) -> Bool {
        let lhsOrder = lhs.sortOrder ?? Int.max
        let rhsOrder = rhs.sortOrder ?? Int.max
        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }

        let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameOrder != .orderedSame {
            return nameOrder == .orderedAscending
        }
        return lhs.createdAt < rhs.createdAt
    }

    private func applyTaskOrder(_ orderedTasks: [WorkTask]) {
        for (sortOrder, task) in orderedTasks.enumerated() {
            guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
                continue
            }
            tasks[index].sortOrder = sortOrder
        }
    }

    private func applyActivityItemOrder(_ orderedItems: [ActivityItem]) {
        for (sortOrder, item) in orderedItems.enumerated() {
            guard let index = activityItems.firstIndex(where: {
                $0.id == item.id
            }) else {
                continue
            }
            activityItems[index].sortOrder = sortOrder
        }
    }

    private static func defaultStorageURL() -> URL {
        if let overridePath = Bundle.main.object(
            forInfoDictionaryKey: "WorkIslandStoragePath"
        ) as? String {
            let cleanedPath = overridePath.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !cleanedPath.isEmpty {
                return URL(fileURLWithPath: cleanedPath)
            }
        }

        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("WorkIsland", isDirectory: true)
            .appendingPathComponent("work-data.json")
    }
}

private struct PersistedState: Codable {
    static let taskLibrarySchemaVersion = 2
    static let activityItemSchemaVersion = 3
    static let activityOrderSchemaVersion = 4
    static let activityItemOrderSchemaVersion = 5
    static let timedActivitySchemaVersion = 6
    static let currentSchemaVersion = timedActivitySchemaVersion

    let schemaVersion: Int
    let sessions: [WorkSession]
    let tasks: [WorkTask]
    let activityItems: [ActivityItem]
    let selectedTaskID: UUID?
    let selectedActivityItemID: UUID?
    let activeWork: ActiveWork?
    let draftSubject: String
    let draftNote: String

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case sessions
        case tasks
        case activityItems
        case selectedTaskID
        case selectedActivityItemID
        case activeWork
        case draftSubject
        case draftNote
    }

    init(
        schemaVersion: Int,
        sessions: [WorkSession],
        tasks: [WorkTask],
        activityItems: [ActivityItem],
        selectedTaskID: UUID?,
        selectedActivityItemID: UUID?,
        activeWork: ActiveWork?,
        draftSubject: String,
        draftNote: String
    ) {
        self.schemaVersion = schemaVersion
        self.sessions = sessions
        self.tasks = tasks
        self.activityItems = activityItems
        self.selectedTaskID = selectedTaskID
        self.selectedActivityItemID = selectedActivityItemID
        self.activeWork = activeWork
        self.draftSubject = draftSubject
        self.draftNote = draftNote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        sessions = try container.decodeIfPresent([WorkSession].self, forKey: .sessions) ?? []
        tasks = try container.decodeIfPresent([WorkTask].self, forKey: .tasks) ?? []
        activityItems = try container.decodeIfPresent([ActivityItem].self, forKey: .activityItems) ?? []
        selectedTaskID = try container.decodeIfPresent(UUID.self, forKey: .selectedTaskID)
        selectedActivityItemID = try container.decodeIfPresent(
            UUID.self,
            forKey: .selectedActivityItemID
        )
        activeWork = try container.decodeIfPresent(ActiveWork.self, forKey: .activeWork)
        draftSubject = try container.decodeIfPresent(String.self, forKey: .draftSubject) ?? ""
        draftNote = try container.decodeIfPresent(String.self, forKey: .draftNote) ?? ""
    }
}
