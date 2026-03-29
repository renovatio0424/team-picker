# 스탠드업 미팅 MVP 구현 계획서 (TDD)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**목표:** 기존 TeamPicker 앱에 스탠드업 미팅 플로우를 추가한다 - 발표 순서를 랜덤 셔플하고, 설정 가능한 카운트다운 타이머와 함께 한 명씩 발표를 진행한다.

**아키텍처:** TabView 기반 네비게이션으로 기존 TeamPicker(탭 1)와 새로운 스탠드업 기능(탭 2)을 분리한다. 스탠드업은 PickerView에서 추출한 셔플 애니메이션 로직을 재사용하고, 타이머 기반 발표자 화면을 추가하며, UserDefaults + Codable로 팀원을 영속 저장한다.

**개발 방법론:** TDD (Test-Driven Development) - Red → Green → Refactor 사이클을 따른다. 모든 로직은 테스트를 먼저 작성하고, 테스트가 실패하는 것을 확인한 후, 최소 구현으로 통과시킨다.

**기술 스택:**
| 기술 | 용도 |
|------|------|
| SwiftUI | UI 프레임워크 (Mac + iPhone 멀티플랫폼) |
| iOS 17+ / macOS 14+ | 최소 배포 대상 |
| Swift 6 | 언어 버전 (strict concurrency) |
| UserDefaults + Codable | 팀원 명단 및 타이머 설정 로컬 영속화 |
| AudioToolbox (iOS) / AppKit (macOS) | 타이머 완료 시 알림음 재생 |
| async/await + Task | 타이머 카운트다운 및 셔플 애니메이션 비동기 처리 |
| `@MainActor` | Swift 6 concurrency 안전한 UI 상태 관리 |
| XCTest | 유닛 테스트 프레임워크 |

**기술 선택 이유:**
- **UserDefaults vs SwiftData**: 저장 데이터가 단순한 `[Participant]` 배열(6~10명)과 타이머 설정값뿐이므로, SwiftData는 과도함. UserDefaults + Codable이 적절.
- **Task.sleep vs Timer**: `@MainActor` 클래스에서 `Timer.scheduledTimer`의 클로저는 Swift 6 strict concurrency와 충돌할 수 있음. `Task { @MainActor in }` + `Task.sleep`이 더 안전.
- **ShuffleAnimator 제네릭**: PickerView는 `[[Participant]]`(2D 배열), 스탠드업은 `[Participant]`(1D 배열)을 셔플하므로, 제네릭 `<T>`로 추상화하여 DRY 원칙 준수.
- **`@MainActor` 클로저**: `@Sendable` 대신 `@MainActor` 클로저를 사용하여 non-Sendable 모델 타입을 안전하게 캡처.

**TDD 참고 사항:**
- 모델/로직 코드(TimerConfiguration, StandupModel, ShuffleAnimator)는 TDD Red-Green-Refactor 사이클을 엄격히 따른다.
- View 코드(StandupView, StandupSessionView, MainTabView)는 SwiftUI 특성상 유닛 테스트가 어려우므로, 모델 레이어 테스트로 커버하고 뷰는 수동 검증한다.
- SoundPlayer는 시스템 사운드 호출이므로 TDD 대상에서 제외한다.

---

## 파일 구조

### 새로 생성하는 파일
| 파일 | 역할 |
|------|------|
| `Sources/MainTabView.swift` | TabView 컨테이너 (팀뽑기 탭 + 스탠드업 탭) |
| `Sources/StandupView.swift` | 스탠드업 메인 화면: 멤버 관리 + 타이머 설정 + 시작 버튼 |
| `Sources/StandupSessionView.swift` | 셔플 애니메이션 → 타이머 진행 → 완료 화면 |
| `Sources/StandupModel.swift` | 스탠드업 데이터 모델: 멤버, 셔플, 타이머 로직, 영속화 |
| `Sources/TimerConfiguration.swift` | 타이머 설정값 struct + UserDefaults 저장 |
| `Sources/ShuffleAnimator.swift` | PickerView에서 추출한 범용 셔플 애니메이션 로직 |
| `Sources/SoundPlayer.swift` | iOS/macOS 크로스플랫폼 알림음 재생 |
| `TeamPickerTests/TimerConfigurationTests.swift` | TimerConfiguration 유닛 테스트 |
| `TeamPickerTests/StandupModelTests.swift` | StandupModel 유닛 테스트 |
| `TeamPickerTests/ShuffleAnimatorTests.swift` | ShuffleAnimator 유닛 테스트 |
| `TeamPickerTests/ParticipantTests.swift` | Participant Codable 유닛 테스트 |

