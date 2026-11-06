import XCTest
@testable import Runner

final class JmapEmailChangesResultTests: XCTestCase {
    private struct TestEmail: Codable { let id: String }

    private func decode(_ newState: String, more: Bool) throws -> JmapResponseObject<TestEmail> {
        let json = """
        {"sessionState":"session","methodResponses":[
          ["Email/changes",{"accountId":"account","newState":"\(newState)","hasMoreChanges":\(more)},"c0"],
          ["Email/get",{"accountId":"account","state":"wrong-get-state","list":[{"id":"email"}]},"c1"]
        ]}
        """
        return try JSONDecoder().decode(JmapResponseObject<TestEmail>.self, from: Data(json.utf8))
    }

    func testNewStateComesFromEmailChangesNotEmailGet() throws {
        XCTAssertEqual(try decode("changes-state", more: false).emailChangesResult?.newState, "changes-state")
    }

    func testHasMoreChangesComesFromEmailChanges() throws {
        let first = try XCTUnwrap(decode("page-one", more: true).emailChangesResult)
        XCTAssertTrue(first.hasMoreChanges)
        let second = try XCTUnwrap(decode("page-two", more: false).emailChangesResult)
        XCTAssertFalse(second.hasMoreChanges)
        XCTAssertEqual(second.newState, "page-two")
        XCTAssertEqual(second.emails.map(\.id), ["email"])
    }

    func testAFailureReturnsNoNewState() throws {
        let json = """
        {"sessionState":"session","methodResponses":[["Email/get",{"accountId":"account","list":[]},"c1"]]}
        """
        let response = try JSONDecoder().decode(JmapResponseObject<TestEmail>.self, from: Data(json.utf8))
        XCTAssertNil(response.emailChangesResult)
    }

    func testWrongCallIdCannotMasqueradeAsChanges() throws {
        let json = """
        {"sessionState":"session","methodResponses":[
          ["Email/changes",{"accountId":"account","newState":"wrong","hasMoreChanges":false},"other"],
          ["Email/get",{"accountId":"account","list":[]},"c1"]]}
        """
        let response = try JSONDecoder().decode(JmapResponseObject<TestEmail>.self, from: Data(json.utf8))
        XCTAssertNil(response.emailChangesResult)
    }

    private func decodeRaw(_ json: String) throws -> JmapResponseObject<TestEmail> {
        try JSONDecoder().decode(JmapResponseObject<TestEmail>.self, from: Data(json.utf8))
    }

    func testCannotCalculateChangesIsAnExpiredState() throws {
        let response = try decodeRaw("""
        {"sessionState":"session","methodResponses":[
          ["error",{"type":"cannotCalculateChanges"},"c0"],
          ["error",{"type":"invalidResultReference"},"c1"]]}
        """)
        XCTAssertTrue(response.isEmailChangesStateExpired)
        XCTAssertNil(response.emailChangesResult)
    }

    func testOtherErrorsAreNotAnExpiredState() throws {
        let response = try decodeRaw("""
        {"sessionState":"session","methodResponses":[["error",{"type":"serverFail"},"c0"]]}
        """)
        XCTAssertFalse(response.isEmailChangesStateExpired)
    }

    func testAnExpiredErrorOnAnotherCallIsNotAnExpiredState() throws {
        let response = try decodeRaw("""
        {"sessionState":"session","methodResponses":[["error",{"type":"cannotCalculateChanges"},"other"]]}
        """)
        XCTAssertFalse(response.isEmailChangesStateExpired)
    }

    func testASuccessfulResponseIsNotAnExpiredState() throws {
        XCTAssertFalse(try decode("changes-state", more: false).isEmailChangesStateExpired)
    }

    func testCurrentEmailStateComesFromEmailGet() throws {
        let response = try decodeRaw("""
        {"sessionState":"session","methodResponses":[
          ["Email/get",{"accountId":"account","state":"server-state","list":[]},"c0"]]}
        """)
        XCTAssertEqual(response.currentEmailState, "server-state")
    }

    func testCurrentEmailStateIsNilWhenTheLookupFails() throws {
        let response = try decodeRaw("""
        {"sessionState":"session","methodResponses":[["error",{"type":"serverFail"},"c0"]]}
        """)
        XCTAssertNil(response.currentEmailState)
    }

    func testCurrentEmailStateRequestAsksForNoIds() throws {
        let request = try XCTUnwrap(JmapRequestGenerator.shared.createCurrentEmailStateRequest(accountId: "account"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        let call = try XCTUnwrap((json["methodCalls"] as? [[Any]])?.first)
        XCTAssertEqual(call[0] as? String, "Email/get")
        XCTAssertEqual(call[2] as? String, "c0")
        let arguments = try XCTUnwrap(call[1] as? [String: Any])
        XCTAssertEqual(arguments["accountId"] as? String, "account")
        XCTAssertEqual((arguments["ids"] as? [String])?.count, 0, "null ids would return every email")
        XCTAssertNil(arguments["#ids"])
    }

    func testTheChangesRequestStillUsesAResultReference() throws {
        let request = try XCTUnwrap(JmapRequestGenerator.shared.createEmailChangesRequest(accountId: "account", sinceState: "state"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        let calls = try XCTUnwrap(json["methodCalls"] as? [[Any]])
        let get = try XCTUnwrap(calls[1][1] as? [String: Any])
        XCTAssertNotNil(get["#ids"])
        XCTAssertNil(get["ids"])
    }
}
