import Foundation

struct Participant: Identifiable, Equatable {
    let id = UUID()
    let name: String
}

class TeamPickerModel: ObservableObject {
    @Published var participants: [Participant] = []
    @Published var numberOfTeams: Int = 2
    @Published var teams: [[Participant]] = []

    var canPick: Bool {
        participants.count >= numberOfTeams
    }

    func addParticipant(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        participants.append(Participant(name: trimmed))
    }

    func removeParticipant(at offsets: IndexSet) {
        participants.remove(atOffsets: offsets)
    }

    func pickTeams() -> [[Participant]] {
        let result = distribute(participants.shuffled())
        teams = result
        return result
    }

    /// Returns a snapshot with random names assigned to each team slot (for animation)
    func randomSnapshot() -> [[Participant]] {
        distribute(participants.shuffled())
    }

    private func distribute(_ names: [Participant]) -> [[Participant]] {
        var result: [[Participant]] = Array(repeating: [], count: numberOfTeams)
        for (index, participant) in names.enumerated() {
            result[index % numberOfTeams].append(participant)
        }
        return result
    }
}
