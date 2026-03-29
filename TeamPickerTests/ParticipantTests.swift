import XCTest
@testable import TeamPicker

final class ParticipantTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let original = Participant(name: "Alice")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Participant.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.name, decoded.name)
    }

    func testCodableArrayRoundTrip() throws {
        let participants = [
            Participant(name: "Alice"),
            Participant(name: "Bob"),
            Participant(name: "Carol")
        ]
        let data = try JSONEncoder().encode(participants)
        let decoded = try JSONDecoder().decode([Participant].self, from: data)

        XCTAssertEqual(participants.count, decoded.count)
        for (original, restored) in zip(participants, decoded) {
            XCTAssertEqual(original.id, restored.id)
            XCTAssertEqual(original.name, restored.name)
        }
    }

    func testExistingInitStillWorks() {
        let p = Participant(name: "Test")
        XCTAssertFalse(p.name.isEmpty)
        XCTAssertFalse(p.id.uuidString.isEmpty)
    }
}
