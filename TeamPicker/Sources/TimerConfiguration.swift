import Foundation

struct TimerConfiguration: Codable, Equatable {
    var durationSeconds: Int = 60

    static let range = 30...180
    static let step = 15

    var displayText: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if seconds == 0 {
            return "\(minutes)분"
        }
        return "\(minutes)분 \(seconds)초"
    }

    private static let key = "standup_timer_config"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func load() -> TimerConfiguration {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(TimerConfiguration.self, from: data) else {
            return TimerConfiguration()
        }
        return config
    }
}
