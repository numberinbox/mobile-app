import Foundation
import Alamofire

class JmapClient {
    static let shared: JmapClient = JmapClient()

    private let jmapHeader = HTTPHeader(name: "Accept", value: "application/json;jmapVersion=rfc-8621")

    private var authentication: Authentication?
    private var tokenRefreshManager: TokenRefreshManager?
    private var authenticationInterceptor: AuthenticationInterceptor?
    
    private var walker = EmailChangesWalker(sinceState: "")
    private var listErrors = [Error]()

    func getNewEmails(
        apiUrl: String,
        accountId: String,
        sinceState: String,
        authenticationType: AuthenticationType,
        tokenOidc: TokenOidc?,
        basicAuth: String?,
        tokenEndpointUrl: String?,
        oidcScopes: [String]?,
        isTWP: Bool?,
        keychainAccountId: String? = nil,
        recoverExpiredState: Bool = false,
        onComplete: @escaping (NewEmailFetchResult) -> Void
    ) {
        if (authenticationType == AuthenticationType.basic) {
            authentication = AuthenticationCredential(
                type: AuthenticationType.basic,
                basicAuth: basicAuth ?? ""
            )
        } else {
            authentication = AuthenticationSSO(
                type: AuthenticationType.oidc,
                accessToken: tokenOidc?.token ?? "",
                refreshToken: tokenOidc?.refreshToken ?? "",
                expireTime: tokenOidc?.expiredTime
            )

            tokenRefreshManager = TokenRefreshManager(
                refreshToken: tokenOidc?.refreshToken ?? "",
                tokenEndpoint: tokenEndpointUrl ?? "",
                scopes: oidcScopes,
                isTWP: isTWP
            )
        }

        // Token refresh must write under the personal keychain key, not a delegated accountId.
        authenticationInterceptor = AuthenticationInterceptor(
            authentication: authentication,
            accountId: keychainAccountId ?? accountId,
            tokenRefreshManager: tokenRefreshManager
        )
        
        walker = EmailChangesWalker(sinceState: sinceState)
        listErrors = [Error]()
        
        self.handleGetEmailChanges(
            apiUrl: apiUrl,
            accountId: accountId,
            recoverExpiredState: recoverExpiredState,
            onComplete: onComplete
        )
    }
    
    private func handleGetEmailChanges(apiUrl: String,
                                       accountId: String,
                                       recoverExpiredState: Bool,
                                       onComplete: @escaping (NewEmailFetchResult) -> Void) {
        guard walker.shouldFetch else {
            return finish(onComplete)
        }

        let sinceState = walker.sinceState
        walker.beginPage()

        let jmapRequestObject = JmapRequestGenerator.shared.createEmailChangesRequest(
            accountId: accountId,
            sinceState: sinceState
        )

        AlamofireService.shared.post(
            url: apiUrl,
            payloadData: jmapRequestObject?.toData(),
            headers: HTTPHeaders([jmapHeader]),
            interceptor: authenticationInterceptor,
            onSuccess: { (data: JmapResponseObject<Email>) in
                if recoverExpiredState && data.isEmailChangesStateExpired {
                    return self.handleExpiredEmailState(apiUrl: apiUrl, accountId: accountId, onComplete: onComplete)
                }
                guard let page = data.emailChangesPage() else {
                    self.listErrors.append(JmapExceptions.notFoundNewEmails)
                    self.walker.fail()
                    return self.finish(onComplete)
                }
                let fetchAnotherPage = self.walker.apply(page)
                if fetchAnotherPage {
                    self.handleGetEmailChanges(apiUrl: apiUrl, accountId: accountId, recoverExpiredState: recoverExpiredState, onComplete: onComplete)
                } else {
                    self.finish(onComplete)
                }
            },
            onFailure: { error in
                self.listErrors.append(error)
                self.walker.fail()
                self.finish(onComplete)
            }
        )
    }

    private func finish(_ onComplete: @escaping (NewEmailFetchResult) -> Void) {
        var emails = walker.emails
        if !emails.isEmpty {
            emails = sortListEmails(currentListEmails: emails)
        }
        onComplete(NewEmailFetchResult(
            emails: emails,
            errors: listErrors,
            latestState: walker.latestState,
            hasMoreChanges: walker.hasMoreChanges,
            failed: walker.failed
        ))
    }
    
    /// Reports the current server state so the caller can move its cursor. The
    /// mail behind this push stays unannounced, so an error is reported too.
    private func handleExpiredEmailState(apiUrl: String,
                                         accountId: String,
                                         onComplete: @escaping (NewEmailFetchResult) -> Void) {
        walker.fail()
        listErrors.append(JmapExceptions.emailStateExpired)

        AlamofireService.shared.post(
            url: apiUrl,
            payloadData: JmapRequestGenerator.shared.createCurrentEmailStateRequest(accountId: accountId)?.toData(),
            headers: HTTPHeaders([jmapHeader]),
            interceptor: authenticationInterceptor,
            onSuccess: { (data: JmapResponseObject<Email>) in
                onComplete(NewEmailFetchResult(
                    emails: [],
                    errors: self.listErrors,
                    latestState: data.currentEmailState,
                    hasMoreChanges: false,
                    failed: true
                ))
            },
            onFailure: { error in
                self.listErrors.append(error)
                self.finish(onComplete)
            }
        )
    }

    private func sortListEmails(currentListEmails: [Email]) -> [Email] {
        emailsSortedByReceivedAt(currentListEmails)
    }
}