### 수정하는 파일
| 파일 | 변경 내용 |
|------|-----------|
| `Sources/TeamPickerApp.swift` | 루트 뷰: `ContentView()` → `MainTabView()` |
| `Sources/TeamPickerModel.swift` | `Participant`에 `Codable` 채택 추가, `init` 명시 |
| `Sources/PickerView.swift` | 인라인 애니메이션 로직을 `ShuffleAnimator` 사용으로 변경 |
| `TeamPicker.xcodeproj/project.pbxproj` | 테스트 타겟 추가 + 새 파일 등록 |

---

## Task 1: 테스트 타겟 설정

**파일:**
- 수정: `TeamPicker.xcodeproj/project.pbxproj`
- 생성: `TeamPickerTests/` 디렉토리

**목적:** TDD를 진행하려면 XCTest 테스트 타겟이 필요하다. 현재 프로젝트에는 테스트 타겟이 없으므로 먼저 설정한다.

- [ ] **Step 1: 테스트 디렉토리 생성**

```bash
mkdir -p TeamPicker/TeamPickerTests
```

- [ ] **Step 2: Xcode에서 테스트 타겟 추가**

Xcode에서 프로젝트를 열고:
1. File → New → Target → Unit Testing Bundle
2. Product Name: `TeamPickerTests`
3. Team: 기존 설정 유지
4. Target to be Tested: `TeamPicker`

또는 `xcodebuild`로 직접 테스트 타겟이 동작하는지 확인. 테스트 타겟이 pbxproj에 등록되어야 한다.

- [ ] **Step 3: 빈 테스트 파일 생성하여 빌드 확인**

```swift
// TeamPicker/TeamPickerTests/TeamPickerTests.swift
import XCTest
@testable import TeamPicker

final class TeamPickerTests: XCTestCase {
    func testSanityCheck() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 4: 테스트 실행 확인**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: 1 test passed

- [ ] **Step 5: 커밋**

```bash
git add TeamPicker/TeamPickerTests/ TeamPicker.xcodeproj/project.pbxproj
git commit -m "chore: add XCTest target for TDD workflow"
```

---

## Task 2: Participant에 Codable 추가 (TDD)

**파일:**
- 생성: `TeamPicker/TeamPickerTests/ParticipantTests.swift`
- 수정: `TeamPicker/Sources/TeamPickerModel.swift:3-6`

**목적:** 팀원 데이터를 UserDefaults에 JSON으로 저장하려면 `Codable`이 필요하다. 기존 `let id = UUID()`는 Codable 자동 합성이 안 되므로, 명시적 `init`으로 변경한다.

- [ ] **Step 1: RED - 실패하는 테스트 작성**

```swift
// TeamPicker/TeamPickerTests/ParticipantTests.swift
import XCTest
@testable import TeamPicker

final class ParticipantTests: XCTestCase {

    func testCodableRoundTrip() throws {
        // Participant를 JSON으로 인코딩 후 디코딩하면 동일한 값이 복원되어야 한다
        let original = Participant(name: "Alice")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Participant.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.name, decoded.name)
    }

    func testCodableArrayRoundTrip() throws {
        // [Participant] 배열도 정상적으로 인코딩/디코딩되어야 한다
        let participants = [
            Participant(name: "Alice"),
            Participant(name: "Bob"),
            Participant(name: "Carol")
        ]
        let data = try JSONEncoder().encode(participants)
        let decoded = try JSONDecoder().decode([Participant].self, from: data)

        XCTAssertEqual(participants.count, decoded.count)
        for (original, restored) in zip(participants, decoded) {
            XCTAssertEqual(original.id, restored.id)
            XCTAssertEqual(original.name, restored.name)
        }
    }

    func testExistingInitStillWorks() {
        // 기존 Participant(name:) 호출 패턴이 그대로 동작해야 한다
        let p = Participant(name: "Test")
        XCTAssertFalse(p.name.isEmpty)
        XCTAssertFalse(p.id.uuidString.isEmpty)
    }
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: FAIL - `Participant`가 `Codable`을 채택하지 않아 `encode`/`decode` 컴파일 에러.

