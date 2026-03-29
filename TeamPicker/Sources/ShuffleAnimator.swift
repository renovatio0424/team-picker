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
        randomSnapshot: @escaping @MainActor () -> T,
        onTick: @escaping @MainActor (T) -> Void,
        finalResult: @escaping @MainActor () -> T,
        onComplete: @escaping @MainActor (T) -> Void
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

            guard !Task.isCancelled else { return }

            let result = finalResult()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                onComplete(result)
            }
        }
    }
}
