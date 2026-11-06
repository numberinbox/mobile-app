import XCTest
@testable import Runner

final class NumberInboxPushPayloadTests: XCTestCase {
    private let fixture: [String: Any] = [
        "schemaVersion": "1", "eventType": "mail.delivered",
        "deliveryId": "e7d3e016-2f4e-4f68-9aa8-f01c96995fe1", "stalwartAccountId": "29883977c13473ae7cb7678ef767cbfbaffc8a44a6e463d971d23a65c1dc4af6", "emailId": "e6948d51214629057f63c03d50e19d31"
    ]

    func testParsesTheSharedContractFixture() {
        let parsed = NumberInboxPushPayload(userInfo: fixture)
        XCTAssertEqual(parsed?.emailId, "e6948d51214629057f63c03d50e19d31")
        XCTAssertEqual(parsed?.stalwartAccountId, "29883977c13473ae7cb7678ef767cbfbaffc8a44a6e463d971d23a65c1dc4af6")
        XCTAssertEqual(parsed?.deliveryId, "e7d3e016-2f4e-4f68-9aa8-f01c96995fe1")
    }

    func testRejectsAnUnknownSchemaVersion() {
        XCTAssertNil(NumberInboxPushPayload(userInfo: fixture.merging(["schemaVersion": "2"], uniquingKeysWith: { _, new in new })))
    }

    func testRejectsAnUnknownEventType() {
        XCTAssertNil(NumberInboxPushPayload(userInfo: fixture.merging(["eventType": "mail.held"], uniquingKeysWith: { _, new in new })))
    }

    func testRejectsAMissingOrEmptyId() {
        for key in ["deliveryId", "stalwartAccountId", "emailId"] {
            var missing = fixture
            missing.removeValue(forKey: key)
            XCTAssertNil(NumberInboxPushPayload(userInfo: missing))
            for invalid in ["" as Any, 42 as Any] {
                missing[key] = invalid
                XCTAssertNil(NumberInboxPushPayload(userInfo: missing))
            }
        }
    }

    func testLocalActionInteractionIsAccountBoundAndContentFree() {
        let info: [AnyHashable: Any] = ["niVersion": 1, "niAccountId": "account", "email_id": "mail", "subject": "private"]
        for action in ["", "mark_read", "archive", "reply"] {
            let result = NumberInboxPushPayload.notificationInteraction(actionId: action, userInfo: info)
            XCTAssertEqual(result?["actionId"] as? String, action)
            XCTAssertEqual(result?["niAccountId"] as? String, "account")
            XCTAssertEqual(result?.count, 4)
            XCTAssertNil(result?["subject"])
        }
        XCTAssertNil(NumberInboxPushPayload.notificationInteraction(actionId: "delete", userInfo: info))
        XCTAssertNil(NumberInboxPushPayload.notificationInteraction(actionId: "reply", userInfo: ["email_id": "mail"]))
    }

    func testIgnoresLegacyStateChangePayloads() {
        XCTAssertNil(NumberInboxPushPayload(userInfo: ["account:EmailDelivery": "state"]))
    }
}