- [ ] **Step 3: GREEN - Participant struct 업데이트**

```swift
struct Participant: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: ALL TESTS PASSED

- [ ] **Step 5: 커밋**

```bash
git add TeamPicker/Sources/TeamPickerModel.swift TeamPicker/TeamPickerTests/ParticipantTests.swift
git commit -m "refactor: make Participant Codable with explicit init (TDD)"
```

---

## Task 3: TimerConfiguration 생성 (TDD)

**파일:**
- 생성: `TeamPicker/TeamPickerTests/TimerConfigurationTests.swift`
- 생성: `TeamPicker/Sources/TimerConfiguration.swift`

**목적:** 발표 제한시간 설정(기본 1분, 30초~3분 범위, 15초 단위)을 관리하고 UserDefaults에 영속 저장한다.

- [ ] **Step 1: RED - 실패하는 테스트 작성**

```swift
// TeamPicker/TeamPickerTests/TimerConfigurationTests.swift
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
        // 테스트용 UserDefaults 격리를 위해 save/load 후 정리
        var config = TimerConfiguration()
        config.durationSeconds = 45
        config.save()

        let loaded = TimerConfiguration.load()
        XCTAssertEqual(loaded.durationSeconds, 45)

        // 정리: 기본값으로 복원
        TimerConfiguration().save()
    }
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: FAIL - `TimerConfiguration` 타입이 존재하지 않아 컴파일 에러.

- [ ] **Step 3: GREEN - TimerConfiguration 구현**

