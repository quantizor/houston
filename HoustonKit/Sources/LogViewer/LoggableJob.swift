import Foundation

public protocol LoggableJob: Sendable {
    var label: String { get }
    var standardOutPath: String? { get }
    var standardErrorPath: String? { get }
}
