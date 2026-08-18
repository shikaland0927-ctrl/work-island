import XCTest
@testable import WorkIsland

final class ActivityItemTests: XCTestCase {
    func testNotchUsesAnOpenCircleForTasks() {
        XCTAssertEqual(ActivityItemKind.task.islandSystemImage, "circle")
        XCTAssertEqual(ActivityItemKind.routine.islandSystemImage, "repeat")
        XCTAssertNotEqual(
            ActivityItemKind.task.islandSystemImage,
            ActivityItemKind.task.systemImage
        )
    }

    func testTasksAndRoutinesShareOnePersistedOrder() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let activity = try XCTUnwrap(store.selectedTask)
        let firstTask = try XCTUnwrap(
            store.addActivityTask(named: "Outline", to: activity.id)
        )
        let routine = try XCTUnwrap(
            store.addRoutine(
                named: "Review",
                to: activity.id,
                schedule: RoutineSchedule(anchorDate: Date())
            )
        )
        let secondTask = try XCTUnwrap(
            store.addActivityTask(named: "Draft", to: activity.id)
        )

        XCTAssertEqual(
            store.reorderableActivityItems(for: activity.id).map(\.id),
            [firstTask.id, routine.id, secondTask.id]
        )

        store.moveActivityItems(
            for: activity.id,
            fromOffsets: IndexSet(integer: 1),
            toOffset: 0
        )
        store.completeActivityTask(id: firstTask.id)
        store.moveActivityItems(
            for: activity.id,
            fromOffsets: IndexSet(integer: 1),
            toOffset: 0
        )
        store.restoreActivityTask(id: firstTask.id)

        XCTAssertEqual(
            store.reorderableActivityItems(for: activity.id).map(\.id),
            [secondTask.id, firstTask.id, routine.id]
        )

