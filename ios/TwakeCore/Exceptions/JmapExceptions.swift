import Foundation

class JmapExceptions: Error, Equatable {
    static func == (value1: JmapExceptions, value2: JmapExceptions) -> Bool {
        return value1.value == value2.value
    }
    
    static let notFoundNewEmails = JmapExceptions(value: "Not found news emails")
    static let emailStateExpired = JmapExceptions(value: "Email state expired")
    
    var value: String?
    
    init(value: String? = nil) {
        self.value = value
    }
}
