import SwiftUI

struct StandupView: View {
    @StateObject private var model = StandupModel()
    @State private var newName = ""
    @State private var showSession = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 멤버 이름 입력
                HStack(spacing: 12) {
                    TextField("멤버 이름", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addMember() }
                        .submitLabel(.done)

                    Button(action: addMember) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolEffect(.bounce, value: model.members.count)
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
                        ForEach(Array(model.members.enumerated()), id: \.element.id) { index, member in
                            HStack {
                                Text("\(index + 1).")
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
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
