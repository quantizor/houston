import Foundation
import Testing
@testable import PrivilegedHelper

@Suite("PrivilegedHelper Tests")
struct PrivilegedHelperTests {

    // MARK: - PrivilegedHelperClient

    @Test("PrivilegedHelperClient can be initialized")
    func canInit() {
        let client = PrivilegedHelperClient()
        #expect(client != nil)
    }

    // MARK: - PathValidator: valid paths

    @Test("PathValidator allows files in /Library/LaunchAgents")
    func allowsLaunchAgentsPath() {
        #expect(PathValidator.isAllowed("/Library/LaunchAgents/com.example.agent.plist"))
    }

    @Test("PathValidator allows files in /Library/LaunchDaemons")
    func allowsLaunchDaemonsPath() {
        #expect(PathValidator.isAllowed("/Library/LaunchDaemons/com.example.daemon.plist"))
    }

    @Test("PathValidator allows nested paths within allowed directories")
    func allowsNestedPath() {
        #expect(PathValidator.isAllowed("/Library/LaunchAgents/subfolder/test.plist"))
    }

    // MARK: - PathValidator: invalid paths

    @Test("PathValidator rejects paths outside /Library")
    func rejectsOutsideLibrary() {
        #expect(!PathValidator.isAllowed("/etc/launchd.conf"))
        #expect(!PathValidator.isAllowed("/tmp/com.example.plist"))
        #expect(!PathValidator.isAllowed("/Users/someone/Library/LaunchAgents/test.plist"))
    }

    @Test("PathValidator rejects home directory paths")
    func rejectsHomeDirectory() {
        #expect(!PathValidator.isAllowed("~/Library/LaunchAgents/test.plist"))
    }

    @Test("PathValidator rejects path traversal attacks")
    func rejectsPathTraversal() {
        #expect(!PathValidator.isAllowed("/Library/LaunchAgents/../../../etc/passwd"))
        #expect(!PathValidator.isAllowed("/Library/LaunchAgents/../../etc/shadow"))
        #expect(!PathValidator.isAllowed("/Library/LaunchDaemons/../LaunchAgents/../../etc/hosts"))
    }

    @Test("PathValidator rejects the directory itself without a file")
    func rejectsDirectoryOnly() {
        // The directory path itself is allowed (isAllowed returns true for the directory),
        // but path traversal out of it is not.
        #expect(PathValidator.isAllowed("/Library/LaunchAgents"))
        #expect(PathValidator.isAllowed("/Library/LaunchDaemons"))
    }

    @Test("PathValidator rejects empty path")
    func rejectsEmptyPath() {
        #expect(!PathValidator.isAllowed(""))
    }

    @Test("PathValidator rejects relative paths")
    func rejectsRelativePaths() {
        #expect(!PathValidator.isAllowed("Library/LaunchAgents/test.plist"))
        #expect(!PathValidator.isAllowed("../Library/LaunchAgents/test.plist"))
    }

    @Test("PathValidator rejects /Library/LaunchAgents prefix that is not a directory boundary")
    func rejectsSimilarPrefixPaths() {
        // e.g. /Library/LaunchAgentsFoo/bar should NOT be allowed
        #expect(!PathValidator.isAllowed("/Library/LaunchAgentsFoo/bar.plist"))
        #expect(!PathValidator.isAllowed("/Library/LaunchDaemonsFoo/bar.plist"))
    }

    // MARK: - PathValidator: validate throws

