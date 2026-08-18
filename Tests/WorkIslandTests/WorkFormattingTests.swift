import XCTest
@testable import WorkIsland

final class WorkFormattingTests: XCTestCase {
    func testElapsedClockNeverPadsItsLeadingField() {
        XCTAssertEqual(WorkFormatting.clock(0), "0:00")
        XCTAssertEqual(WorkFormatting.clock(2 * 60 + 5), "2:05")
        XCTAssertEqual(WorkFormatting.clock(59 * 60 + 59), "59:59")
        XCTAssertEqual(
            WorkFormatting.clock(2 * 3_600 + 3 * 60 + 4),
            "2:03:04"
        )
        XCTAssertEqual(
            WorkFormatting.clock(24 * 3_600 + 59 * 60),
            "24:59:00"
        )
    }

    func testHistoryDateAndTimeUseCompactEnglishTwentyFourHourFormat() throws {
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 8,
                    day: 3,
                    hour: 18,
                    minute: 5
                )
            )
        )

        XCTAssertEqual(WorkFormatting.time(date, timeZone: timeZone), "18:05")
        XCTAssertEqual(WorkFormatting.compactDate(date, timeZone: timeZone), "8/3 (Mon)")
    }
}
