import SwiftUI

struct ContentView: View {
    @StateObject private var model = TeamPickerModel()
    @State private var newName = ""
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input section
                HStack {
                    TextField("이름 입력", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addName() }

                    Button(action: addName) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()

                // Team count stepper
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(.secondary)
                    Stepper("팀 수: \(model.numberOfTeams)", value: $model.numberOfTeams, in: 2...8)
                }
                .padding(.horizontal)
                .padding(.bottom)

                // Participant list
                List {
                    Section {
                        ForEach(model.participants) { participant in
                            HStack {
                                Text("\((model.participants.firstIndex(of: participant) ?? 0) + 1).")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text(participant.name)
                            }
                        }
                        .onDelete(perform: model.removeParticipant)
                    } header: {
                        Text("참여자 \(model.participants.count)명")
                    }
                }
                .listStyle(.insetGrouped)

                // Pick button
                Button {
                    showPicker = true
                } label: {
                    Label("팀 뽑기!", systemImage: "shuffle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(model.canPick ? Color.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!model.canPick)
                .padding()
            }
            .navigationTitle("TeamPicker")
            .fullScreenCover(isPresented: $showPicker) {
                PickerView(model: model, isPresented: $showPicker)
            }
        }
    }

    private func addName() {
        model.addParticipant(newName)
        newName = ""
    }
}

#Preview {
    ContentView()
}
