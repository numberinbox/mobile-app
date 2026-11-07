import Foundation

/// Versioned platform event. Mail content is fetched with the keychain session;
/// it is never accepted from this untrusted push payload.
struct NumberInboxPushPayload {

    static func notificationInteraction(actionId: String, userInfo: [AnyHashable: Any]) -> [String: Any]? {
        guard actionId.isEmpty,
              userInfo["niVersion"] as? Int == 1,
              let account = userInfo["niAccountId"] as? String, !account.isEmpty,
              let email = userInfo["email_id"] as? String, !email.isEmpty else { return nil }
        return ["niVersion": 1, "niAccountId": account, "emailId": email, "actionId": actionId]
    }

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
