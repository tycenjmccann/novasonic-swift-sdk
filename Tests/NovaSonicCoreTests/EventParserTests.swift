import XCTest
@testable import NovaSonicCore

final class EventParserTests: XCTestCase {
    func testParseSessionUpdatedEvent() {
        let json = """
        {"event":{"sessionUpdated":{"sessionId":"test-session-123","type":"session.updated"}}}
        """
        let result = EventParser.parse(json)
        guard case .sessionUpdated(let response) = result else {
            XCTFail("Expected .sessionUpdated, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(response.sessionId, "test-session-123")
        XCTAssertEqual(response.type, "session.updated")
    }

    func testParseSessionUpdatedMinimal() {
        let json = """
        {"event":{"sessionUpdated":{"sessionId":"minimal-session"}}}
        """
        let result = EventParser.parse(json)
        guard case .sessionUpdated(let response) = result else {
            XCTFail("Expected .sessionUpdated")
            return
        }
        XCTAssertEqual(response.sessionId, "minimal-session")
        XCTAssertNil(response.type)
    }

    func testParseSessionUpdatedMissingSessionId() {
        let json = """
        {"event":{"sessionUpdated":{"type":"session.updated"}}}
        """
        XCTAssertNil(EventParser.parse(json))
    }

    func testExistingEventTypesStillWork() {
        let json = """
        {"event":{"completionStart":{"sessionId":"s1","promptName":"p1","completionId":"c1"}}}
        """
        guard case .completionStart(let e) = EventParser.parse(json) else {
            XCTFail("Expected .completionStart")
            return
        }
        XCTAssertEqual(e.sessionId, "s1")
    }
}
