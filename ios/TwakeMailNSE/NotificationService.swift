import UserNotifications
import Sentry
import SwiftUI

class NotificationService: UNNotificationServiceExtension {

    private let newEmailDefaultMessageKey: String = "newMessageInTwakeMail"
    private let newNotificationDefaultMessageKey: String = "newNotificationInTwakeMail"

    // The system creates one service per notification, in one shared process.
    // A client per service keeps concurrent pushes from mixing fetch state.
    private let platformJmapClient = JmapClient()

    private var isPlatformPush = false
    private var originalPlatformContent: UNMutableNotificationContent?

    private var handler: ((UNNotificationContent) -> Void)?
    private var modifiedContent: UNMutableNotificationContent?
    
    private lazy var keychainController = KeychainController(service: .sessions,
                                                             accessGroup: InfoPlistReader.main.keychainAccessGroupIdentifier)
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        
        SentryManager.shared.configure(with: keychainController)
        SentryManager.shared.clearUser()

        handler = contentHandler
        modifiedContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        let appGroupId = (Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String) ?? "group.\(Bundle.main.bundleIdentifier!)"
        let userDefaults = UserDefaults(suiteName: appGroupId)
        let isAppActive = userDefaults?.value(forKey: CoreUtils.APPLICATION_STATE) as? Bool
        if isAppActive == true {
            self.modifiedContent?.userInfo = request.content.userInfo.merging(["data": request.content.userInfo], uniquingKeysWith: {(_, new) in new})
            contentHandler(self.modifiedContent ?? request.content)
            return
        }

        if let payload = request.content.userInfo as? [String: Any],
           let push = NumberInboxPushPayload(userInfo: payload) {
            isPlatformPush = true
            modifiedContent?.userInfo[JmapConstants.EMAIL_ID] = push.emailId
            originalPlatformContent = modifiedContent?.mutableCopy() as? UNMutableNotificationContent
            handlePlatformPush(push)
            return
        }

        SentryManager.shared.addBreadcrumb(message: "NSE: Received push notification", level: .info)

        guard let payloadData = request.content.userInfo as? [String: Any],
              !keychainController.retrieveSharingSessions().isEmpty else {
            SentryManager.shared.capture(message: "NSE: Payload invalid or No Session found in Keychain")
            self.showDefaultNotification(message: NSLocalizedString(self.newNotificationDefaultMessageKey, comment: "Localizable"))
            return self.notify()
        }

