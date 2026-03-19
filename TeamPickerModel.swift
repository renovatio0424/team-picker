import Foundation

class TeamPickerModel: ObservableObject {
    @Published var participants: [String] = []
    @Published var numberOfTeams: Int = 2
    @Published var teams: [[String]] = []

    var canPick: Bool {
        participants.count >= numberOfTeams
    }

    func addParticipant(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        participants.append(trimmed)
    }

    func removeParticipant(at offsets: IndexSet) {
        participants.remove(atOffsets: offsets)
    }

    func pickTeams() -> [[String]] {
        var shuffled = participants.shuffled()
        var result: [[String]] = Array(repeating: [], count: numberOfTeams)
        for (index, name) in shuffled.enumerated() {
            result[index % numberOfTeams].append(name)
        }
        teams = result
        return result
    }

    /// Returns a snapshot with random names assigned to each team slot (for animation)
    func randomSnapshot() -> [[String]] {
        var result: [[String]] = Array(repeating: [], count: numberOfTeams)
        let shuffled = participants.shuffled()
        for (index, name) in shuffled.enumerated() {
            result[index % numberOfTeams].append(name)
        }
        return result
    }
}
