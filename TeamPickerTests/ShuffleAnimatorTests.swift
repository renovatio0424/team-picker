import XCTest
@testable import TeamPicker

@MainActor
final class ShuffleAnimatorTests: XCTestCase {

    func testOnTickCalledExpectedTimes() async {
        let animator = ShuffleAnimator<Int>(totalTicks: 5, baseInterval: 0.01)
        var tickCount = 0

        let task = animator.run(
            randomSnapshot: { Int.random(in: 0...100) },
            onTick: { _ in tickCount += 1 },
            finalResult: { 42 },
            onComplete: { _ in }
        )

        await task.value

        XCTAssertEqual(tickCount, 5, "onTick은 totalTicks(5)번 호출되어야 한다")
    }

    func testFinalResultDelivered() async {
        let animator = ShuffleAnimator<String>(totalTicks: 3, baseInterval: 0.01)
        var completedValue: String?

        let task = animator.run(
            randomSnapshot: { "random" },
            onTick: { _ in },
            finalResult: { "FINAL" },
            onComplete: { value in completedValue = value }
        )

        await task.value

        XCTAssertEqual(completedValue, "FINAL", "onComplete에 finalResult 값이 전달되어야 한다")
    }

    func testCancellation() async {
        let animator = ShuffleAnimator<Int>(totalTicks: 100, baseInterval: 0.05)
        var tickCount = 0

        let task = animator.run(
            randomSnapshot: { 0 },
            onTick: { _ in tickCount += 1 },
            finalResult: { 0 },
            onComplete: { _ in }
        )

        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()
        await task.value

        XCTAssertLessThan(tickCount, 100, "취소 시 모든 틱을 실행하지 않아야 한다")
    }

    func testGenericTypeSupport() async {
        let animator = ShuffleAnimator<[String]>(totalTicks: 2, baseInterval: 0.01)
        var completedValue: [String]?

        let task = animator.run(
            randomSnapshot: { ["A", "B", "C"].shuffled() },
            onTick: { _ in },
            finalResult: { ["X", "Y", "Z"] },
            onComplete: { value in completedValue = value }
        )

        await task.value

        XCTAssertEqual(completedValue, ["X", "Y", "Z"])
    }
}
