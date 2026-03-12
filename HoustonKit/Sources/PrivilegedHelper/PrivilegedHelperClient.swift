import Foundation
import Models
import ServiceManagement

/// XPC client for communicating with the privileged helper for root operations.
public final class PrivilegedHelperClient: @unchecked Sendable {
    private let helperBundleID = "com.houston.helper"
    private var connection: NSXPCConnection?
    private let lock = NSLock()

    public init() {}

    // MARK: - Connection management

    /// Establish a connection to the helper via XPC Mach service.
    public func connect() throws {
        lock.lock()
        defer { lock.unlock() }

        if connection != nil { return }

        let conn = NSXPCConnection(machServiceName: helperBundleID, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)

        conn.interruptionHandler = { [weak self] in
            self?.lock.lock()
            self?.connection = nil
            self?.lock.unlock()
        }

        conn.invalidationHandler = { [weak self] in
            self?.lock.lock()
            self?.connection = nil
            self?.lock.unlock()
        }

        conn.resume()
        connection = conn
    }

    /// Disconnect from the helper.
    public func disconnect() {
        lock.lock()
        defer { lock.unlock() }

        connection?.invalidate()
        connection = nil
    }

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

    // MARK: - Helper proxy

    private func getConnection() throws -> NSXPCConnection {
        lock.lock()
        defer { lock.unlock() }

        if connection == nil {
            lock.unlock()
            try connect()
            lock.lock()
        }

        guard let conn = connection else {
            throw PrivilegedHelperError.connectionFailed
        }

        return conn
    }

    // MARK: - Operations

    /// Write plist data to a path in a privileged directory.
    public func writePlist(_ data: Data, toPath path: String) async throws {
        try PathValidator.validate(path)

        let conn = try getConnection()

        return try await withCheckedThrowingContinuation { continuation in
            let helper = conn.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: PrivilegedHelperError.connectionFailed)
            } as! HelperProtocol

            helper.writePlist(data, toPath: path) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PrivilegedHelperError.operationFailed(
                        errorMessage ?? "Unknown error writing plist"
                    ))
                }
            }
        }
    }

    /// Delete a plist at a path in a privileged directory.
    public func deletePlist(atPath path: String) async throws {
        try PathValidator.validate(path)

        let conn = try getConnection()

        return try await withCheckedThrowingContinuation { continuation in
            let helper = conn.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: PrivilegedHelperError.connectionFailed)
            } as! HelperProtocol

            helper.deletePlist(atPath: path) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PrivilegedHelperError.operationFailed(
                        errorMessage ?? "Unknown error deleting plist"
                    ))
                }
            }
        }
    }

    /// Execute a launchctl command via the privileged helper.
    public func executeLaunchctl(arguments: [String]) async throws -> (stdout: String, stderr: String) {
        let conn = try getConnection()

        return try await withCheckedThrowingContinuation { continuation in
            let helper = conn.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: PrivilegedHelperError.connectionFailed)
            } as! HelperProtocol

            helper.executeLaunchctl(arguments: arguments) { success, stdout, stderr in
                if success {
                    continuation.resume(returning: (stdout: stdout ?? "", stderr: stderr ?? ""))
                } else {
                    continuation.resume(throwing: PrivilegedHelperError.operationFailed(
                        stderr ?? "launchctl command failed"
                    ))
                }
            }
        }
    }

    /// Get the helper tool version.
    public func getHelperVersion() async throws -> String {
        let conn = try getConnection()

        return try await withCheckedThrowingContinuation { continuation in
            let helper = conn.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: PrivilegedHelperError.connectionFailed)
            } as! HelperProtocol

            helper.getVersion { version in
                continuation.resume(returning: version)
            }
        }
    }
}