```swift
// TeamPicker/Sources/TimerConfiguration.swift
import Foundation

struct TimerConfiguration: Codable, Equatable {
    var durationSeconds: Int = 60

    static let range = 30...180
    static let step = 15

    var displayText: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if seconds == 0 {
            return "\(minutes)분"
        }
        return "\(minutes)분 \(seconds)초"
    }

    private static let key = "standup_timer_config"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func load() -> TimerConfiguration {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(TimerConfiguration.self, from: data) else {
            return TimerConfiguration()
        }
        return config
    }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: ALL TESTS PASSED

- [ ] **Step 5: 커밋**

```bash
git add TeamPicker/Sources/TimerConfiguration.swift TeamPicker/TeamPickerTests/TimerConfigurationTests.swift
git commit -m "feat: add TimerConfiguration with TDD (default 60s, range 30-180s)"
```

---

## Task 4: ShuffleAnimator 추출 (TDD)

**파일:**
- 생성: `TeamPicker/TeamPickerTests/ShuffleAnimatorTests.swift`
- 생성: `TeamPicker/Sources/ShuffleAnimator.swift`
- 수정: `TeamPicker/Sources/PickerView.swift:108-133`

**목적:** PickerView의 슬롯머신 셔플 애니메이션 로직(30틱 cubic ease-out → spring 최종 결과)을 제네릭 클래스로 추출하여, 팀뽑기(`[[Participant]]`)와 스탠드업(`[Participant]`) 모두에서 재사용한다.

- [ ] **Step 1: RED - 실패하는 테스트 작성**

```swift
// TeamPicker/TeamPickerTests/ShuffleAnimatorTests.swift
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

        // 태스크 완료 대기
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

        // 약간의 지연 후 취소
        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()
        await task.value

        XCTAssertLessThan(tickCount, 100, "취소 시 모든 틱을 실행하지 않아야 한다")
    }

    func testGenericTypeSupport() async {
        // [String] 타입으로도 동작하는지 확인 (스탠드업용 [Participant] 대용)
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
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: FAIL - `ShuffleAnimator` 타입이 존재하지 않아 컴파일 에러.

- [ ] **Step 3: GREEN - ShuffleAnimator 구현**

```swift
// TeamPicker/Sources/ShuffleAnimator.swift
import SwiftUI

/// 범용 셔플 애니메이션 엔진. 모든 클로저는 MainActor에서 실행되므로
/// non-Sendable 모델 타입을 안전하게 캡처할 수 있다.
@MainActor
final class ShuffleAnimator<T> {
    let totalTicks: Int
    let baseInterval: TimeInterval

    init(totalTicks: Int = 30, baseInterval: TimeInterval = 0.05) {
        self.totalTicks = totalTicks
        self.baseInterval = baseInterval
    }

    func run(
        randomSnapshot: @MainActor () -> T,
        onTick: @MainActor (T) -> Void,
        finalResult: @MainActor () -> T,
        onComplete: @MainActor (T) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            for tick in 0..<totalTicks {
                let progress = Double(tick) / Double(totalTicks)
                let easeOut = 1 - pow(1 - progress, 3)
                let interval = baseInterval + easeOut * 0.35
                let nanoseconds = UInt64(interval * 1_000_000_000)

                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }

                onTick(randomSnapshot())
            }

            let result = finalResult()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                onComplete(result)
            }
        }
    }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: ALL TESTS PASSED

- [ ] **Step 5: REFACTOR - PickerView에서 ShuffleAnimator 사용하도록 리팩토링**

PickerView.swift의 `startAnimation()` 교체:

```swift
// PickerView에서 아래 프로퍼티 제거:
// private let totalTicks = 30
// private let baseInterval: TimeInterval = 0.05

// 아래 프로퍼티 추가:
private let animator = ShuffleAnimator<[[Participant]]>()

// startAnimation() 교체:
private func startAnimation() {
    isAnimating = true
    isDone = false
    displayTeams = model.randomSnapshot()

    animationTask = animator.run(
        randomSnapshot: { model.randomSnapshot() },
        onTick: { snapshot in
            displayTeams = snapshot
        },
        finalResult: { model.pickTeams() },
        onComplete: { result in
            displayTeams = result
            isAnimating = false
            isDone = true
        }
    )
}
```

- [ ] **Step 6: 빌드 및 기존 동작 확인**

```bash
xcodebuild build -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: BUILD SUCCEEDED - 기존 슬롯머신 애니메이션 동작 변경 없음.

- [ ] **Step 7: 전체 테스트 재실행**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: ALL TESTS PASSED

- [ ] **Step 8: 커밋**

```bash
git add TeamPicker/Sources/ShuffleAnimator.swift TeamPicker/Sources/PickerView.swift TeamPicker/TeamPickerTests/ShuffleAnimatorTests.swift
git commit -m "refactor: extract ShuffleAnimator from PickerView with TDD"
```

---

## Task 5: SoundPlayer 생성

**파일:**
- 생성: `TeamPicker/Sources/SoundPlayer.swift`

**목적:** 타이머 완료 시 알림음을 재생한다. iOS는 `AudioToolbox`의 시스템 사운드, macOS는 `NSSound.beep()`을 사용하여 크로스플랫폼 지원. 시스템 사운드 호출이므로 TDD 대상에서 제외한다.

- [ ] **Step 1: 크로스플랫폼 SoundPlayer 생성**

```swift
// TeamPicker/Sources/SoundPlayer.swift
import Foundation
#if os(iOS)
import AudioToolbox
#endif
#if os(macOS)
import AppKit
#endif

enum SoundPlayer {
    static func playTimerAlert() {
        #if os(iOS)
        AudioServicesPlaySystemSound(1005)
        #elseif os(macOS)
        NSSound.beep()
        #endif
    }
}
```

- [ ] **Step 2: 빌드**

```bash
xcodebuild build -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: BUILD SUCCEEDED

- [ ] **Step 3: 커밋**

```bash
git add TeamPicker/Sources/SoundPlayer.swift
git commit -m "feat: add cross-platform SoundPlayer for timer alerts"
```

---

## Task 6: StandupModel 생성 (TDD)

**파일:**
- 생성: `TeamPicker/TeamPickerTests/StandupModelTests.swift`
- 생성: `TeamPicker/Sources/StandupModel.swift`

**목적:** 스탠드업 미팅의 핵심 비즈니스 로직을 담당한다:
- 멤버 관리 (추가/삭제/영속 저장)
- 발표 순서 셔플
- 타이머 카운트다운 (`Task.sleep` 기반)
- 진행 상태 관리 (`StandupPhase`: idle → shuffling → presenting → completed)

- [ ] **Step 1: RED - 실패하는 테스트 작성**

```swift
// TeamPicker/TeamPickerTests/StandupModelTests.swift
import XCTest
@testable import TeamPicker

@MainActor
final class StandupModelTests: XCTestCase {

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

        // 정리
        model2.removeMember(at: IndexSet(integer: 0))
        model2.removeMember(at: IndexSet(integer: 0))
    }
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: FAIL - `StandupModel`, `StandupPhase` 타입이 존재하지 않아 컴파일 에러.

- [ ] **Step 3: GREEN - StandupModel 구현**

```swift
// TeamPicker/Sources/StandupModel.swift
import Foundation

enum StandupPhase: Equatable {
    case idle       // 시작 전
    case shuffling  // 셔플 애니메이션 중
    case presenting // 타이머 진행 중 (한 명씩 발표)
    case completed  // 전원 발표 완료
}

@MainActor
class StandupModel: ObservableObject {
    @Published var members: [Participant] = []
    @Published var shuffledOrder: [Participant] = []
    @Published var currentIndex: Int = 0
    @Published var timerRemaining: TimeInterval = 0
    @Published var isTimerRunning: Bool = false
    @Published var phase: StandupPhase = .idle
    @Published var timerConfig: TimerConfiguration

    private var timerTask: Task<Void, Never>?
    private static let membersKey = "standup_members"

    var currentPresenter: Participant? {
        guard phase == .presenting,
              currentIndex < shuffledOrder.count else { return nil }
        return shuffledOrder[currentIndex]
    }

    var progress: Double {
        guard timerConfig.durationSeconds > 0 else { return 0 }
        return timerRemaining / TimeInterval(timerConfig.durationSeconds)
    }

    var canStart: Bool {
        members.count >= 2
    }

    init() {
        self.timerConfig = TimerConfiguration.load()
        self.members = Self.loadMembers()
    }

    // MARK: - 멤버 관리

    func addMember(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        members.append(Participant(name: trimmed))
        saveMembers()
    }

    func removeMember(at offsets: IndexSet) {
        members.remove(atOffsets: offsets)
        saveMembers()
    }

    // MARK: - 스탠드업 플로우

    func shuffleOrder() -> [Participant] {
        let order = members.shuffled()
        shuffledOrder = order
        return order
    }

    func randomOrderSnapshot() -> [Participant] {
        members.shuffled()
    }

    func beginPresenting() {
        currentIndex = 0
        phase = .presenting
        startTimer()
    }

    func advanceToNext() {
        timerTask?.cancel()
        isTimerRunning = false

        currentIndex += 1
        if currentIndex >= shuffledOrder.count {
            phase = .completed
        } else {
            startTimer()
        }
    }

    func reset() {
        timerTask?.cancel()
        isTimerRunning = false
        timerRemaining = 0
        currentIndex = 0
        shuffledOrder = []
        phase = .idle
    }

    // MARK: - 타이머

    func startTimer() {
        timerRemaining = TimeInterval(timerConfig.durationSeconds)
        isTimerRunning = true
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while timerRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                timerRemaining -= 1
            }
            if !Task.isCancelled {
                isTimerRunning = false
                SoundPlayer.playTimerAlert()
            }
        }
    }

    func saveTimerConfig() {
        timerConfig.save()
    }

    // MARK: - 영속화

    private func saveMembers() {
        if let data = try? JSONEncoder().encode(members) {
            UserDefaults.standard.set(data, forKey: Self.membersKey)
        }
    }

    private static func loadMembers() -> [Participant] {
        guard let data = UserDefaults.standard.data(forKey: membersKey),
              let members = try? JSONDecoder().decode([Participant].self, from: data) else {
            return []
        }
        return members
    }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: ALL TESTS PASSED

- [ ] **Step 5: 커밋**

```bash
git add TeamPicker/Sources/StandupModel.swift TeamPicker/TeamPickerTests/StandupModelTests.swift
git commit -m "feat: add StandupModel with member management, timer, and persistence (TDD)"
```

---

## Task 7: StandupView와 StandupSessionView 생성

**파일:**
- 생성: `TeamPicker/Sources/StandupView.swift`
- 생성: `TeamPicker/Sources/StandupSessionView.swift`

**목적:** 스탠드업 미팅의 두 가지 화면을 구현한다. SwiftUI View는 유닛 테스트가 어려우므로, 이미 TDD로 검증된 StandupModel 위에 뷰를 구성하고 수동 검증한다.

참고: 두 뷰가 서로 참조하므로(StandupView가 StandupSessionView를 fullScreenCover로 열음) 함께 생성해야 빌드가 성공한다.

- [ ] **Step 1: StandupView 생성**

```swift
// TeamPicker/Sources/StandupView.swift
import SwiftUI

struct StandupView: View {
    @StateObject private var model = StandupModel()
    @State private var newName = ""
    @State private var showSession = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 멤버 이름 입력
                HStack {
                    TextField("멤버 이름", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addMember() }

                    Button(action: addMember) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()

                // 타이머 설정
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
                    Stepper(
                        "발표 시간: \(model.timerConfig.displayText)",
                        value: $model.timerConfig.durationSeconds,
                        in: TimerConfiguration.range,
                        step: TimerConfiguration.step
                    )
                    .onChange(of: model.timerConfig.durationSeconds) {
                        model.saveTimerConfig()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)

                // 멤버 리스트
                List {
                    Section {
                        ForEach(model.members) { member in
                            HStack {
                                Text("\((model.members.firstIndex(of: member) ?? 0) + 1).")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text(member.name)
                            }
                        }
                        .onDelete(perform: model.removeMember)
                    } header: {
                        Text("멤버 \(model.members.count)명")
                    }
                }
                .listStyle(.insetGrouped)

                // 시작 버튼
                Button {
                    showSession = true
                } label: {
                    Label("스탠드업 시작", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(model.canStart ? Color.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!model.canStart)
                .padding()
            }
            .navigationTitle("스탠드업")
            .fullScreenCover(isPresented: $showSession) {
                StandupSessionView(model: model, isPresented: $showSession)
            }
        }
    }

    private func addMember() {
        model.addMember(newName)
        newName = ""
    }
}

#Preview {
    StandupView()
}
```

- [ ] **Step 2: StandupSessionView 생성**

이 뷰는 3단계(phase)로 구성된다:
1. **shuffling**: 이름들이 빠르게 셔플되는 애니메이션 (ShuffleAnimator 사용)
2. **presenting**: 현재 발표자 이름 + 원형 타이머 프로그레스 링 + 다음 버튼
3. **completed**: "스탠드업 완료!" 메시지 + 돌아가기 버튼

```swift
// TeamPicker/Sources/StandupSessionView.swift
import SwiftUI