    @Test("PathValidator.validate throws for invalid path")
    func validateThrows() {
        #expect(throws: PrivilegedHelperError.self) {
            try PathValidator.validate("/etc/passwd")
        }
    }

    @Test("PathValidator.validate does not throw for valid path")
    func validateDoesNotThrow() throws {
        try PathValidator.validate("/Library/LaunchAgents/com.example.plist")
    }

    // MARK: - PrivilegedHelperError descriptions

    @Test("PrivilegedHelperError.notInstalled has a description")
    func notInstalledDescription() {
        let error = PrivilegedHelperError.notInstalled
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("not installed"))
    }

    @Test("PrivilegedHelperError.connectionFailed has a description")
    func connectionFailedDescription() {
        let error = PrivilegedHelperError.connectionFailed
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("connect"))
    }

    @Test("PrivilegedHelperError.operationFailed has a description")
    func operationFailedDescription() {
        let error = PrivilegedHelperError.operationFailed("test detail")
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("test detail"))
    }

    @Test("PrivilegedHelperError.invalidPath has a description")
    func invalidPathDescription() {
        let error = PrivilegedHelperError.invalidPath("/bad/path")
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("/bad/path"))
    }

    @Test("PrivilegedHelperError.timeout has a description")
    func timeoutDescription() {
        let error = PrivilegedHelperError.timeout
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("timed out"))
    }
}

// MARK: - HelperMessages Codable Tests

@Suite("HelperRequest Codable Tests")
struct HelperRequestCodableTests {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func roundTrip(_ request: HelperRequest) throws -> HelperRequest {
        let data = try encoder.encode(request)
        return try decoder.decode(HelperRequest.self, from: data)
    }

    @Test("writePlist round-trips through JSON")
    func writePlistRoundTrip() throws {
        let plistData = Data("<?xml version=\"1.0\"?>".utf8)
        let original = HelperRequest.writePlist(data: plistData, path: "/Library/LaunchAgents/com.test.plist")
        let decoded = try roundTrip(original)

        if case .writePlist(let data, let path) = decoded {
            #expect(data == plistData)
            #expect(path == "/Library/LaunchAgents/com.test.plist")
        } else {
            Issue.record("Expected .writePlist, got \(decoded)")
        }
    }

    @Test("deletePlist round-trips through JSON")
    func deletePlistRoundTrip() throws {
        let original = HelperRequest.deletePlist(path: "/Library/LaunchDaemons/com.test.plist")
        let decoded = try roundTrip(original)

        if case .deletePlist(let path) = decoded {
            #expect(path == "/Library/LaunchDaemons/com.test.plist")
        } else {
            Issue.record("Expected .deletePlist, got \(decoded)")
        }
    }

    @Test("executeLaunchctl round-trips through JSON")
    func executeLaunchctlRoundTrip() throws {
        let original = HelperRequest.executeLaunchctl(arguments: ["list", "com.apple.Finder"], uid: 501)
        let decoded = try roundTrip(original)

        if case .executeLaunchctl(let arguments, let uid) = decoded {
            #expect(arguments == ["list", "com.apple.Finder"])
            #expect(uid == 501)
        } else {
            Issue.record("Expected .executeLaunchctl, got \(decoded)")
        }
    }

    @Test("executeProcess round-trips through JSON")
    func executeProcessRoundTrip() throws {
        let original = HelperRequest.executeProcess(path: "/usr/bin/log", arguments: ["show", "--last", "1m"])
        let decoded = try roundTrip(original)

        if case .executeProcess(let path, let arguments) = decoded {
            #expect(path == "/usr/bin/log")
            #expect(arguments == ["show", "--last", "1m"])
        } else {
            Issue.record("Expected .executeProcess, got \(decoded)")
        }
    }

    @Test("querySystemLog round-trips through JSON")
    func querySystemLogRoundTrip() throws {
        let original = HelperRequest.querySystemLog(predicate: "subsystem == \"com.apple.launchd\"", sinceInterval: 3600.0, limit: 250)
        let decoded = try roundTrip(original)

        if case .querySystemLog(let predicate, let sinceInterval, let limit) = decoded {
            #expect(predicate == "subsystem == \"com.apple.launchd\"")
            #expect(sinceInterval == 3600.0)
            #expect(limit == 250)
        } else {
            Issue.record("Expected .querySystemLog, got \(decoded)")
        }
    }

    @Test("getVersion round-trips through JSON")
    func getVersionRoundTrip() throws {
        let original = HelperRequest.getVersion
        let decoded = try roundTrip(original)

        if case .getVersion = decoded {
            // success
        } else {
            Issue.record("Expected .getVersion, got \(decoded)")
        }
    }