        let restored = WorkTimerStore(storageURL: storageURL)
        XCTAssertEqual(
            restored.reorderableActivityItems(for: activity.id).map(\.id),
            [secondTask.id, firstTask.id, routine.id]
        )
    }

    func testSchemaFourItemsMigrateUsingTheirPreviousVisibleOrder() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let activity = try XCTUnwrap(store.selectedTask)
        let routine = try XCTUnwrap(
            store.addRoutine(
                named: "Review",
                to: activity.id,
                schedule: RoutineSchedule(anchorDate: Date())
            )
        )
        let laterTask = try XCTUnwrap(
            store.addActivityTask(named: "Write", to: activity.id)
        )
        let earlierTask = try XCTUnwrap(
            store.addActivityTask(named: "Outline", to: activity.id)
        )

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: storageURL))
                as? [String: Any]
        )
        var items = try XCTUnwrap(object["activityItems"] as? [[String: Any]])
        for index in items.indices {
            items[index].removeValue(forKey: "sortOrder")
        }
        object["activityItems"] = items
        object["schemaVersion"] = 4
        try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: storageURL, options: .atomic)

        let migrated = WorkTimerStore(storageURL: storageURL)

        XCTAssertEqual(
            migrated.activityItems(for: activity.id).map(\.id),
            [earlierTask.id, laterTask.id, routine.id]
        )
        XCTAssertEqual(
            migrated.activityItems(for: activity.id).compactMap(\.sortOrder),
            [0, 1, 2]
        )

        let migratedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: storageURL))
                as? [String: Any]
        )
        XCTAssertEqual(migratedObject["schemaVersion"] as? Int, 6)
    }

    func testRoutineScheduleSupportsDayWeekAndMonthRules() throws {
        let calendar = utcCalendar()
        let anchor = try date("2026-08-03T12:00:00Z")

        let daily = RoutineSchedule(
            frequency: .day,
            interval: 2,
            anchorDate: anchor,
            calendar: calendar
        )
        XCTAssertTrue(daily.isScheduled(on: anchor, calendar: calendar))
        XCTAssertFalse(
            daily.isScheduled(
                on: try date("2026-08-04T12:00:00Z"),
                calendar: calendar
            )
        )
        XCTAssertTrue(
            daily.isScheduled(
                on: try date("2026-08-05T12:00:00Z"),
                calendar: calendar
            )
        )

        let weekly = RoutineSchedule(
            frequency: .week,
            interval: 2,
            weekdays: [2, 4],
            anchorDate: anchor,
            calendar: calendar
        )
        XCTAssertTrue(weekly.isScheduled(on: anchor, calendar: calendar))
        XCTAssertTrue(
            weekly.isScheduled(
                on: try date("2026-08-05T12:00:00Z"),
                calendar: calendar
            )
        )
        XCTAssertFalse(
            weekly.isScheduled(
                on: try date("2026-08-10T12:00:00Z"),
                calendar: calendar
            )
        )
        XCTAssertTrue(
            weekly.isScheduled(
                on: try date("2026-08-17T12:00:00Z"),
                calendar: calendar
            )
        )

        let onThirtyFirst = RoutineSchedule(
            frequency: .month,
            monthMode: .dates,
            monthDates: [31],
            anchorDate: try date("2026-08-01T12:00:00Z"),
            calendar: calendar
        )
        XCTAssertTrue(
            onThirtyFirst.isScheduled(
                on: try date("2026-08-31T12:00:00Z"),
                calendar: calendar
            )
        )
        XCTAssertFalse(
            onThirtyFirst.isScheduled(
                on: try date("2026-09-30T12:00:00Z"),
                calendar: calendar
            )
        )

        let lastDay = RoutineSchedule(
            frequency: .month,
            monthMode: .dates,
            monthDates: [31],
            includesLastDay: true,
            anchorDate: try date("2026-08-01T12:00:00Z"),
            calendar: calendar
        )
        XCTAssertTrue(
            lastDay.isScheduled(
                on: try date("2026-09-30T12:00:00Z"),
                calendar: calendar
            )
        )

        let lastFriday = RoutineSchedule(
            frequency: .month,
            monthMode: .pattern,
            ordinal: .last,
            ordinalWeekday: 6,
            anchorDate: try date("2026-08-01T12:00:00Z"),
            calendar: calendar
        )
        XCTAssertTrue(
            lastFriday.isScheduled(
                on: try date("2026-08-28T12:00:00Z"),
                calendar: calendar
            )
        )
        XCTAssertFalse(
            lastFriday.isScheduled(
                on: try date("2026-08-21T12:00:00Z"),
                calendar: calendar
            )
        )

        XCTAssertEqual(
            daily.mostRecentDate(
                onOrBefore: try date("2026-08-04T12:00:00Z"),
                calendar: calendar
            ),
            calendar.startOfDay(for: anchor)
        )
        XCTAssertNil(
            daily.mostRecentDate(
                onOrBefore: try date("2026-08-02T12:00:00Z"),
                calendar: calendar
            )
        )
    }

    func testFinishKeepsTaskOpenAndDoneCompletesIt() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let activity = try XCTUnwrap(store.addTask(named: "Thesis"))
        let item = try XCTUnwrap(
            store.addActivityTask(named: "Write introduction", to: activity.id)
        )
        let firstStart = Date(timeIntervalSince1970: 1_800_000_000)

        store.selectActivityItem(id: item.id, at: firstStart)
        store.start(at: firstStart)
        let firstSession = try XCTUnwrap(
            store.finish(at: firstStart.addingTimeInterval(600))
        )

        XCTAssertEqual(firstSession.activityItemID, item.id)
        XCTAssertEqual(firstSession.activityItemTitle, "Write introduction")
        XCTAssertEqual(firstSession.activityItemKind, .task)
        XCTAssertNil(store.activityItem(id: item.id)?.completedAt)

        let secondStart = firstStart.addingTimeInterval(1_000)
        store.selectActivityItem(id: item.id, at: secondStart)
        store.start(at: secondStart)
        let completedSession = try XCTUnwrap(
            store.finishAndComplete(at: secondStart.addingTimeInterval(300))
        )

        XCTAssertEqual(completedSession.activityItemID, item.id)
        XCTAssertNotNil(store.activityItem(id: item.id)?.completedAt)
        XCTAssertNil(store.selectedActivityItemID)
        XCTAssertFalse(store.openActivityTasks(for: activity.id).contains { $0.id == item.id })
        XCTAssertTrue(store.completedActivityTasks(for: activity.id).contains { $0.id == item.id })

        let restored = WorkTimerStore(storageURL: storageURL)
        XCTAssertNotNil(restored.activityItem(id: item.id)?.completedAt)
        XCTAssertEqual(restored.sessions.first?.activityItemTitle, "Write introduction")
    }

    func testRoutineDoneCompletesOnlyTheCurrentOccurrence() throws {
        let calendar = Calendar.current
        let firstDay = try date("2026-08-03T12:00:00Z")
        let secondDay = try date("2026-08-04T12:00:00Z")
        let thirdDay = try date("2026-08-05T12:00:00Z")
        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        let activity = try XCTUnwrap(store.addTask(named: "Health"))
        let schedule = RoutineSchedule(
            frequency: .day,
            anchorDate: firstDay,
            calendar: calendar
        )
        let routine = try XCTUnwrap(
            store.addRoutine(
                named: "Stretch",
                to: activity.id,
                schedule: schedule,
                at: firstDay
            )
        )

        store.selectActivityItem(id: routine.id, at: firstDay, calendar: calendar)
        store.start(at: firstDay)
        _ = store.finishAndComplete(at: firstDay.addingTimeInterval(120))

        let completed = try XCTUnwrap(store.activityItem(id: routine.id))
        XCTAssertFalse(completed.isSelectable(on: firstDay, calendar: calendar))
        XCTAssertTrue(completed.isSelectable(on: secondDay, calendar: calendar))
        XCTAssertTrue(completed.isSelectable(on: thirdDay, calendar: calendar))
        XCTAssertEqual(
            completed.nextPendingDates(
                startingAt: thirdDay,
                count: 2,
                calendar: calendar
            ),
            [
                calendar.startOfDay(for: thirdDay),
                calendar.startOfDay(
                    for: try date("2026-08-06T12:00:00Z")
                )
            ]
        )
    }

    func testRoutineMovesThroughCompletedUntilItsNextScheduledOccurrence() throws {
        let calendar = utcCalendar()
        let firstDay = try date("2026-08-03T12:00:00Z")
        let betweenOccurrences = try date("2026-08-04T12:00:00Z")
        let nextOccurrence = try date("2026-08-05T12:00:00Z")
        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        let activity = try XCTUnwrap(store.addTask(named: "Health"))
        let routine = try XCTUnwrap(
            store.addRoutine(
                named: "Stretch",
                to: activity.id,
                schedule: RoutineSchedule(
                    frequency: .day,
                    interval: 2,
                    anchorDate: firstDay,
                    calendar: calendar
                ),
                at: firstDay
            )
        )

        store.selectActivityItem(id: routine.id, at: firstDay, calendar: calendar)
        store.start(at: firstDay)
        _ = store.finishAndComplete(at: firstDay.addingTimeInterval(120))

        XCTAssertTrue(
            store.completedActivityItems(
                for: activity.id,
                at: firstDay,
                calendar: calendar
            ).contains { $0.id == routine.id }
        )
        XCTAssertTrue(
            store.completedActivityItems(
                for: activity.id,
                at: betweenOccurrences,
                calendar: calendar
            ).contains { $0.id == routine.id }
        )
        XCTAssertFalse(
            store.openRoutines(
                for: activity.id,
                at: betweenOccurrences,
                calendar: calendar
            ).contains { $0.id == routine.id }
        )

        XCTAssertTrue(
            store.restoreActivityItem(
                id: routine.id,
                at: firstDay,
                calendar: calendar
            )
        )
        XCTAssertTrue(
            store.selectableRoutines(
                for: activity.id,
                at: firstDay,
                calendar: calendar
            ).contains { $0.id == routine.id }
        )

        store.selectActivityItem(id: routine.id, at: firstDay, calendar: calendar)
        store.start(at: firstDay.addingTimeInterval(180))
        _ = store.finishAndComplete(at: firstDay.addingTimeInterval(300))

        XCTAssertFalse(
            store.completedActivityItems(
                for: activity.id,
                at: nextOccurrence,
                calendar: calendar
            ).contains { $0.id == routine.id }
        )
        XCTAssertTrue(
            store.openRoutines(
                for: activity.id,
                at: nextOccurrence,
                calendar: calendar
            ).contains { $0.id == routine.id }
        )
    }

    func testRoutineCheckboxTogglesCurrentCycleWithoutRemovingRoutine() throws {
        let calendar = utcCalendar()
        let firstDay = try date("2026-08-03T12:00:00Z")
        let betweenOccurrences = try date("2026-08-04T12:00:00Z")
        let nextOccurrence = try date("2026-08-05T12:00:00Z")
        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        let activity = try XCTUnwrap(store.addTask(named: "Health"))
        let routine = try XCTUnwrap(
            store.addRoutine(
                named: "Stretch",
                to: activity.id,
                schedule: RoutineSchedule(
                    frequency: .day,
                    interval: 2,
                    anchorDate: firstDay,
                    calendar: calendar
                ),
                at: firstDay
            )
        )

        XCTAssertTrue(
            store.completeActivityItem(
                id: routine.id,
                at: betweenOccurrences,
                calendar: calendar
            )
        )
        XCTAssertTrue(store.routines(for: activity.id).contains { $0.id == routine.id })
        XCTAssertNotNil(
            store.activityItem(id: routine.id)?
                .completedOccurrenceKeyForCurrentCycle(
                    at: betweenOccurrences,
                    calendar: calendar
                )
        )

        XCTAssertTrue(
            store.restoreActivityItem(
                id: routine.id,
                at: betweenOccurrences,
                calendar: calendar
            )
        )
        XCTAssertNil(
            store.activityItem(id: routine.id)?
                .completedOccurrenceKeyForCurrentCycle(
                    at: betweenOccurrences,
                    calendar: calendar
                )
        )

        XCTAssertTrue(
            store.completeActivityItem(
                id: routine.id,
                at: betweenOccurrences,
                calendar: calendar
            )
        )
        XCTAssertNil(
            store.activityItem(id: routine.id)?
                .completedOccurrenceKeyForCurrentCycle(
                    at: nextOccurrence,
                    calendar: calendar
                )
        )
        XCTAssertTrue(store.routines(for: activity.id).contains { $0.id == routine.id })
    }

    func testDeletingAnItemKeepsItsHistorySnapshot() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let activity = try XCTUnwrap(store.addTask(named: "Study"))
        let item = try XCTUnwrap(
            store.addActivityTask(named: "Chapter 1", to: activity.id)
        )
        let start = Date(timeIntervalSince1970: 1_800_100_000)

        store.start(at: start)
        _ = store.finish(at: start.addingTimeInterval(60))
        store.deleteActivityItem(id: item.id)

        XCTAssertNil(store.activityItem(id: item.id))
        XCTAssertEqual(store.sessions.first?.activityItemID, item.id)
        XCTAssertEqual(store.sessions.first?.activityItemTitle, "Chapter 1")

        let restored = WorkTimerStore(storageURL: storageURL)
        XCTAssertNil(restored.activityItem(id: item.id))
        XCTAssertEqual(restored.sessions.first?.activityItemTitle, "Chapter 1")
    }

    func testSchemaTwoEmptyLibraryMigratesWithoutSeedingWork() throws {
        let storageURL = temporaryStorageURL()
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let schemaTwo = """
        {
          "schemaVersion": 2,
          "sessions": [],
          "tasks": [],
          "selectedTaskID": null,
          "activeWork": null,
          "draftSubject": "",
          "draftNote": ""
        }
        """
        try Data(schemaTwo.utf8).write(to: storageURL)

        let store = WorkTimerStore(storageURL: storageURL)

        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertTrue(store.activityItems.isEmpty)
        XCTAssertNil(store.selectedTaskID)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: storageURL))
                as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 6)
        XCTAssertEqual((object["activityItems"] as? [Any])?.count, 0)
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }

    private func temporaryStorageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkIslandActivityItemTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("work-data.json")
    }
}
