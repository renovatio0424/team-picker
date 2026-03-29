import SwiftUI

@MainActor
protocol HapticFeedbackProvider {
    func lightImpact(intensity: Double)
    func heavyImpact()
}

@MainActor
final class HapticManager {
    private let provider: HapticFeedbackProvider

    init(provider: HapticFeedbackProvider? = nil) {
        self.provider = provider ?? Self.platformProvider()
    }

    func tick(intensity: Double = 0.5) {
        provider.lightImpact(intensity: intensity)
    }

    func selection() {
        provider.heavyImpact()
    }

    private static func platformProvider() -> HapticFeedbackProvider {
        #if os(iOS)
        return IOSHapticProvider()
        #else
        return NoOpHapticProvider()
        #endif
    }
}

// MARK: - Platform Providers

#if os(iOS)
import UIKit

private final class IOSHapticProvider: HapticFeedbackProvider {
    func lightImpact(intensity: Double) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: CGFloat(intensity))
    }

    func heavyImpact() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
#endif

private final class NoOpHapticProvider: HapticFeedbackProvider {
    func lightImpact(intensity: Double) {}
    func heavyImpact() {}
}
