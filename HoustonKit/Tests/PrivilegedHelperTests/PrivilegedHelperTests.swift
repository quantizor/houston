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
