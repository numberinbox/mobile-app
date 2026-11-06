import Foundation

/// Versioned platform event. Mail content is fetched with the keychain session;
/// it is never accepted from this untrusted push payload.
struct NumberInboxPushPayload {
    let deliveryId: String
    let stalwartAccountId: String
    let emailId: String

    init?(userInfo: [String: Any]) {
        guard userInfo["schemaVersion"] as? String == "1",
              userInfo["eventType"] as? String == "mail.delivered",
              let deliveryId = userInfo["deliveryId"] as? String, !deliveryId.isEmpty,
              let accountId = userInfo["stalwartAccountId"] as? String, !accountId.isEmpty,
              let emailId = userInfo["emailId"] as? String, !emailId.isEmpty else { return nil }
        self.deliveryId = deliveryId
        self.stalwartAccountId = accountId
        self.emailId = emailId
    }
}