struct StandupSessionView: View {
    @ObservedObject var model: StandupModel
    @Binding var isPresented: Bool

    @State private var displayOrder: [Participant] = []
    @State private var animationTask: Task<Void, Never>?

    private let animator = ShuffleAnimator<[Participant]>()

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .idle, .shuffling:
                    shufflePhase
                case .presenting:
                    presenterPhase
                case .completed:
                    completedPhase
                }
            }
            .navigationTitle("스탠드업 진행")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        model.reset()
                        isPresented = false
                    }
                }
            }
            .onAppear { startShuffle() }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
        }
    }

    // MARK: - 셔플 단계

    private var shufflePhase: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("순서를 정하고 있어요...")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(Array(displayOrder.enumerated()), id: \.element.id) { index, participant in
                    HStack {
                        Text("\(index + 1).")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                        Text(participant.name)
                            .font(.title3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)
                }
            }

            Spacer()
        }
    }

    // MARK: - 발표 진행 단계

    private var presenterPhase: some View {
        VStack(spacing: 24) {
            // 진행 표시 (몇 번째 / 전체)
            Text("\(model.currentIndex + 1) / \(model.shuffledOrder.count)")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()

            // 현재 발표자 이름
            if let presenter = model.currentPresenter {
                Text(presenter.name)
                    .font(.system(size: 36, weight: .bold))
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(presenter.id)
            }

            // 원형 타이머 프로그레스 링
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(
                        model.isTimerRunning ? Color.accentColor : Color.orange,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: model.progress)

                Text(timerText)
                    .font(.system(size: 48, weight: .medium, design: .monospaced))
                    .contentTransition(.numericText())
            }
            .frame(width: 200, height: 200)

            Spacer()

            // 다음 버튼 (타이머 완료 후 활성화)
            Button {
                withAnimation {
                    model.advanceToNext()
                }
            } label: {
                Label(
                    model.currentIndex < model.shuffledOrder.count - 1 ? "다음" : "완료",
                    systemImage: model.currentIndex < model.shuffledOrder.count - 1
                        ? "forward.fill" : "checkmark"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(!model.isTimerRunning ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(model.isTimerRunning)
            .padding(.horizontal)
        }
        .padding(.bottom)
    }

    // MARK: - 완료 단계

    private var completedPhase: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("스탠드업 완료!")
                .font(.title)
                .fontWeight(.bold)

            Text("\(model.shuffledOrder.count)명 발표 완료")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                model.reset()
                isPresented = false
            } label: {
                Label("돌아가기", systemImage: "arrow.uturn.backward")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }

    // MARK: - 헬퍼

    private var timerText: String {
        let minutes = Int(model.timerRemaining) / 60
        let seconds = Int(model.timerRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startShuffle() {
        model.phase = .shuffling
        displayOrder = model.randomOrderSnapshot()

        animationTask = animator.run(
            randomSnapshot: { model.randomOrderSnapshot() },
            onTick: { snapshot in
                displayOrder = snapshot
            },
            finalResult: { model.shuffleOrder() },
            onComplete: { result in
                displayOrder = result
                model.beginPresenting()
            }
        )
    }
}

#Preview {
    let model = StandupModel()
    StandupSessionView(model: model, isPresented: .constant(true))
}
```

- [ ] **Step 3: 빌드 + 전체 테스트**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: BUILD SUCCEEDED, ALL TESTS PASSED (기존 테스트 모두 통과)

- [ ] **Step 4: 커밋**

```bash
git add TeamPicker/Sources/StandupView.swift TeamPicker/Sources/StandupSessionView.swift
git commit -m "feat: add StandupView and StandupSessionView with shuffle and timer"
```

---

## Task 8: MainTabView 생성 및 네비게이션 연결

**파일:**
- 생성: `TeamPicker/Sources/MainTabView.swift`
- 수정: `TeamPicker/Sources/TeamPickerApp.swift:7`

**목적:** 앱의 루트 뷰를 TabView로 변경하여 기존 팀뽑기(탭 1)와 새 스탠드업(탭 2)을 분리한다.

- [ ] **Step 1: MainTabView 생성**

```swift
// TeamPicker/Sources/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("팀 뽑기", systemImage: "person.3.fill")
                }

            StandupView()
                .tabItem {
                    Label("스탠드업", systemImage: "clock.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
}
```

- [ ] **Step 2: TeamPickerApp 엔트리포인트 업데이트**

`TeamPickerApp.swift`에서 `ContentView()`를 `MainTabView()`로 변경:

```swift
import SwiftUI

@main
struct TeamPickerApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
```

- [ ] **Step 3: 빌드 + 전체 테스트**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: BUILD SUCCEEDED, ALL TESTS PASSED

- [ ] **Step 4: 커밋**

```bash
git add TeamPicker/Sources/MainTabView.swift TeamPicker/Sources/TeamPickerApp.swift
git commit -m "feat: add MainTabView with TeamPicker and Standup tabs"
```

---

## Task 9: Xcode 프로젝트에 새 파일 등록

**파일:**
- 수정: `TeamPicker.xcodeproj/project.pbxproj`

**목적:** 새로 생성한 Swift 파일들이 Xcode 빌드 타겟에 포함되어 있는지 확인한다. `.xcodeproj` 프로젝트에서는 SPM과 달리 새 파일을 `project.pbxproj`에 수동 등록해야 할 수 있다.

- [ ] **Step 1: 모든 새 파일이 빌드 타겟에 포함되었는지 확인**

앱 타겟에 포함될 파일:
- `Sources/MainTabView.swift`
- `Sources/StandupView.swift`
- `Sources/StandupSessionView.swift`
- `Sources/StandupModel.swift`
- `Sources/TimerConfiguration.swift`
- `Sources/ShuffleAnimator.swift`
- `Sources/SoundPlayer.swift`

테스트 타겟에 포함될 파일:
- `TeamPickerTests/ParticipantTests.swift`
- `TeamPickerTests/TimerConfigurationTests.swift`
- `TeamPickerTests/ShuffleAnimatorTests.swift`
- `TeamPickerTests/StandupModelTests.swift`

- [ ] **Step 2: 양 플랫폼에서 빌드 + 전체 테스트**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: BUILD SUCCEEDED, ALL TESTS PASSED

- [ ] **Step 3: 프로젝트 파일 변경 시 커밋**

```bash
git add TeamPicker.xcodeproj/project.pbxproj
git commit -m "chore: register new standup and test files in Xcode project"
```

---

## Task 10: 전체 검증 (End-to-End)

**목적:** 모든 기능이 정상 동작하는지 확인한다. 자동 테스트 + 수동 검증을 조합한다.

- [ ] **Step 1: 전체 테스트 스위트 실행**

```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=iOS Simulator,name=iPhone 16'
```

예상 결과: ALL TESTS PASSED - ParticipantTests, TimerConfigurationTests, ShuffleAnimatorTests, StandupModelTests 모두 통과.

- [ ] **Step 2: 팀뽑기 탭 수동 검증**

1. 앱 실행 → "팀 뽑기" 탭 선택 가능
2. 참여자 추가 → "팀 뽑기!" 버튼 → 슬롯머신 애니메이션이 기존과 동일하게 동작
3. 닫기 후 복귀 → 기존 기능 정상

- [ ] **Step 3: 스탠드업 탭 수동 검증**

1. "스탠드업" 탭으로 전환
2. 멤버 3명 이상 추가 → 앱 재시작 후에도 이름이 유지됨
3. 타이머 설정 변경 (예: 30초) → 앱 재시작 후에도 설정 유지
4. "스탠드업 시작" 탭

- [ ] **Step 4: 셔플 애니메이션 수동 검증**

1. 이름들이 세로 리스트에서 빠르게 셔플됨
2. 애니메이션이 ease-out으로 감속
3. 최종 순서가 spring 애니메이션으로 확정

- [ ] **Step 5: 타이머 진행 수동 검증**

1. 첫 번째 발표자가 이름 + 카운트다운 타이머 링과 함께 표시됨
2. 설정된 시간만큼 타이머 카운트다운
3. 타이머 0 도달 시: 알림음 재생, "다음" 버튼 활성화
4. "다음" 탭 → 다음 발표자 + 타이머 리셋
5. 마지막 발표자 이후 → "스탠드업 완료!" 화면
6. "돌아가기" 탭 → StandupView로 복귀

- [ ] **Step 6: 크로스플랫폼 검증 (가능한 경우)**

macOS 타겟 빌드 및 테스트:
```bash
xcodebuild test -project TeamPicker.xcodeproj -scheme TeamPicker -destination 'platform=macOS'
```

- [ ] **Step 7: 최종 커밋**

```bash
git commit --allow-empty -m "test: verify standup meeting MVP end-to-end - all tests passing"
```
