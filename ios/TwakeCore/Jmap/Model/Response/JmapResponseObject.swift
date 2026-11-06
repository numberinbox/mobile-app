import Foundation

struct JmapResponseObject<T: Codable>: Codable {
    let sessionState: String
    let methodResponses: [[ResponseInvocation<T>]]
}

enum ResponseInvocation<T: Codable>: Codable {
    case methodResponse(MethodResponse<T>)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        if let x = try? container.decode(MethodResponse<T>.self) {
            self = .methodResponse(x)
            return
        }
        throw DecodingError.typeMismatch(ResponseInvocation<T>.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for ResponseInvocation"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .methodResponse(let x):
            try container.encode(x)
        case .string(let x):
            try container.encode(x)
        }
    }
    
    var listObject: [T]? {
        switch self {
            case .methodResponse(let method): return method.list
            case .string(_): return nil
        }
    }
    
    var response: MethodResponse<T>? {
        switch self {
            case .methodResponse(let method): return method
            case .string(_): return nil
        }
    }
}

struct MethodResponse<T: Codable>: Codable {
    let accountId: String?
    // Set only on an "error" invocation, which has no accountId.
    let type: String?
    let oldState: String?
    let newState: String?
    let hasMoreChanges: Bool?
    let created: [String]?
    let updated: [String]?
    let destroyed: [String]?
    let notFound: [String]?
    let state: String?
    let list: [T]?
}

extension JmapResponseObject {
    func parsing(methodName: String, methodCallId: String) -> MethodResponse<T>? {
        let invocations = methodResponses.first { (responseInvocations: [ResponseInvocation<T>]) in
            return responseInvocations.contains { (responseInvocation: ResponseInvocation<T>) in
                return validateResponseInvocation(response: responseInvocation, methodName: methodName, methodCallId: methodCallId)
            }
        }
        
        if invocations == nil || invocations?.isEmpty == true {
            return nil
        } else {
            let invocation = invocations!.first { response in
                return validateMethodResponse(response: response)
            }
            
            return invocation?.response
        }
    }
    
    private func validateResponseInvocation(response: ResponseInvocation<T>, methodName: String, methodCallId: String) -> Bool {
        switch response {
        case .string(let stringValue):
            return stringValue == methodName || stringValue == methodCallId
        default:
            return false
        }
    }
    
    private func validateMethodResponse(response: ResponseInvocation<T>) -> Bool {
        switch response {
        case .methodResponse(_):
            return true
        default:
            return false
        }
    }
}

extension JmapResponseObject {
    private func exactResponse(_ method: String, _ callId: String) -> MethodResponse<T>? {
        guard let invocation = methodResponses.first(where: { values in
            guard values.count == 3,
                  case .string(let name) = values[0],
                  case .string(let id) = values[2] else { return false }
            return name == method && id == callId
        }) else { return nil }
        return invocation[1].response
    }

    /// The since-state is older than the server's change history. Retrying can
    /// never succeed, so the cursor has to move to the current server state.
    var isEmailChangesStateExpired: Bool {
        exactResponse(JmapConstants.ERROR_METHOD_NAME, "c0")?.type == JmapConstants.CANNOT_CALCULATE_CHANGES
    }

    var currentEmailState: String? {
        guard let state = exactResponse(JmapConstants.EMAIL_GET_METHOD_NAME, "c0")?.state,
              !state.isEmpty else { return nil }
        return state
    }
}

/// Cursor and paging belong to Email/changes (c0), never Email/get (c1).
struct JmapEmailChangesResult<T: Codable> {
    let emails: [T]
    let newState: String
    let hasMoreChanges: Bool
}

extension JmapResponseObject {
    var emailChangesResult: JmapEmailChangesResult<T>? {
        guard let changes = exactResponse(JmapConstants.EMAIL_CHANGES_METHOD_NAME, "c0"),
              let state = changes.newState, !state.isEmpty,
              let more = changes.hasMoreChanges,
              let emails = exactResponse(JmapConstants.EMAIL_GET_METHOD_NAME, "c1")?.list else { return nil }
        return JmapEmailChangesResult(emails: emails, newState: state, hasMoreChanges: more)
    }
}
