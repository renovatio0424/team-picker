import XCTest
@testable import TeamPicker

@MainActor
final class StandupModelTests: XCTestCase {

    private let membersKey = "standup_members"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: membersKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: membersKey)
        super.tearDown()
    }

    // MARK: - 멤버 관리

    func testAddMember() {
        let model = StandupModel()
        model.addMember("Alice")

        XCTAssertEqual(model.members.count, 1)
        XCTAssertEqual(model.members.first?.name, "Alice")
    }

    func testAddMemberTrimsWhitespace() {
        let model = StandupModel()
        model.addMember("  Bob  ")

        XCTAssertEqual(model.members.first?.name, "Bob")
    }

    func testAddEmptyMemberIgnored() {
        let model = StandupModel()
        model.addMember("")
        model.addMember("   ")

        XCTAssertTrue(model.members.isEmpty, "빈 이름은 추가되지 않아야 한다")
    }

    func testRemoveMember() {
        let model = StandupModel()
        model.addMember("Alice")
        model.addMember("Bob")
        model.removeMember(at: IndexSet(integer: 0))

        XCTAssertEqual(model.members.count, 1)
        XCTAssertEqual(model.members.first?.name, "Bob")
    }

    // MARK: - canStart

    func testCanStartRequiresAtLeastTwo() {
        let model = StandupModel()
        XCTAssertFalse(model.canStart)

        model.addMember("Alice")
        XCTAssertFalse(model.canStart)

        model.addMember("Bob")
        XCTAssertTrue(model.canStart)
    }

    // MARK: - 셔플

    func testShuffleOrderPreservesAllMembers() {
        let model = StandupModel()
        model.addMember("Alice")
        model.addMember("Bob")
        model.addMember("Carol")

        let order = model.shuffleOrder()

        XCTAssertEqual(order.count, 3)
        let names = Set(order.map(\.name))
        XCTAssertEqual(names, Set(["Alice", "Bob", "Carol"]), "셔플 후에도 모든 멤버가 포함되어야 한다")
    }

    func testShuffleOrderSetsShuffledOrder() {
        let model = StandupModel()
        model.addMember("Alice")
        model.addMember("Bob")

        let order = model.shuffleOrder()
        XCTAssertEqual(model.shuffledOrder, order)
    }

    func testRandomOrderSnapshotDoesNotMutateState() {
        let model = StandupModel()
        model.addMember("Alice")
        model.addMember("Bob")

        _ = model.randomOrderSnapshot()
        XCTAssertTrue(model.shuffledOrder.isEmpty, "randomOrderSnapshot은 shuffledOrder를 변경하지 않아야 한다")
    }

    // MARK: - 진행 플로우

    func testBeginPresenting() {
        let model = StandupModel()
        model.addMember("Alice")
        model.addMember("Bob")
        _ = model.shuffleOrder()
        model.beginPresenting()

        XCTAssertEqual(model.phase, .presenting)
        XCTAssertEqual(model.currentIndex, 0)
        XCTAssertTrue(model.isTimerRunning)
    }

    func testCurrentPresenter() {
        let model = StandupModel()
        model.addMember("Alice")
        model.addMember("Bob")
        _ = model.shuffleOrder()
        model.beginPresenting()

        XCTAssertNotNil(model.currentPresenter)
        XCTAssertEqual(model.currentPresenter, model.shuffledOrder[0])
    }

    func testCurrentPresenterNilWhenIdle() {
        let model = StandupModel()
        model.addMember("Alice")

        XCTAssertNil(model.currentPresenter, "idle 상태에서는 currentPresenter가 nil이어야 한다")
    }

    func testAdvanceToNext() {
        let model = StandupModel()
        model.addMember("Alice")
        model.addMember("Bob")
        model.addMember("Carol")
        _ = model.shuffleOrder()
        model.beginPresenting()

        model.advanceToNext()

        XCTAssertEqual(model.currentIndex, 1)
        XCTAssertEqual(model.phase, .presenting, "아직 발표자가 남아있으므로 presenting 상태 유지")
    }

    func testAdvanceToNextCompletesAfterLastMember() {
        let model = StandupModel()
        model.addMember("Alice")
        model.addMember("Bob")
        _ = model.shuffleOrder()
        model.beginPresenting()

        model.advanceToNext() // Bob 차례
        model.advanceToNext() // 마지막 → completed

        XCTAssertEqual(model.phase, .completed)
    }

    func testReset() {
        let model = StandupModel()
        model.addMember("Alice")
        model.addMember("Bob")
        _ = model.shuffleOrder()
        model.beginPresenting()
        model.advanceToNext()

        model.reset()

        XCTAssertEqual(model.phase, .idle)
        XCTAssertEqual(model.currentIndex, 0)
        XCTAssertTrue(model.shuffledOrder.isEmpty)
        XCTAssertFalse(model.isTimerRunning)
        XCTAssertEqual(model.timerRemaining, 0)
    }

    // MARK: - 타이머

    func testTimerStartsSetsRemaining() {
        let model = StandupModel()
        model.timerConfig.durationSeconds = 30
        model.addMember("Alice")
        model.addMember("Bob")
        _ = model.shuffleOrder()
        model.beginPresenting()

        XCTAssertEqual(model.timerRemaining, 30, "타이머는 설정된 시간으로 시작해야 한다")
        XCTAssertTrue(model.isTimerRunning)
    }

    func testProgressCalculation() {
        let model = StandupModel()
        model.timerConfig.durationSeconds = 60
        model.timerRemaining = 30

        XCTAssertEqual(model.progress, 0.5, accuracy: 0.01)
    }

    func testProgressZeroWhenDurationZero() {
        let model = StandupModel()
        model.timerConfig.durationSeconds = 0

        XCTAssertEqual(model.progress, 0)
    }

    // MARK: - 영속화

    func testMemberPersistence() {
        // 저장
        let model1 = StandupModel()
        model1.addMember("Alice")
        model1.addMember("Bob")

        // 새 인스턴스에서 로드
        let model2 = StandupModel()
        XCTAssertEqual(model2.members.count, 2)
        XCTAssertEqual(model2.members.map(\.name), ["Alice", "Bob"])
    }
}