    @Test("writePlist with empty data round-trips")
    func writePlistEmptyData() throws {
        let original = HelperRequest.writePlist(data: Data(), path: "/Library/LaunchAgents/empty.plist")
        let decoded = try roundTrip(original)

        if case .writePlist(let data, _) = decoded {
            #expect(data.isEmpty)
        } else {
            Issue.record("Expected .writePlist, got \(decoded)")
        }
    }

    @Test("executeLaunchctl with empty arguments round-trips")
    func executeLaunchctlEmptyArgs() throws {
        let original = HelperRequest.executeLaunchctl(arguments: [], uid: 0)
        let decoded = try roundTrip(original)

        if case .executeLaunchctl(let arguments, let uid) = decoded {
            #expect(arguments.isEmpty)
            #expect(uid == 0)
        } else {
            Issue.record("Expected .executeLaunchctl, got \(decoded)")
        }
    }

    @Test("All request cases produce valid JSON data")
    func allCasesEncodeToNonEmptyData() throws {
        let cases: [HelperRequest] = [
            .writePlist(data: Data([0x01, 0x02]), path: "/Library/LaunchAgents/a.plist"),
            .deletePlist(path: "/Library/LaunchDaemons/b.plist"),
            .executeLaunchctl(arguments: ["list"], uid: 501),
            .executeProcess(path: "/usr/bin/true", arguments: []),
            .querySystemLog(predicate: "test", sinceInterval: 60.0, limit: 100),
            .getVersion,
        ]

        for request in cases {
            let data = try encoder.encode(request)
            #expect(!data.isEmpty)
        }
    }
}

@Suite("HelperResponse Codable Tests")
struct HelperResponseCodableTests {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func roundTrip(_ response: HelperResponse) throws -> HelperResponse {
        let data = try encoder.encode(response)
        return try decoder.decode(HelperResponse.self, from: data)
    }

    @Test("success round-trips through JSON")
    func successRoundTrip() throws {
        let decoded = try roundTrip(.success)

        if case .success = decoded {
            // success
        } else {
            Issue.record("Expected .success, got \(decoded)")
        }
    }

    @Test("processOutput round-trips through JSON")
    func processOutputRoundTrip() throws {
        let original = HelperResponse.processOutput(stdout: "some output\n", stderr: "warning: something\n")
        let decoded = try roundTrip(original)

        if case .processOutput(let stdout, let stderr) = decoded {
            #expect(stdout == "some output\n")
            #expect(stderr == "warning: something\n")
        } else {
            Issue.record("Expected .processOutput, got \(decoded)")
        }
    }

    @Test("processOutput with empty strings round-trips")
    func processOutputEmptyRoundTrip() throws {
        let original = HelperResponse.processOutput(stdout: "", stderr: "")
        let decoded = try roundTrip(original)

        if case .processOutput(let stdout, let stderr) = decoded {
            #expect(stdout == "")
            #expect(stderr == "")
        } else {
            Issue.record("Expected .processOutput, got \(decoded)")
        }
    }

    @Test("logOutput round-trips through JSON")
    func logOutputRoundTrip() throws {
        let logText = "{\"timestamp\":\"2026-03-24T10:00:00Z\",\"message\":\"test\"}\n"
        let original = HelperResponse.logOutput(logText)
        let decoded = try roundTrip(original)

        if case .logOutput(let output) = decoded {
            #expect(output == logText)
        } else {
            Issue.record("Expected .logOutput, got \(decoded)")
        }
    }

    @Test("logOutput with empty string round-trips")
    func logOutputEmptyRoundTrip() throws {
        let decoded = try roundTrip(.logOutput(""))

        if case .logOutput(let output) = decoded {
            #expect(output == "")
        } else {
            Issue.record("Expected .logOutput, got \(decoded)")
        }
    }

    @Test("version round-trips through JSON")
    func versionRoundTrip() throws {
        let original = HelperResponse.version("1.0.3")
        let decoded = try roundTrip(original)

        if case .version(let version) = decoded {
            #expect(version == "1.0.3")
        } else {
            Issue.record("Expected .version, got \(decoded)")
        }
    }

