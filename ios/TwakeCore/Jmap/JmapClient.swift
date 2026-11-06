import Foundation
import Alamofire

class JmapClient {
    static let shared: JmapClient = JmapClient()

    private let jmapHeader = HTTPHeader(name: "Accept", value: "application/json;jmapVersion=rfc-8621")

    private var authentication: Authentication?
    private var tokenRefreshManager: TokenRefreshManager?
    private var authenticationInterceptor: AuthenticationInterceptor?
    
    private var hasMoreChanges: Bool = true
    private var currentSinceState: String?
    private var totalListEmails = [Email]()
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
        onComplete: @escaping ([Email], [Error], String?) -> Void
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

        authenticationInterceptor = AuthenticationInterceptor(
            authentication: authentication,
            accountId: accountId,
            tokenRefreshManager: tokenRefreshManager
        )
        
        hasMoreChanges = true
        currentSinceState = sinceState
        totalListEmails = [Email]()
        listErrors = [Error]()
        
        self.handleGetEmailChanges(
            apiUrl: apiUrl,
            accountId: accountId,
            onComplete: onComplete
        )
    }
    
    private func handleGetEmailChanges(apiUrl: String, 
                                       accountId: String,
                                       onComplete: @escaping ([Email], [Error], String?) -> Void) {
        guard hasMoreChanges, let sinceState = currentSinceState else {
            if !self.totalListEmails.isEmpty {
                let sortedListEmails = self.sortListEmails(currentListEmails: self.totalListEmails)
                self.totalListEmails = sortedListEmails
            }
            
            return onComplete(self.totalListEmails, self.listErrors, self.listErrors.isEmpty ? self.currentSinceState : nil)
        }
        
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
                if data.isEmailChangesStateExpired {
                    self.handleExpiredEmailState(apiUrl: apiUrl, accountId: accountId, onComplete: onComplete)
                } else if let response = data.emailChangesResult {
                    self.totalListEmails.append(contentsOf: response.emails)
                    self.hasMoreChanges = response.hasMoreChanges
                    self.currentSinceState = response.newState
                    
                    self.handleGetEmailChanges(apiUrl: apiUrl, accountId: accountId, onComplete: onComplete)
                } else {
                    self.listErrors.append(JmapExceptions.notFoundNewEmails)
                    self.hasMoreChanges = false
                    self.currentSinceState = nil
                    
                    if !self.totalListEmails.isEmpty {
                        let sortedListEmails = self.sortListEmails(currentListEmails: self.totalListEmails)
                        self.totalListEmails = sortedListEmails
                    }
                    
                    onComplete(self.totalListEmails, self.listErrors, self.listErrors.isEmpty ? self.currentSinceState : nil)
                }
            },
            onFailure: { error in
                self.listErrors.append(error)
                self.hasMoreChanges = false
                self.currentSinceState = nil
                
                if !self.totalListEmails.isEmpty {
                    let sortedListEmails = self.sortListEmails(currentListEmails: self.totalListEmails)
                    self.totalListEmails = sortedListEmails
                }
                
                onComplete(self.totalListEmails, self.listErrors, self.listErrors.isEmpty ? self.currentSinceState : nil)
            }
        )
    }
    
    /// Reports the current server state so the caller can move its cursor. The
    /// mail behind this push stays unannounced, so an error is reported too.
    private func handleExpiredEmailState(apiUrl: String,
                                         accountId: String,
                                         onComplete: @escaping ([Email], [Error], String?) -> Void) {
        hasMoreChanges = false
        currentSinceState = nil
        listErrors.append(JmapExceptions.emailStateExpired)

        AlamofireService.shared.post(
            url: apiUrl,
            payloadData: JmapRequestGenerator.shared.createCurrentEmailStateRequest(accountId: accountId)?.toData(),
            headers: HTTPHeaders([jmapHeader]),
            interceptor: authenticationInterceptor,
            onSuccess: { (data: JmapResponseObject<Email>) in
                onComplete(self.totalListEmails, self.listErrors, data.currentEmailState)
            },
            onFailure: { error in
                self.listErrors.append(error)
                onComplete(self.totalListEmails, self.listErrors, nil)
            }
        )
    }

    private func sortListEmails(currentListEmails: [Email]) -> [Email] {
        let sortedListEmails = currentListEmails.sorted(by: { (email1, email2) -> Bool in
            if let date1 = email1.receivedAt?.convertUTCDateToLocalDate(),
               let date2 = email2.receivedAt?.convertUTCDateToLocalDate() {
                return date1 < date2
            }
            return false
        })
        return sortedListEmails
    }
}
