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
        model.beginShuffling()
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