        if #available(iOSApplicationExtension 13.0, *) {
            Task {
                await handlePushNotificationForNewEmail(payloadData: payloadData)
            }
        } else {
            self.handleGetNewEmails(payloadData: payloadData)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        SentryManager.shared.capture(message: "NSE: Service Extension Time Expired (Timeout)", flushTimeout: 0.3)
        if isPlatformPush {
            modifiedContent = originalPlatformContent
        } else {
            self.showDefaultNotification(message: NSLocalizedString(self.newNotificationDefaultMessageKey, comment: "Localizable"))
        }
        self.notify()
    }
    
    private func handlePlatformPush(_ push: NumberInboxPushPayload) {
        guard let session = keychainController.retrieveSharingSessionFromKeychain(accountId: push.stalwartAccountId),
              session.tokenOIDC != nil || session.basicAuth?.isEmpty == false,
              let state = session.emailDeliveryState ?? session.emailState else {
            SentryManager.shared.capture(message: "NSE: Platform session unavailable")
            return notify()
        }
        platformJmapClient.getNewEmails(
            apiUrl: session.apiUrl, accountId: session.accountId, sinceState: state,
            authenticationType: session.authenticationType, tokenOidc: session.tokenOIDC,
            basicAuth: session.basicAuth, tokenEndpointUrl: session.tokenEndpoint,
            oidcScopes: session.oidcScopes, isTWP: session.isTWP,
            onComplete: { (emails, errors, newState) in
                // Expiry may have completed the handler while the request was in flight.
                guard self.handler != nil else { return }
                guard let active = self.keychainController.retrieveSharingSessionFromKeychain(accountId: session.accountId),
                      active.basicAuth == session.basicAuth,
                      active.tokenOIDC?.token == session.tokenOIDC?.token else {
                    SentryManager.shared.capture(message: "NSE: Platform session ended")
                    return self.notify()
                }
                if let newState {
                    self.keychainController.updateEmailDeliveryStateToKeychain(
                        accountId: session.accountId, newEmailDeliveryState: newState)
                }
                if !errors.isEmpty && emails.isEmpty {
                    SentryManager.shared.capture(message: "NSE: Platform fetch failed")
                    return self.notify()
                }
                let filtered = self.filterEmailsToPushNotification(
                    emails: emails, mailboxIdsBlockNotification: active.mailboxIdsBlockNotification ?? [])
                if filtered.isEmpty { return self.discard() }
                self.showListNotification(emails: filtered)
            }
        )
    }

    @available(iOSApplicationExtension 13.0.0, *)
    private func handlePushNotificationForNewEmail(payloadData: [String: Any]) async {
        self.handleGetNewEmails(payloadData: payloadData)
    }
        
    private func handleGetNewEmails(payloadData: [String: Any]) {
        let mapStateChanges: [String: [TypeName: String]] = PayloadParser.shared.parsingPayloadNotification(payloadData: payloadData)
        
        if (mapStateChanges.isEmpty) {
            SentryManager.shared.capture(message: "NSE: Payload parsing returned empty state changes")
            self.showDefaultNotification(message: NSLocalizedString(self.newNotificationDefaultMessageKey, comment: "Localizable"))
            return self.notify()
        } else {
            guard let currentAccountId = mapStateChanges.keys.first,
                  let keychainSharingSession = keychainController.retrieveSharingSessionFromKeychain(accountId: currentAccountId),
                  keychainSharingSession.tokenOIDC != nil || keychainSharingSession.basicAuth != nil else {
                SentryManager.shared.capture(message: "NSE: Session missing or invalid credential for account: \(mapStateChanges.keys.first ?? "unknown")")
                self.showDefaultNotification(message: NSLocalizedString(self.newNotificationDefaultMessageKey, comment: "Localizable"))
                return self.notify()
            }

            SentryManager.shared.setSentryUser(keychainSharingSession.sentryUser)

            guard let listStateOfAccount = mapStateChanges[currentAccountId],
                  let newEmailDeliveryState = listStateOfAccount[TypeName.emailDelivery] else {
                SentryManager.shared.capture(message: "NSE: Missing emailDelivery state in payload")
                self.showDefaultNotification(message: NSLocalizedString(self.newNotificationDefaultMessageKey, comment: "Localizable"))
                return self.notify()
            }

            guard let oldEmailDeliveryState = keychainSharingSession.emailDeliveryState ?? keychainSharingSession.emailState else {
                SentryManager.shared.capture(message: "NSE: No stored email state for account: \(currentAccountId)")
                self.showDefaultNotification(message: NSLocalizedString(self.newEmailDefaultMessageKey, comment: "Localizable"))
                return self.notify()
            }

            guard newEmailDeliveryState != oldEmailDeliveryState else {
                SentryManager.shared.capture(message: "NSE: Email delivery state unchanged, skipping fetch")
                self.showDefaultNotification(message: NSLocalizedString(self.newEmailDefaultMessageKey, comment: "Localizable"))
                return self.notify()
            }
            
            JmapClient.shared.getNewEmails(
                apiUrl: keychainSharingSession.apiUrl,
                accountId: keychainSharingSession.accountId,
                sinceState: oldEmailDeliveryState,
                authenticationType: keychainSharingSession.authenticationType,
                tokenOidc: keychainSharingSession.tokenOIDC,
                basicAuth: keychainSharingSession.basicAuth,
                tokenEndpointUrl: keychainSharingSession.tokenEndpoint,
                oidcScopes: keychainSharingSession.oidcScopes,
                isTWP: keychainSharingSession.isTWP,
                onComplete: { (emails, errors, _) in
                    errors.forEach { SentryManager.shared.capture(error: $0) }

                    if emails.isEmpty {
                        SentryManager.shared.capture(message: "NSE: getNewEmails returned empty list")
                        self.showDefaultNotification(message: NSLocalizedString(self.newEmailDefaultMessageKey, comment: "Localizable"))
                        return self.notify()
                    }

                    self.keychainController.updateEmailDeliveryStateToKeychain(
                        accountId: keychainSharingSession.accountId,
                        newEmailDeliveryState: newEmailDeliveryState
                    )

                    let mailboxIdsBlockNotification = keychainSharingSession.mailboxIdsBlockNotification ?? []

                    if mailboxIdsBlockNotification.isEmpty {
                        return self.showListNotification(emails: emails)
                    } else {
                        let emailFiltered = self.filterEmailsToPushNotification(
                            emails: emails,
                            mailboxIdsBlockNotification: mailboxIdsBlockNotification)
                        return self.showListNotification(emails: emailFiltered)
                    }
                }
            )
        }
    }
    
    private func filterEmailsToPushNotification(emails: [Email], mailboxIdsBlockNotification: [String]) -> [Email] {
        return emails.filter { email in
            guard let mailboxIds = email.mailboxIds else { return true }
            for id in mailboxIds.keys {
                if mailboxIdsBlockNotification.contains(id) {
                    return false
                }
            }
            return true
        }
    }
    
    private func showListNotification(emails: [Email]) {
        guard !emails.isEmpty else {
            SentryManager.shared.capture(message: "NSE: All emails filtered by block list, no notification shown")
            return self.notify()
        }

        for email in emails {
            if (email.id == emails.last?.id) {
                self.showModifiedNotification(title: email.getSenderName(),
                                              subtitle: email.subject,
                                              body: email.preview,
                                              badgeCount: emails.count,
                                              userInfo: [JmapConstants.EMAIL_ID : email.id])
                return self.notify()
            } else {
                self.showNewNotification(title: email.getSenderName(),
                                         subtitle: email.subject,
                                         body: email.preview,
                                         badgeCount: emails.count,
                                         notificationId: email.id,
                                         userInfo: [JmapConstants.EMAIL_ID : email.id])
            }
        }
    }
    
    private func showDefaultNotification(message: String) {
        self.modifiedContent?.title = InfoPlistReader(bundle: .app).bundleDisplayName
        self.modifiedContent?.body = message
        self.modifiedContent?.badge = NSNumber(value: 1)
        self.modifiedContent?.sound = .default
    }
    
    private func showModifiedNotification(title: String?,
                                          subtitle: String?,
                                          body: String?,
                                          badgeCount: Int,
                                          userInfo: [String: Any]) {
        self.modifiedContent?.title = title ?? InfoPlistReader(bundle: .app).bundleDisplayName
        self.modifiedContent?.subtitle = subtitle ?? ""
        self.modifiedContent?.body = body ?? ""
        self.modifiedContent?.badge = NSNumber(value: badgeCount)
        self.modifiedContent?.sound = .default
        self.modifiedContent?.userInfo = userInfo
    }
    
    private func showNewNotification(title: String?,
                                     subtitle: String?,
                                     body: String?,
                                     badgeCount: Int,
                                     notificationId: String,
                                     userInfo: [String: Any]) {
        // Create a notification content
        let content = UNMutableNotificationContent()
        content.title = title ?? InfoPlistReader(bundle: .app).bundleDisplayName
        content.subtitle = subtitle ?? ""
        content.body = body ?? ""
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = userInfo

        // Create a notification trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        // Create a notification request
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                TwakeLogger.shared.log(message: "Error scheduling notification: \(error.localizedDescription)")
                SentryManager.shared.capture(error: error)
            } else {
                TwakeLogger.shared.log(message: "Notification scheduled successfully")
            }
        }
    }

    private func notify() {
        guard let modifiedContent else {
            return discard()
        }
        
        handler?(modifiedContent)
        cleanUp()
    }
    
    private func discard() {
        // A platform push discards on purpose when its mail was already announced.
        if !isPlatformPush {
            SentryManager.shared.capture(message: "NSE: modifiedContent nil, notification discarded")
        }
        handler?(UNNotificationContent())
        cleanUp()
    }
    
    private func cleanUp() {
        SentryManager.shared.clearUser()
        handler = nil
        modifiedContent = nil
        originalPlatformContent = nil
        isPlatformPush = false
    }
    
    deinit {
        cleanUp()
    }
}
