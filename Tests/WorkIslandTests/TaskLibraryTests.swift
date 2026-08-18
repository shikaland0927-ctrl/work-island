import XCTest
@testable import WorkIsland

final class TaskLibraryTests: XCTestCase {
    func testLegacyDraftMigratesIntoSelectedTask() throws {
        let storageURL = temporaryStorageURL()
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let legacyJSON = """
        {
          "draftNote" : "Vocabulary",
          "draftSubject" : "English",
          "sessions" : [
            {
              "endedAt" : "2026-08-02T01:05:00Z",
              "id" : "4C363C25-D637-4C3E-8910-142D974881C7",
              "note" : "Vocabulary",
              "segments" : [
                {
                  "endedAt" : "2026-08-02T01:05:00Z",
                  "startedAt" : "2026-08-02T01:00:00Z"
                }
              ],
              "startedAt" : "2026-08-02T01:00:00Z",
              "subject" : "English"
            }
          ]
        }
        """
        try Data(legacyJSON.utf8).write(to: storageURL)

        let store = WorkTimerStore(storageURL: storageURL)

        XCTAssertEqual(store.availableTasks.map(\.name), ["English"])
        XCTAssertEqual(store.selectedTask?.name, "English")
        XCTAssertEqual(store.draftNote, "Vocabulary")
        XCTAssertEqual(store.sessions.first?.taskID, store.selectedTaskID)
        XCTAssertEqual(store.totalDuration(forTaskID: try XCTUnwrap(store.selectedTaskID)), 300)

        let restoredStore = WorkTimerStore(storageURL: storageURL)
        XCTAssertEqual(restoredStore.selectedTask?.name, "English")
    }

    func testCurrentSchemaKeepsAnIntentionallyEmptyActivityLibrary() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let defaultTask = try XCTUnwrap(store.tasks.first)

        store.archiveTask(id: defaultTask.id)
        store.deleteTask(id: defaultTask.id)

        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertNil(store.selectedTaskID)

        let restoredStore = WorkTimerStore(storageURL: storageURL)

        XCTAssertTrue(restoredStore.tasks.isEmpty)
        XCTAssertTrue(restoredStore.availableTasks.isEmpty)
        XCTAssertNil(restoredStore.selectedTaskID)
        XCTAssertEqual(restoredStore.draftSubject, "")
    }

    func testSelectedTaskAndSessionTaskIDPersist() throws {
        let storageURL = temporaryStorageURL()
        let start = Date(timeIntervalSince1970: 1_700_200_000)
        let store = WorkTimerStore(storageURL: storageURL)
        let task = try XCTUnwrap(store.addTask(named: "Thesis"))

        store.start(at: start)
        store.finish(at: start.addingTimeInterval(300))

        let restoredStore = WorkTimerStore(storageURL: storageURL)

        XCTAssertEqual(restoredStore.selectedTaskID, task.id)
        XCTAssertEqual(restoredStore.sessions.first?.taskID, task.id)
        XCTAssertEqual(restoredStore.sessions.first?.subject, "Thesis")
    }

    func testRenamingTaskUpdatesItsExistingSessions() throws {
        let start = Date(timeIntervalSince1970: 1_700_300_000)
        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        let task = try XCTUnwrap(store.addTask(named: "Reading"))

        store.start(at: start)
        store.finish(at: start.addingTimeInterval(120))

        XCTAssertTrue(store.renameTask(id: task.id, to: "Research"))
        XCTAssertEqual(store.task(id: task.id)?.name, "Research")
        XCTAssertEqual(store.sessions.first?.subject, "Research")
    }

    func testArchivedTaskLeavesSelectorsButRemainsInHistory() throws {
        let start = Date(timeIntervalSince1970: 1_700_400_000)
        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        let task = try XCTUnwrap(store.addTask(named: "Client Work"))

        store.start(at: start)
        store.finish(at: start.addingTimeInterval(180))
        store.archiveTask(id: task.id)

        XCTAssertFalse(store.availableTasks.contains { $0.id == task.id })
        XCTAssertTrue(store.historyTasks.contains { $0.id == task.id })
        XCTAssertEqual(store.sessionCount(forTaskID: task.id), 1)
        XCTAssertTrue(store.canDeleteTask(id: task.id))
    }

    func testDeletingArchivedTaskAlsoDeletesItsRecordsAndPersists() throws {
        let storageURL = temporaryStorageURL()
        let start = Date(timeIntervalSince1970: 1_700_450_000)
        let store = WorkTimerStore(storageURL: storageURL)
        let keptTask = try XCTUnwrap(store.addTask(named: "Keep"))
        store.start(at: start)
        store.finish(at: start.addingTimeInterval(60))

        let deletedTask = try XCTUnwrap(store.addTask(named: "Delete"))
        store.start(at: start.addingTimeInterval(120))
        store.finish(at: start.addingTimeInterval(300))

        XCTAssertFalse(store.canDeleteTask(id: deletedTask.id))
        store.archiveTask(id: deletedTask.id)
        XCTAssertTrue(store.canDeleteTask(id: deletedTask.id))

        store.deleteTask(id: deletedTask.id)

        XCTAssertNil(store.task(id: deletedTask.id))
        XCTAssertEqual(store.sessionCount(forTaskID: deletedTask.id), 0)
        XCTAssertEqual(store.sessionCount(forTaskID: keptTask.id), 1)

        let restoredStore = WorkTimerStore(storageURL: storageURL)
        XCTAssertNil(restoredStore.task(id: deletedTask.id))
        XCTAssertFalse(restoredStore.sessions.contains { $0.taskID == deletedTask.id })
        XCTAssertEqual(restoredStore.sessionCount(forTaskID: keptTask.id), 1)
    }

    func testDeletingArchivedUnicodeActivityWithoutRecordsPersists() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let activity = try XCTUnwrap(store.addTask(named: "cvっc"))
        store.archiveTask(id: activity.id)

        let request = ArchivedActivityDeletionRequest(
            activity: activity,
            recordCount: store.sessionCount(forTaskID: activity.id)
        )

        XCTAssertEqual(request.activityID, activity.id)
        XCTAssertEqual(request.title, "Delete cvっc?")
        XCTAssertEqual(
            request.message,
            "This permanently deletes the activity and its tasks and routines."
        )
        XCTAssertTrue(store.canDeleteTask(id: request.activityID))

        store.deleteTask(id: request.activityID)

        XCTAssertNil(store.task(id: activity.id))
        XCTAssertNil(WorkTimerStore(storageURL: storageURL).task(id: activity.id))
    }

    func testTotalsAreSeparatedByTask() throws {
        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        let firstStart = Date(timeIntervalSince1970: 1_700_500_000)
        let firstTask = try XCTUnwrap(store.addTask(named: "English"))

        store.start(at: firstStart)
        store.finish(at: firstStart.addingTimeInterval(60))

        let secondTask = try XCTUnwrap(store.addTask(named: "Writing"))
        let secondStart = firstStart.addingTimeInterval(500)
        store.start(at: secondStart)
        store.finish(at: secondStart.addingTimeInterval(120))

        XCTAssertEqual(store.totalDuration(forTaskID: firstTask.id), 60, accuracy: 0.001)
        XCTAssertEqual(store.totalDuration(forTaskID: secondTask.id), 120, accuracy: 0.001)
    }

    private func temporaryStorageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkIslandTaskTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("work-data.json")
    }
}
