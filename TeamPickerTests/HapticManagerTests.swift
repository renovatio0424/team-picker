import XCTest
@testable import TeamPicker

@MainActor
final class HapticManagerTests: XCTestCase {

    func testTickTriggersLightImpact() {
        let spy = HapticSpy()
        let manager = HapticManager(provider: spy)

        manager.tick()

        XCTAssertEqual(spy.lightImpactCount, 1)
    }

    func testSelectionTriggersHeavyImpact() {
        let spy = HapticSpy()
        let manager = HapticManager(provider: spy)

        manager.selection()

        XCTAssertEqual(spy.heavyImpactCount, 1)
    }

    func testTickIntensityIncreasesWithProgress() {
        let spy = HapticSpy()
        let manager = HapticManager(provider: spy)

        manager.tick(intensity: 0.3)
        manager.tick(intensity: 0.9)

        XCTAssertEqual(spy.lastIntensities.count, 2)
        XCTAssertEqual(spy.lastIntensities[0], 0.3, accuracy: 0.01)
        XCTAssertEqual(spy.lastIntensities[1], 0.9, accuracy: 0.01)
    }
}

// MARK: - Test Double

@MainActor
final class HapticSpy: HapticFeedbackProvider {
    var lightImpactCount = 0
    var heavyImpactCount = 0
    var lastIntensities: [Double] = []

    func lightImpact(intensity: Double) {
        lightImpactCount += 1
        lastIntensities.append(intensity)
    }

    func heavyImpact() {
        heavyImpactCount += 1
    }
}
