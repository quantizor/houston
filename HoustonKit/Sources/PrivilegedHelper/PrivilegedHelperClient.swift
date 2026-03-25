import Foundation
import Models
import ServiceManagement

/// XPC client for communicating with the privileged helper for root operations.
public final class PrivilegedHelperClient: Sendable {
    private let helperBundleID = "com.quantizor.houston.helper"

    public init() {}

    // MARK: - Helper management

    /// Install the helper using SMAppService (macOS 13+).
    public func installHelper() async throws {
        let service = SMAppService.daemon(plistName: "\(helperBundleID).plist")
        try service.register()
    }

    /// Check if helper is installed and responsive.
    public func isHelperAvailable() async -> Bool {
        do {
            _ = try await getHelperVersion()
            return true
        } catch {
            return false
        }
    }

    // MARK: - XPC session

    private func send(_ request: HelperRequest) async throws -> HelperResponse {
        let machService = helperBundleID
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let session = try XPCSession(
                    machService: machService,
                    targetQueue: nil,
                    options: [],
                    requirement: .isFromSameTeam(andMatchesSigningIdentifier: nil),
                    cancellationHandler: nil
                )
                // Use the typed generic overload: send<Message, Reply>(_:replyHandler:)
                // Reply is decoded automatically — no manual .decode(as:) needed
                try session.send(request) { (result: Result<HelperResponse, any Error>) in
                    switch result {
                    case .success(let response):
                        continuation.resume(returning: response)
                    case .failure(let error):
                        continuation.resume(throwing: PrivilegedHelperError.operationFailed(
                            error.localizedDescription
                        ))
                    }
                }
            } catch {
                continuation.resume(throwing: PrivilegedHelperError.connectionFailed)
            }
        }
    }

    // MARK: - Response extraction

    private func unwrap<T>(_ response: HelperResponse, extract: (HelperResponse) -> T?) throws -> T {
        if let value = extract(response) { return value }
        if case .error(let message) = response {
            throw PrivilegedHelperError.operationFailed(message)
        }
        throw PrivilegedHelperError.operationFailed("Unexpected response from helper")
    }

    // MARK: - Operations

    public func writePlist(_ data: Data, toPath path: String) async throws {
        try PathValidator.validate(path)
        let response = try await send(.writePlist(data: data, path: path))
        try unwrap(response) { if case .success = $0 { return () } else { return nil } }
    }

    public func deletePlist(atPath path: String) async throws {
        try PathValidator.validate(path)
        let response = try await send(.deletePlist(path: path))
        try unwrap(response) { if case .success = $0 { return () } else { return nil } }
    }

    public func executeLaunchctl(arguments: [String], asUser uid: UInt32 = UInt32(getuid())) async throws -> (stdout: String, stderr: String) {
        let response = try await send(.executeLaunchctl(arguments: arguments, uid: uid))
        return try unwrap(response) { if case .processOutput(let o, let e) = $0 { return (o, e) } else { return nil } }
    }

    public func executeProcess(path: String, arguments: [String]) async throws -> (stdout: String, stderr: String) {
        let response = try await send(.executeProcess(path: path, arguments: arguments))
        return try unwrap(response) { if case .processOutput(let o, let e) = $0 { return (o, e) } else { return nil } }
    }

    public func querySystemLog(predicate: String, sinceInterval: Double, limit: Int = 500) async throws -> String {
        let response = try await send(.querySystemLog(predicate: predicate, sinceInterval: sinceInterval, limit: limit))
        return try unwrap(response) { if case .logOutput(let s) = $0 { return s } else { return nil } }
    }

    public func getHelperVersion() async throws -> String {
        let response = try await send(.getVersion)
        return try unwrap(response) { if case .version(let v) = $0 { return v } else { return nil } }
    }
}