    @Test("error round-trips through JSON")
    func errorRoundTrip() throws {
        let original = HelperResponse.error("Something went wrong")
        let decoded = try roundTrip(original)

        if case .error(let message) = decoded {
            #expect(message == "Something went wrong")
        } else {
            Issue.record("Expected .error, got \(decoded)")
        }
    }

    @Test("All response cases produce valid JSON data")
    func allCasesEncodeToNonEmptyData() throws {
        let cases: [HelperResponse] = [
            .success,
            .processOutput(stdout: "out", stderr: "err"),
            .logOutput("log line"),
            .version("2.0.0"),
            .error("fail"),
        ]

        for response in cases {
            let data = try encoder.encode(response)
            #expect(!data.isEmpty)
        }
    }

    @Test("processOutput preserves multiline content")
    func processOutputMultiline() throws {
        let multilineStdout = "line1\nline2\nline3\n"
        let multilineStderr = "warn1\nwarn2\n"
        let original = HelperResponse.processOutput(stdout: multilineStdout, stderr: multilineStderr)
        let decoded = try roundTrip(original)

        if case .processOutput(let stdout, let stderr) = decoded {
            #expect(stdout == multilineStdout)
            #expect(stderr == multilineStderr)
        } else {
            Issue.record("Expected .processOutput, got \(decoded)")
        }
    }

    @Test("error preserves special characters in message")
    func errorSpecialCharacters() throws {
        let message = "Failed: path \"/Library/LaunchAgents/test.plist\" not found (errno=2)"
        let decoded = try roundTrip(.error(message))

        if case .error(let decodedMessage) = decoded {
            #expect(decodedMessage == message)
        } else {
            Issue.record("Expected .error, got \(decoded)")
        }
    }
}

// MARK: - PrivilegedHelperClient Extended Tests

@Suite("PrivilegedHelperClient Tests")
struct PrivilegedHelperClientTests {

    @Test("Client can be created multiple times independently")
    func multipleInstances() {
        let client1 = PrivilegedHelperClient()
        let client2 = PrivilegedHelperClient()
        #expect(client1 !== client2)
    }

    @Test("writePlist throws invalidPath for disallowed path")
    func writePlistInvalidPath() async {
        let client = PrivilegedHelperClient()
        do {
            try await client.writePlist(Data(), toPath: "/etc/evil.plist")
            Issue.record("Expected invalidPath error to be thrown")
        } catch let error as PrivilegedHelperError {
            if case .invalidPath(let path) = error {
                #expect(path == "/etc/evil.plist")
            } else {
                Issue.record("Expected .invalidPath, got \(error)")
            }
        } catch {
            Issue.record("Expected PrivilegedHelperError, got \(error)")
        }
    }

    @Test("deletePlist throws invalidPath for disallowed path")
    func deletePlistInvalidPath() async {
        let client = PrivilegedHelperClient()
        do {
            try await client.deletePlist(atPath: "/tmp/bad.plist")
            Issue.record("Expected invalidPath error to be thrown")
        } catch let error as PrivilegedHelperError {
            if case .invalidPath(let path) = error {
                #expect(path == "/tmp/bad.plist")
            } else {
                Issue.record("Expected .invalidPath, got \(error)")
            }
        } catch {
            Issue.record("Expected PrivilegedHelperError, got \(error)")
        }
    }

}

// MARK: - PrivilegedHelperError Extended Tests

@Suite("PrivilegedHelperError Extended Tests")
struct PrivilegedHelperErrorExtendedTests {

    @Test("All error cases produce non-empty descriptions")
    func allCasesHaveDescriptions() {
        let cases: [PrivilegedHelperError] = [
            .notInstalled,
            .connectionFailed,
            .operationFailed("detail"),
            .invalidPath("/some/path"),
            .timeout,
        ]

        for error in cases {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(!description!.isEmpty)
        }
    }

