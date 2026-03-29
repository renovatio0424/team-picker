import SwiftUI

struct PickerView: View {
    @ObservedObject var model: TeamPickerModel
    @Binding var isPresented: Bool

    @State private var displayTeams: [[Participant]] = []
    @State private var isAnimating = false
    @State private var isDone = false
    @State private var animationTask: Task<Void, Never>?

    private let animator = ShuffleAnimator<[[Participant]]>()

    private let teamColors: [Color] = [
        .blue, .orange, .green, .purple, .red, .teal, .pink, .indigo
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if displayTeams.isEmpty && !isAnimating {
                    Spacer()
                    Text("준비 중...")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(0..<model.numberOfTeams, id: \.self) { teamIndex in
                                teamCard(index: teamIndex)
                            }
                        }
                        .padding()
                    }
                }

                if isDone {
                    Button {
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom)
            .navigationTitle("팀 뽑기 결과")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { isPresented = false }
                }
            }
            .onAppear { startAnimation() }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
        }
    }

    private var gridColumns: [GridItem] {
        let count = model.numberOfTeams <= 4 ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    private func teamCard(index: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundStyle(teamColors[index % teamColors.count])
                Text("팀 \(index + 1)")
                    .font(.headline)
            }

            Divider()

            if index < displayTeams.count {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(displayTeams[index]) { participant in
                        Text(participant.name)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(teamColors[index % teamColors.count].opacity(isDone ? 0.6 : 0.2), lineWidth: 2)
        )
        .scaleEffect(isDone ? 1.0 : (isAnimating ? 0.98 : 1.0))
        .animation(.easeInOut(duration: 0.15), value: displayTeams)
    }

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
                guard !Task.isCancelled else { return }
                displayTeams = result
                isAnimating = false
                isDone = true
            }
        )
    }
}

#Preview {
    PickerView(
        model: {
            let m = TeamPickerModel()
            m.participants = [
                Participant(name: "Alice"),
                Participant(name: "Bob"),
                Participant(name: "Carol"),
                Participant(name: "Dave"),
                Participant(name: "Eve"),
                Participant(name: "Frank")
            ]
            m.numberOfTeams = 3
            return m
        }(),
        isPresented: .constant(true)
    )
}