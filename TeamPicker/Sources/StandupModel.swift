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