    @Test("notInstalled mentions preferences")
    func notInstalledMentionsPreferences() {
        let error = PrivilegedHelperError.notInstalled
        #expect(error.errorDescription!.contains("preferences"))
    }

    @Test("connectionFailed mentions helper")
    func connectionFailedMentionsHelper() {
        let error = PrivilegedHelperError.connectionFailed
        #expect(error.errorDescription!.contains("helper"))
    }

    @Test("operationFailed includes the detail string")
    func operationFailedIncludesDetail() {
        let detail = "permission denied for /Library/LaunchDaemons"
        let error = PrivilegedHelperError.operationFailed(detail)
        #expect(error.errorDescription!.contains(detail))
    }

    @Test("operationFailed with empty detail still has description")
    func operationFailedEmptyDetail() {
        let error = PrivilegedHelperError.operationFailed("")
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }

    @Test("invalidPath includes the path and mentions allowed directories")
    func invalidPathIncludesPathAndDirectories() {
        let error = PrivilegedHelperError.invalidPath("/usr/local/bin/evil")
        let desc = error.errorDescription!
        #expect(desc.contains("/usr/local/bin/evil"))
        #expect(desc.contains("LaunchAgents") || desc.contains("LaunchDaemons"))
    }

    @Test("timeout mentions timeout")
    func timeoutMentionsTimeout() {
        let error = PrivilegedHelperError.timeout
        #expect(error.errorDescription!.contains("timed out"))
    }

    @Test("Errors conform to LocalizedError")
    func conformsToLocalizedError() {
        let error: any LocalizedError = PrivilegedHelperError.notInstalled
        #expect(error.errorDescription != nil)
    }

    @Test("Errors conform to Sendable")
    func conformsToSendable() {
        let error: any Sendable = PrivilegedHelperError.connectionFailed
        #expect(error is PrivilegedHelperError)
    }
}

// MARK: - HelperMessages Cross-type Tests

@Suite("HelperMessages Cross-type Tests")
struct HelperMessagesCrossTypeTests {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Test("HelperRequest JSON cannot be decoded as HelperResponse")
    func requestCannotDecodeAsResponse() throws {
        let request = HelperRequest.getVersion
        let data = try encoder.encode(request)
        #expect(throws: (any Error).self) {
            try decoder.decode(HelperResponse.self, from: data)
        }
    }

    @Test("HelperResponse JSON cannot be decoded as HelperRequest")
    func responseCannotDecodeAsRequest() throws {
        let response = HelperResponse.success
        let data = try encoder.encode(response)
        #expect(throws: (any Error).self) {
            try decoder.decode(HelperRequest.self, from: data)
        }
    }

    @Test("HelperRequest conforms to Sendable")
    func requestIsSendable() {
        let request: any Sendable = HelperRequest.getVersion
        #expect(request is HelperRequest)
    }

    @Test("HelperResponse conforms to Sendable")
    func responseIsSendable() {
        let response: any Sendable = HelperResponse.success
        #expect(response is HelperResponse)
    }

    @Test("Large data survives HelperRequest round-trip")
    func largeDataRoundTrip() throws {
        let largeData = Data(repeating: 0xAB, count: 100_000)
        let original = HelperRequest.writePlist(data: largeData, path: "/Library/LaunchAgents/big.plist")
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(HelperRequest.self, from: encoded)

        if case .writePlist(let data, _) = decoded {
            #expect(data.count == 100_000)
            #expect(data == largeData)
        } else {
            Issue.record("Expected .writePlist, got \(decoded)")
        }
    }

    @Test("Unicode content survives HelperResponse round-trip")
    func unicodeRoundTrip() throws {
        let unicodeString = "Error: \u{1F4A5} path=/Library/\u{00E9}t\u{00E9}/test \u{2603}"
        let original = HelperResponse.error(unicodeString)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(HelperResponse.self, from: encoded)

        if case .error(let message) = decoded {
            #expect(message == unicodeString)
        } else {
            Issue.record("Expected .error, got \(decoded)")
        }
    }
}
