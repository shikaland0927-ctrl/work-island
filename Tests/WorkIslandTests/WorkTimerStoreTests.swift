import XCTest
@testable import WorkIsland

final class WorkTimerStoreTests: XCTestCase {
    func testStoreReportsWhetherPersistentDataAlreadyExisted() {
        let storageURL = temporaryStorageURL()

        let freshStore = WorkTimerStore(storageURL: storageURL)
        let restoredStore = WorkTimerStore(storageURL: storageURL)

        XCTAssertFalse(freshStore.startedWithExistingData)
        XCTAssertTrue(restoredStore.startedWithExistingData)
    }

    func testActivityOrderPersistsAfterManualMove() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let work = try XCTUnwrap(store.selectedTask)
        let research = try XCTUnwrap(store.addTask(named: "Research"))
        let study = try XCTUnwrap(store.addTask(named: "Study"))

        store.moveTasks(
            fromOffsets: IndexSet(integer: 2),
            toOffset: 0
        )

        XCTAssertEqual(
            store.availableTasks.map(\.id),
            [study.id, work.id, research.id]
        )

        let restored = WorkTimerStore(storageURL: storageURL)

        XCTAssertEqual(
            restored.availableTasks.map(\.id),
            [study.id, work.id, research.id]
        )
    }

    func testDashboardStatsReportCurrentAndLongestStreakAndBestDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let firstDay = try XCTUnwrap(
            formatter.date(from: "2026-08-01T10:00:00Z")
        )
        let secondDay = try XCTUnwrap(
            formatter.date(from: "2026-08-02T10:00:00Z")
        )
        let thirdDay = try XCTUnwrap(
            formatter.date(from: "2026-08-03T10:00:00Z")
        )
        let fifthDay = try XCTUnwrap(
            formatter.date(from: "2026-08-05T10:00:00Z")
        )
        let sixthDay = try XCTUnwrap(
            formatter.date(from: "2026-08-06T10:00:00Z")
        )
        let now = try XCTUnwrap(
            formatter.date(from: "2026-08-06T18:00:00Z")
        )
        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        let activity = try XCTUnwrap(store.selectedTask)

        _ = store.addManualSession(
            duration: 7_200,
            endedAt: firstDay.addingTimeInterval(7_200),
            taskID: activity.id
        )
        _ = store.addManualSession(
            duration: 3_600,
            endedAt: secondDay.addingTimeInterval(3_600),
            taskID: activity.id
        )
        _ = store.addManualSession(
            duration: 10_800,
            endedAt: thirdDay.addingTimeInterval(10_800),
            taskID: activity.id
        )
        _ = store.addManualSession(
            duration: 5_400,
            endedAt: fifthDay.addingTimeInterval(5_400),
            taskID: activity.id
        )
        _ = store.addManualSession(
            duration: 1_800,
            endedAt: sixthDay.addingTimeInterval(1_800),
            taskID: activity.id
        )

        let stats = store.dashboardStats(at: now, calendar: calendar)

        XCTAssertEqual(stats.currentStreak, 2)
        XCTAssertEqual(stats.longestStreak, 3)
        XCTAssertEqual(
            stats.bestDay,
            calendar.startOfDay(for: thirdDay)
        )
        XCTAssertEqual(stats.bestDayDuration, 10_800, accuracy: 0.001)
    }

    func testPauseAndResumeExcludePausedTime() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        let task = try XCTUnwrap(store.addTask(named: "Research"))
        store.updateNote("Chapter 1")
        store.start(at: start)
        store.pause(at: start.addingTimeInterval(600))
        store.resume(at: start.addingTimeInterval(900))
        let session = store.finish(at: start.addingTimeInterval(1_200))

        XCTAssertEqual(session?.subject, "Research")
        XCTAssertEqual(session?.taskID, task.id)
        XCTAssertEqual(session?.note, "Chapter 1")
        XCTAssertEqual(session?.totalDuration ?? -1, 900, accuracy: 0.001)
        XCTAssertEqual(session?.segments.count, 2)
        XCTAssertNil(store.activeWork)
    }

    func testRunningSessionIsRestoredFromDisk() throws {
        let storageURL = temporaryStorageURL()
        let start = Date(timeIntervalSince1970: 1_700_100_000)

        do {
            let store = WorkTimerStore(storageURL: storageURL)
            store.addTask(named: "Reading")
            store.start(at: start)
        }

        let restoredStore = WorkTimerStore(storageURL: storageURL)

        XCTAssertEqual(restoredStore.activeWork?.subject, "Reading")
        XCTAssertEqual(restoredStore.activeWork?.runningSince, start)
        XCTAssertTrue(restoredStore.isRunning)
    }

    func testActiveWorkCanOnlyBeDiscardedAfterPause() throws {
        let storageURL = temporaryStorageURL()
        let start = Date(timeIntervalSince1970: 1_700_150_000)
        let store = WorkTimerStore(storageURL: storageURL)

        store.addTask(named: "Draft")
        store.updateNote("Do not save")
        store.start(at: start)

        XCTAssertFalse(store.discardPausedWork())
        XCTAssertNotNil(store.activeWork)

        store.pause(at: start.addingTimeInterval(90))

        XCTAssertTrue(store.discardPausedWork())
        XCTAssertNil(store.activeWork)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(store.draftNote, "")

        let restoredStore = WorkTimerStore(storageURL: storageURL)
        XCTAssertNil(restoredStore.activeWork)
        XCTAssertTrue(restoredStore.sessions.isEmpty)
    }

    func testTimerCompletesAtItsExactDeadlineAndRecordsOnce() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let start = Date(timeIntervalSince1970: 1_700_200_000)

        XCTAssertTrue(store.startTimer(duration: 600, at: start))
        XCTAssertEqual(store.activeWork?.resolvedMode, .timer)
        XCTAssertEqual(
            store.displayedDuration(at: start.addingTimeInterval(90)),
            510,
            accuracy: 0.001
        )
        XCTAssertEqual(
            store.activeProgress(at: start.addingTimeInterval(150)) ?? -1,
            0.25,
            accuracy: 0.001
        )
        XCTAssertNil(
            store.completeTimedActivity(
                at: start.addingTimeInterval(599)
            )
        )

        let completion = try XCTUnwrap(
            store.completeTimedActivity(
                at: start.addingTimeInterval(645)
            )
        )

        XCTAssertEqual(completion.kind, .timer)
        XCTAssertNil(store.activeWork)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions[0].totalDuration, 600, accuracy: 0.001)
        XCTAssertEqual(
            store.sessions[0].endedAt,
            start.addingTimeInterval(600)
        )
        XCTAssertNil(store.completeTimedActivity(at: start.addingTimeInterval(700)))
    }

    func testPausedTimerKeepsItsRemainingTimeAndRestoresFromDisk() throws {
        let storageURL = temporaryStorageURL()
        let start = Date(timeIntervalSince1970: 1_700_300_000)

        do {
            let store = WorkTimerStore(storageURL: storageURL)
            XCTAssertTrue(store.startTimer(duration: 900, at: start))
            store.pause(at: start.addingTimeInterval(240))
            XCTAssertNil(store.timedCompletionDelay(at: start.addingTimeInterval(500)))
            XCTAssertEqual(
                store.displayedDuration(at: start.addingTimeInterval(500)),
                660,
                accuracy: 0.001
            )
        }

        let restored = WorkTimerStore(storageURL: storageURL)
        XCTAssertTrue(restored.isPaused)
        XCTAssertEqual(restored.activeWork?.resolvedMode, .timer)
        XCTAssertEqual(restored.activeWork?.plannedDuration, 900)
        restored.resume(at: start.addingTimeInterval(600))
        XCTAssertEqual(
            restored.timedCompletionDelay(at: start.addingTimeInterval(700)) ?? -1,
            560,
            accuracy: 0.001
        )
    }

    func testPomodoroRecordsFocusButNeverCountsBreaksAsWork() throws {
        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        let start = Date(timeIntervalSince1970: 1_700_400_000)
        let configuration = PomodoroConfiguration(
            focusMinutes: 1,
            shortBreakMinutes: 1,
            longBreakMinutes: 2,
            sessionsBeforeLongBreak: 2
        )

        XCTAssertTrue(store.startPomodoro(configuration: configuration, at: start))

        let firstFocus = try XCTUnwrap(
            store.completeTimedActivity(at: start.addingTimeInterval(75))
        )
        XCTAssertEqual(firstFocus.kind, .focus(next: .shortBreak))
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions[0].totalDuration, 60, accuracy: 0.001)
        XCTAssertEqual(store.activeWork?.pomodoroPhase, .shortBreak)
        XCTAssertEqual(
            store.totalDuration(at: start.addingTimeInterval(90)),
            60,
            accuracy: 0.001
        )

        let firstBreak = try XCTUnwrap(
            store.completeTimedActivity(at: start.addingTimeInterval(125))
        )
        XCTAssertEqual(firstBreak.kind, .breakTime(next: .focus))
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.activeWork?.pomodoroPhase, .focus)

        let secondFocus = try XCTUnwrap(
            store.completeTimedActivity(at: start.addingTimeInterval(185))
        )
        XCTAssertEqual(secondFocus.kind, .focus(next: .longBreak))
        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertEqual(store.activeWork?.pomodoroPhase, .longBreak)
        XCTAssertEqual(store.activeWork?.plannedDuration, 120)
        XCTAssertEqual(
            store.totalDuration(at: start.addingTimeInterval(200)),
            120,
            accuracy: 0.001
        )
    }

    func testFinishingAPomodoroBreakDoesNotCreateAWorkRecord() throws {
        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        let start = Date(timeIntervalSince1970: 1_700_500_000)
        let configuration = PomodoroConfiguration(
            focusMinutes: 1,
            shortBreakMinutes: 1,
            longBreakMinutes: 1,
            sessionsBeforeLongBreak: 4
        )

        XCTAssertTrue(store.startPomodoro(configuration: configuration, at: start))
        _ = store.completeTimedActivity(at: start.addingTimeInterval(60))
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.activeWork?.pomodoroPhase, .shortBreak)

        XCTAssertNil(store.finish(at: start.addingTimeInterval(75)))
        XCTAssertNil(store.activeWork)
        XCTAssertEqual(store.sessions.count, 1)
    }

    func testSessionCrossingMidnightIsSplitAcrossDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let start = try XCTUnwrap(formatter.date(from: "2026-08-01T23:50:00Z"))
        let end = try XCTUnwrap(formatter.date(from: "2026-08-02T00:10:00Z"))
        let firstDay = try XCTUnwrap(formatter.date(from: "2026-08-01T12:00:00Z"))
        let secondDay = try XCTUnwrap(formatter.date(from: "2026-08-02T12:00:00Z"))

        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        store.start(at: start)
        store.finish(at: end)

        XCTAssertEqual(
            store.totalDuration(on: firstDay, at: end, calendar: calendar),
            600,
            accuracy: 0.001
        )
        XCTAssertEqual(
            store.totalDuration(on: secondDay, at: end, calendar: calendar),
            600,
            accuracy: 0.001
        )
    }

    func testConfiguredDayStartSplitsWorkAtThatBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let start = try XCTUnwrap(
            formatter.date(from: "2026-08-02T03:30:00Z")
        )
        let boundary = try XCTUnwrap(
            formatter.date(from: "2026-08-02T04:00:00Z")
        )
        let end = try XCTUnwrap(
            formatter.date(from: "2026-08-02T04:30:00Z")
        )
        let firstDay = try XCTUnwrap(
            formatter.date(from: "2026-08-01T12:00:00Z")
        )
        let secondDay = try XCTUnwrap(
            formatter.date(from: "2026-08-02T12:00:00Z")
        )
        let store = WorkTimerStore(storageURL: temporaryStorageURL())

        store.start(at: start)
        store.finish(at: end)

        XCTAssertEqual(
            WorkdayCalendar.day(
                containing: start,
                startHour: 4,
                calendar: calendar
            ),
            calendar.startOfDay(for: firstDay)
        )
        XCTAssertEqual(
            WorkdayCalendar.day(
                containing: boundary,
                startHour: 4,
                calendar: calendar
            ),
            calendar.startOfDay(for: secondDay)
        )
        XCTAssertEqual(
            store.totalDuration(
                on: firstDay,
                at: end,
                calendar: calendar,
                dayStartHour: 4
            ),
            1_800,
            accuracy: 0.001
        )
        XCTAssertEqual(
            store.totalDuration(
                on: secondDay,
                at: end,
                calendar: calendar,
                dayStartHour: 4
            ),
            1_800,
            accuracy: 0.001
        )

        let totals = store.dailyTotals(
            last: 2,
            through: secondDay,
            at: end,
            calendar: calendar,
            dayStartHour: 4
        )
        XCTAssertEqual(totals.map(\.duration), [1_800, 1_800])
    }

    func testDailyTotalsFillEmptyDaysAndFilterByTask() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let firstStart = try XCTUnwrap(formatter.date(from: "2026-07-31T10:00:00Z"))
        let secondStart = try XCTUnwrap(formatter.date(from: "2026-08-01T10:00:00Z"))
        let endingDay = try XCTUnwrap(formatter.date(from: "2026-08-02T12:00:00Z"))
        let store = WorkTimerStore(storageURL: temporaryStorageURL())

        let firstTask = try XCTUnwrap(store.addTask(named: "English"))
        store.start(at: firstStart)
        store.finish(at: firstStart.addingTimeInterval(60))

        store.addTask(named: "Writing")
        store.start(at: secondStart)
        store.finish(at: secondStart.addingTimeInterval(120))

        store.selectTask(id: firstTask.id)
        store.start(at: endingDay.addingTimeInterval(-3_600))

        let allTotals = store.dailyTotals(
            last: 3,
            through: endingDay,
            at: endingDay,
            calendar: calendar
        )
        let englishTotals = store.dailyTotals(
            last: 3,
            through: endingDay,
            forTaskID: firstTask.id,
            at: endingDay,
            calendar: calendar
        )

        XCTAssertEqual(allTotals.map(\.duration), [60, 120, 3_600])
        XCTAssertEqual(englishTotals.map(\.duration), [60, 0, 3_600])
        XCTAssertEqual(allTotals.map(\.day), allTotals.map(\.day).sorted())
    }

    func testHistoryRangesShareConsistentDateBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let oldStart = try XCTUnwrap(formatter.date(from: "2026-07-01T10:00:00Z"))
        let recentStart = try XCTUnwrap(formatter.date(from: "2026-08-02T10:00:00Z"))
        let endingDay = try XCTUnwrap(formatter.date(from: "2026-08-02T12:00:00Z"))
        let store = WorkTimerStore(storageURL: temporaryStorageURL())

        store.addTask(named: "History")
        store.start(at: oldStart)
        store.finish(at: oldStart.addingTimeInterval(60))
        store.start(at: recentStart)
        store.finish(at: recentStart.addingTimeInterval(120))

        let all = store.dailyTotals(
            in: .all,
            through: endingDay,
            at: endingDay,
            calendar: calendar
        )
        let thirtyDays = store.dailyTotals(
            in: .thirtyDays,
            through: endingDay,
            at: endingDay,
            calendar: calendar
        )
        let sevenDays = store.dailyTotals(
            in: .sevenDays,
            through: endingDay,
            at: endingDay,
            calendar: calendar
        )
        let today = store.dailyTotals(
            in: .today,
            through: endingDay,
            at: endingDay,
            calendar: calendar
        )

        XCTAssertEqual(all.first?.day, calendar.startOfDay(for: oldStart))
        XCTAssertEqual(all.last?.day, calendar.startOfDay(for: endingDay))
        XCTAssertEqual(all.reduce(0) { $0 + $1.duration }, 180, accuracy: 0.001)
        XCTAssertEqual(thirtyDays.count, 30)
        XCTAssertEqual(thirtyDays.reduce(0) { $0 + $1.duration }, 120, accuracy: 0.001)
        XCTAssertEqual(sevenDays.count, 7)
        XCTAssertEqual(sevenDays.reduce(0) { $0 + $1.duration }, 120, accuracy: 0.001)
        XCTAssertEqual(today.count, 1)
        XCTAssertEqual(today.first?.duration ?? -1, 120, accuracy: 0.001)
        XCTAssertEqual(
            store.sessions(
                in: .sevenDays,
                through: endingDay,
                at: endingDay,
                calendar: calendar
            ).count,
            1
        )
    }

    func testActivityCalendarPadsPartialWeeksFromSunday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let wednesday = try XCTUnwrap(formatter.date(from: "2026-08-05T12:00:00Z"))
        let thursday = try XCTUnwrap(formatter.date(from: "2026-08-06T12:00:00Z"))
        let points = [
            DailyWorkTotal(day: wednesday, duration: 60),
            DailyWorkTotal(day: thursday, duration: 120)
        ]

        let weeks = ActivityCalendar.weeks(from: points, calendar: calendar)

        XCTAssertEqual(weeks.count, 1)
        XCTAssertEqual(weeks.first?.days.count, 7)
        XCTAssertEqual(
            weeks.first.map { calendar.component(.weekday, from: $0.startDate) },
            1
        )
        XCTAssertNil(weeks.first?.days[0])
        XCTAssertNil(weeks.first?.days[1])
        XCTAssertNil(weeks.first?.days[2])
        XCTAssertEqual(weeks.first?.days[3]?.duration, 60)
        XCTAssertEqual(weeks.first?.days[4]?.duration, 120)
        XCTAssertNil(weeks.first?.days[5])
    }

    func testActivityCalendarStartsANewWeekBetweenSaturdayAndSunday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let saturday = try XCTUnwrap(formatter.date(from: "2026-08-08T12:00:00Z"))
        let sunday = try XCTUnwrap(formatter.date(from: "2026-08-09T12:00:00Z"))

        let weeks = ActivityCalendar.weeks(
            from: [
                DailyWorkTotal(day: saturday, duration: 60),
                DailyWorkTotal(day: sunday, duration: 120)
            ],
            calendar: calendar
        )

        XCTAssertEqual(weeks.count, 2)
        XCTAssertEqual(weeks[0].days[6]?.duration, 60)
        XCTAssertEqual(weeks[1].days[0]?.duration, 120)
        XCTAssertEqual(calendar.component(.weekday, from: weeks[1].startDate), 1)
    }

    func testSundayWeekDayCountRunsFromOneThroughSeven() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let sunday = try XCTUnwrap(formatter.date(from: "2026-08-09T12:00:00Z"))
        let wednesday = try XCTUnwrap(formatter.date(from: "2026-08-12T12:00:00Z"))
        let saturday = try XCTUnwrap(formatter.date(from: "2026-08-15T12:00:00Z"))

        XCTAssertEqual(
            ActivityCalendar.daysElapsedInSundayWeek(
                through: sunday,
                calendar: calendar
            ),
            1
        )
        XCTAssertEqual(
            ActivityCalendar.daysElapsedInSundayWeek(
                through: wednesday,
                calendar: calendar
            ),
            4
        )
        XCTAssertEqual(
            ActivityCalendar.daysElapsedInSundayWeek(
                through: saturday,
                calendar: calendar
            ),
            7
        )
    }

    func testSundayWeekRangeAlwaysRunsSundayThroughSaturday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let wednesday = try XCTUnwrap(formatter.date(from: "2026-08-12T12:00:00Z"))
        let expectedSunday = try XCTUnwrap(formatter.date(from: "2026-08-09T00:00:00Z"))
        let expectedSaturday = try XCTUnwrap(formatter.date(from: "2026-08-15T00:00:00Z"))

        let range = ActivityCalendar.sundayWeek(
            containing: wednesday,
            calendar: calendar
        )

        XCTAssertEqual(range.startDate, expectedSunday)
        XCTAssertEqual(range.endDate, expectedSaturday)
        XCTAssertEqual(range.dayCount, 7)
    }

    func testMonthRangeAlwaysRunsFromFirstThroughLastDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let august = try XCTUnwrap(formatter.date(from: "2026-08-12T12:00:00Z"))
        let leapFebruary = try XCTUnwrap(formatter.date(from: "2028-02-12T12:00:00Z"))

        let augustRange = ActivityCalendar.month(
            containing: august,
            calendar: calendar
        )
        let februaryRange = ActivityCalendar.month(
            containing: leapFebruary,
            calendar: calendar
        )

        XCTAssertEqual(
            augustRange.startDate,
            try XCTUnwrap(formatter.date(from: "2026-08-01T00:00:00Z"))
        )
        XCTAssertEqual(
            augustRange.endDate,
            try XCTUnwrap(formatter.date(from: "2026-08-31T00:00:00Z"))
        )
        XCTAssertEqual(augustRange.dayCount, 31)
        XCTAssertEqual(
            februaryRange.endDate,
            try XCTUnwrap(formatter.date(from: "2028-02-29T00:00:00Z"))
        )
        XCTAssertEqual(februaryRange.dayCount, 29)
    }

    func testDashboardPeriodsShiftAndDescribeCalendarRanges() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let wednesday = try XCTUnwrap(formatter.date(from: "2026-08-12T12:00:00Z"))

        let previousWeek = DashboardPeriod.week.shiftedDate(
            from: wednesday,
            by: -1,
            calendar: calendar
        )
        let previousMonth = DashboardPeriod.month.shiftedDate(
            from: wednesday,
            by: -1,
            calendar: calendar
        )

        XCTAssertEqual(
            DashboardPeriod.day.displayLabel(
                containing: wednesday,
                calendar: calendar
            ),
            "8/12 (Wed)"
        )
        XCTAssertEqual(
            DashboardPeriod.week.displayLabel(
                containing: previousWeek,
                calendar: calendar
            ),
            "8/2–8/8"
        )
        XCTAssertEqual(
            DashboardPeriod.month.displayLabel(
                containing: previousMonth,
                calendar: calendar
            ),
            "Jul"
        )
        XCTAssertEqual(
            DashboardPeriod.month.calendarRange(
                containing: previousMonth,
                calendar: calendar
            ).dayCount,
            31
        )
    }

    func testCompletedSessionCanEditNoteAndTimingAndPersists() throws {
        let storageURL = temporaryStorageURL()
        let start = Date(timeIntervalSince1970: 1_700_700_000)
        let store = WorkTimerStore(storageURL: storageURL)

        store.start(at: start)
        store.pause(at: start.addingTimeInterval(300))
        store.resume(at: start.addingTimeInterval(600))
        let session = try XCTUnwrap(store.finish(at: start.addingTimeInterval(900)))
        let originalSegments = session.segments

        XCTAssertTrue(store.updateSession(id: session.id, note: "  Added later  "))
        XCTAssertEqual(store.sessions.first?.note, "Added later")
        XCTAssertEqual(store.sessions.first?.startedAt, session.startedAt)
        XCTAssertEqual(store.sessions.first?.endedAt, session.endedAt)
        XCTAssertEqual(store.sessions.first?.segments, originalSegments)
        XCTAssertFalse(store.updateSession(id: UUID(), note: "Missing"))

        let replacementEnd = start.addingTimeInterval(10_000)
        XCTAssertTrue(
            store.updateSession(
                id: session.id,
                note: "  End anchored  ",
                anchorDate: replacementEnd,
                duration: 5_400,
                anchor: .end
            )
        )

        var edited = try XCTUnwrap(store.sessions.first)
        XCTAssertEqual(edited.note, "End anchored")
        XCTAssertEqual(edited.startedAt, replacementEnd.addingTimeInterval(-5_400))
        XCTAssertEqual(edited.endedAt, replacementEnd)
        XCTAssertEqual(
            edited.segments,
            [
                WorkSegment(
                    startedAt: replacementEnd.addingTimeInterval(-5_400),
                    endedAt: replacementEnd
                )
            ]
        )
        XCTAssertEqual(edited.totalDuration, 5_400, accuracy: 0.001)

        let replacementStart = start.addingTimeInterval(20_000)
        XCTAssertTrue(
            store.updateSession(
                id: session.id,
                note: "  Start anchored  ",
                anchorDate: replacementStart,
                duration: 3_600,
                anchor: .start
            )
        )

        edited = try XCTUnwrap(store.sessions.first)
        XCTAssertEqual(edited.note, "Start anchored")
        XCTAssertEqual(edited.startedAt, replacementStart)
        XCTAssertEqual(edited.endedAt, replacementStart.addingTimeInterval(3_600))
        XCTAssertEqual(edited.totalDuration, 3_600, accuracy: 0.001)

        let beforeInvalidEdit = edited
        XCTAssertFalse(
            store.updateSession(
                id: session.id,
                note: "Invalid",
                anchorDate: replacementStart,
                duration: 0,
                anchor: .start
            )
        )
        XCTAssertEqual(store.sessions.first, beforeInvalidEdit)

        let restoredStore = WorkTimerStore(storageURL: storageURL)
        XCTAssertEqual(restoredStore.sessions.first, edited)
    }

    func testManualSessionValidatesRangeAndPersists() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let task = try XCTUnwrap(store.addTask(named: "Manual"))
        let end = Date(timeIntervalSince1970: 1_700_805_400)
        let start = end.addingTimeInterval(-5_400)

        XCTAssertNil(
            store.addManualSession(
                duration: 0,
                endedAt: end,
                taskID: task.id
            )
        )
        XCTAssertNil(
            store.addManualSession(
                duration: 5_400,
                endedAt: end,
                taskID: UUID()
            )
        )
        XCTAssertTrue(store.sessions.isEmpty)

        let session = try XCTUnwrap(
            store.addManualSession(
                duration: 5_400,
                endedAt: end,
                taskID: task.id,
                note: "  Added manually  "
            )
        )

        XCTAssertEqual(session.taskID, task.id)
        XCTAssertEqual(session.subject, "Manual")
        XCTAssertEqual(session.note, "Added manually")
        XCTAssertEqual(session.startedAt, start)
        XCTAssertEqual(session.endedAt, end)
        XCTAssertEqual(session.segments, [WorkSegment(startedAt: start, endedAt: end)])
        XCTAssertEqual(session.totalDuration, 5_400, accuracy: 0.001)

        let restoredStore = WorkTimerStore(storageURL: storageURL)
        XCTAssertEqual(restoredStore.sessions, [session])
    }

    func testManualSessionSupportsStartAndEndAnchors() throws {
        let storageURL = temporaryStorageURL()
        let store = WorkTimerStore(storageURL: storageURL)
        let task = try XCTUnwrap(store.addTask(named: "Anchored"))
        let anchorDate = Date(timeIntervalSince1970: 1_700_900_000)

        let startAnchored = try XCTUnwrap(
            store.addManualSession(
                duration: 3_600,
                anchorDate: anchorDate,
                anchor: .start,
                taskID: task.id
            )
        )
        XCTAssertEqual(startAnchored.startedAt, anchorDate)
        XCTAssertEqual(startAnchored.endedAt, anchorDate.addingTimeInterval(3_600))

        let endAnchored = try XCTUnwrap(
            store.addManualSession(
                duration: 1_800,
                anchorDate: anchorDate,
                anchor: .end,
                taskID: task.id
            )
        )
        XCTAssertEqual(endAnchored.startedAt, anchorDate.addingTimeInterval(-1_800))
        XCTAssertEqual(endAnchored.endedAt, anchorDate)

        XCTAssertNil(
            store.addManualSession(
                duration: .infinity,
                anchorDate: anchorDate,
                anchor: .end,
                taskID: task.id
            )
        )

        let restoredStore = WorkTimerStore(storageURL: storageURL)
        XCTAssertEqual(Set(restoredStore.sessions), Set([startAnchored, endAnchored]))
    }

    func testManualSessionCanExplicitlyRecordNoItem() throws {
        let store = WorkTimerStore(storageURL: temporaryStorageURL())
        let activity = try XCTUnwrap(store.selectedTask)
        let item = try XCTUnwrap(
            store.addActivityTask(named: "Draft", to: activity.id)
        )
        store.selectActivityItem(id: item.id)

        let session = try XCTUnwrap(
            store.addManualSession(
                duration: 300,
                taskID: activity.id,
                activityItemID: nil,
                usesSelectedActivityItemWhenNil: false
            )
        )

        XCTAssertNil(session.activityItemID)
        XCTAssertNil(session.activityItemTitle)
        XCTAssertNil(session.activityItemKind)
        XCTAssertEqual(store.selectedActivityItemID, item.id)
    }

    func testTaskAnalyticsUseStableTaskBreakdownAndIncludeActiveWork() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let formatter = ISO8601DateFormatter()
        let firstDay = try XCTUnwrap(formatter.date(from: "2026-08-01T10:00:00Z"))
        let secondDay = try XCTUnwrap(formatter.date(from: "2026-08-02T10:00:00Z"))
        let endingDay = try XCTUnwrap(formatter.date(from: "2026-08-03T12:00:00Z"))
        let store = WorkTimerStore(storageURL: temporaryStorageURL())

        let english = try XCTUnwrap(store.addTask(named: "English"))
        store.start(at: firstDay)
        store.finish(at: firstDay.addingTimeInterval(60))

        let writing = try XCTUnwrap(store.addTask(named: "Writing"))
        store.start(at: secondDay)
        store.finish(at: secondDay.addingTimeInterval(120))

        store.selectTask(id: english.id)
        store.start(at: endingDay.addingTimeInterval(-600))

        let daily = store.dailyTaskTotals(
            last: 3,
            through: endingDay,
            at: endingDay,
            calendar: calendar
        )
        let totals = store.taskTotals(
            last: 3,
            through: endingDay,
            at: endingDay,
            calendar: calendar
        )

        XCTAssertEqual(daily.count, 3)
        XCTAssertEqual(daily.filter { $0.taskID == english.id }.map(\.duration), [60, 600])
        XCTAssertEqual(daily.filter { $0.taskID == writing.id }.map(\.duration), [120])
        XCTAssertEqual(totals.map(\.taskID), [english.id, writing.id])
        XCTAssertEqual(totals.map(\.duration), [660, 120])
        XCTAssertEqual(
            TaskColorPalette.index(for: english.id, name: english.name),
            TaskColorPalette.index(for: english.id, name: "Renamed")
        )
    }

    func testExportAndImportReplaceDataAfterCreatingBackup() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkIslandTransferTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let source = WorkTimerStore(
            storageURL: rootURL
                .appendingPathComponent("source", isDirectory: true)
                .appendingPathComponent("work-data.json")
        )
        let importedTask = try XCTUnwrap(source.addTask(named: "Imported"))
        let end = Date(timeIntervalSince1970: 1_700_900_300)
        _ = source.addManualSession(
            duration: 300,
            endedAt: end,
            taskID: importedTask.id,
            note: "From backup"
        )

        let exportURL = rootURL.appendingPathComponent("backup.json")
        try source.exportData(to: exportURL)

        let destination = WorkTimerStore(
            storageURL: rootURL
                .appendingPathComponent("destination", isDirectory: true)
                .appendingPathComponent("work-data.json")
        )
        _ = destination.addTask(named: "Existing")
        try destination.importData(from: exportURL)

        XCTAssertEqual(destination.sessions.count, 1)
        XCTAssertEqual(destination.sessions.first?.taskID, importedTask.id)
        XCTAssertEqual(destination.sessions.first?.note, "From backup")
        XCTAssertTrue(destination.tasks.contains { $0.id == importedTask.id })
        XCTAssertFalse(destination.tasks.contains { $0.name == "Existing" })

        let previous = WorkTimerStore(storageURL: destination.importBackupURL)
        XCTAssertTrue(previous.tasks.contains { $0.name == "Existing" })
        XCTAssertTrue(previous.sessions.isEmpty)
    }

    func testImportRefusesToReplaceAnActiveTimer() throws {
        let sourceURL = temporaryStorageURL()
        let source = WorkTimerStore(storageURL: sourceURL)
        let exportURL = sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("backup.json")
        try source.exportData(to: exportURL)

        let destination = WorkTimerStore(storageURL: temporaryStorageURL())
        destination.start(at: Date(timeIntervalSince1970: 1_700_910_000))

        XCTAssertThrowsError(try destination.importData(from: exportURL))
        XCTAssertNotNil(destination.activeWork)
    }

    private func temporaryStorageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkIslandTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("work-data.json")
    }
}
