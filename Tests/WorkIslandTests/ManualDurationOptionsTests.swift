import XCTest
@testable import WorkIsland

final class ManualDurationOptionsTests: XCTestCase {
    func testMinuteChoicesFollowCustomStepWithoutSixty() {
        XCTAssertEqual(
            ManualDurationOptions.minutes(for: 5),
            Array(stride(from: 0, to: 60, by: 5))
        )
        XCTAssertEqual(ManualDurationOptions.minutes(for: 7), [0, 7, 14, 21, 28, 35, 42, 49, 56])
        XCTAssertEqual(ManualDurationOptions.minutes(for: 30), [0, 30])
        XCTAssertFalse(ManualDurationOptions.minutes(for: 1).contains(60))
    }

    func testMinuteSnappingAndDurationCalculation() {
        XCTAssertEqual(ManualDurationOptions.snappedMinute(7, step: 5), 5)
        XCTAssertEqual(ManualDurationOptions.snappedMinute(58, step: 5), 55)
        XCTAssertEqual(ManualDurationOptions.snappedMinute(58, step: 7), 56)
        XCTAssertEqual(
            ManualDurationOptions.duration(hours: 1, minutes: 30),
            5_400,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ManualDurationOptions.duration(hours: 1, minutes: 60),
            7_140,
            accuracy: 0.001
        )
    }

    func testMinuteStepValidationKeepsCustomValuesAndRepairsInvalidOnes() {
        XCTAssertEqual(ManualDurationOptions.normalizedStep(1), 1)
        XCTAssertEqual(ManualDurationOptions.normalizedStep(17), 17)
        XCTAssertEqual(ManualDurationOptions.normalizedStep(59), 59)
        XCTAssertEqual(
            ManualDurationOptions.normalizedStep(0),
            ManualDurationOptions.defaultMinuteStep
        )
        XCTAssertEqual(
            ManualDurationOptions.normalizedStep(60),
            ManualDurationOptions.defaultMinuteStep
        )
    }
}
