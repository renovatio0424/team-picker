import XCTest
@testable import TeamPicker

final class TimerConfigurationTests: XCTestCase {

    func testDefaultValues() {
        let config = TimerConfiguration()
        XCTAssertEqual(config.durationSeconds, 60, "기본값은 60초(1분)이어야 한다")
    }

    func testRangeConstants() {
        XCTAssertEqual(TimerConfiguration.range.lowerBound, 30, "최소 30초")
        XCTAssertEqual(TimerConfiguration.range.upperBound, 180, "최대 180초(3분)")
        XCTAssertEqual(TimerConfiguration.step, 15, "15초 단위 조정")
    }

    func testDisplayTextMinutesOnly() {
        var config = TimerConfiguration()
        config.durationSeconds = 60
        XCTAssertEqual(config.displayText, "1분")

        config.durationSeconds = 120
        XCTAssertEqual(config.displayText, "2분")
    }

    func testDisplayTextWithSeconds() {
        var config = TimerConfiguration()
        config.durationSeconds = 45
        XCTAssertEqual(config.displayText, "0분 45초")

        config.durationSeconds = 90
        XCTAssertEqual(config.displayText, "1분 30초")
    }

    func testCodableRoundTrip() throws {
        var config = TimerConfiguration()
        config.durationSeconds = 90

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TimerConfiguration.self, from: data)

        XCTAssertEqual(config, decoded)
    }

    func testSaveAndLoad() {
        var config = TimerConfiguration()
        config.durationSeconds = 45
        config.save()

        let loaded = TimerConfiguration.load()
        XCTAssertEqual(loaded.durationSeconds, 45)

        // 정리: 기본값으로 복원
        TimerConfiguration().save()
    }
}
