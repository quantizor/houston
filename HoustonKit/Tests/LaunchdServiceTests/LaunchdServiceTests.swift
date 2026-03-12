import Testing
import Foundation
@testable import LaunchdService
@testable import Models

@Suite("LaunchdService Tests")
@MainActor
struct LaunchdServiceTests {
    @Test("LaunchdService can be initialized")
    func canInit() {
        let service = LaunchdService()
        #expect(service.jobs.isEmpty)
        #expect(service.isLoading == false)
    }

    @Test("ProcessResult stores all fields")
    func processResult() {
        let result = ProcessResult(exitCode: 0, stdout: "hello", stderr: "")
        #expect(result.exitCode == 0)
        #expect(result.stdout == "hello")
        #expect(result.stderr == "")
    }

    @Test("ProcessResult with non-zero exit code")
    func processResultError() {
        let result = ProcessResult(exitCode: 1, stdout: "", stderr: "error msg")
        #expect(result.exitCode == 1)
        #expect(result.stderr == "error msg")
    }

    @Test("LaunchctlListEntry parsing from sample output")
    func parseListOutput() {
        let sampleOutput = """
        PID\tStatus\tLabel
        1234\t0\tcom.apple.finder
        -\t0\tcom.apple.dock
        5678\t-11\tcom.example.running
        -\t78\tcom.example.crashed
        """

        let entries = LaunchctlExecutor.parseListOutput(sampleOutput)

        #expect(entries.count == 4)

        #expect(entries[0].pid == 1234)
        #expect(entries[0].lastExitStatus == 0)
        #expect(entries[0].label == "com.apple.finder")

        #expect(entries[1].pid == nil)
        #expect(entries[1].lastExitStatus == 0)
        #expect(entries[1].label == "com.apple.dock")

        #expect(entries[2].pid == 5678)
        #expect(entries[2].lastExitStatus == -11)
        #expect(entries[2].label == "com.example.running")

        #expect(entries[3].pid == nil)
        #expect(entries[3].lastExitStatus == 78)
        #expect(entries[3].label == "com.example.crashed")
    }

    @Test("LaunchctlListEntry parsing skips empty lines")
    func parseListOutputSkipsEmptyLines() {
        let sampleOutput = """
        PID\tStatus\tLabel
        1234\t0\tcom.example.test

        """

        let entries = LaunchctlExecutor.parseListOutput(sampleOutput)
        #expect(entries.count == 1)
        #expect(entries[0].label == "com.example.test")
    }

    @Test("LaunchctlListEntry parsing handles empty output")
    func parseEmptyOutput() {
        let entries = LaunchctlExecutor.parseListOutput("")
        #expect(entries.isEmpty)
    }

    @Test("PlistWriter.createNew creates valid plist")
    func writerCreateNew() throws {
        let writer = PlistWriter()
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("com.test.createNew.\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: url) }

        try writer.createNew(label: "com.test.agent", programArguments: ["/usr/bin/true"], at: url)

        // Read back and verify
        let data = try Data(contentsOf: url)
        let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]

        #expect(dict["Label"] as? String == "com.test.agent")
        #expect(dict["ProgramArguments"] as? [String] == ["/usr/bin/true"])
    }

    @Test("PlistWriter.createNew rejects empty label")
    func writerRejectsEmptyLabel() throws {
        let writer = PlistWriter()
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("com.test.empty.\(UUID().uuidString).plist")

        #expect(throws: LaunchctlError.self) {
            try writer.createNew(label: "", programArguments: ["/usr/bin/true"], at: url)
        }
    }

    @Test("PlistWriter.updateKey preserves existing keys")
    func writerUpdateKeyPreservesKeys() throws {
        let writer = PlistWriter()
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("com.test.updateKey.\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: url) }

        // Create initial plist
        try writer.createNew(label: "com.test.agent", programArguments: ["/usr/bin/true"], at: url)

        // Update a key
        try writer.updateKey("RunAtLoad", value: true, in: url)

        // Read back and verify both original and new keys exist
        let data = try Data(contentsOf: url)
        let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]

        #expect(dict["Label"] as? String == "com.test.agent")
        #expect(dict["ProgramArguments"] as? [String] == ["/usr/bin/true"])
        #expect(dict["RunAtLoad"] as? Bool == true)
    }

    @Test("PlistWriter.write preserves unknown keys")
    func writerPreservesUnknownKeys() throws {
        let writer = PlistWriter()
        let parser = PlistParser()
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("com.test.preserve.\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: url) }

        // Create a plist with a custom key
        let initialDict: [String: Any] = [
            "Label": "com.test.preserve",
            "ProgramArguments": ["/usr/bin/true"],
            "CustomKey": "custom_value",
            "SomeNumber": 42,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: initialDict, format: .xml, options: 0)
        try data.write(to: url)

        // Parse and write back
        var job = try parser.parse(url: url, domain: .userAgent)
        job.runAtLoad = true
        try writer.write(job: job, to: url)

        // Verify custom keys survived
        let readBack = try Data(contentsOf: url)
        let dict = try PropertyListSerialization.propertyList(from: readBack, options: [], format: nil) as! [String: Any]

        #expect(dict["CustomKey"] as? String == "custom_value")
        #expect(dict["SomeNumber"] as? Int == 42)
        #expect(dict["RunAtLoad"] as? Bool == true)
        #expect(dict["Label"] as? String == "com.test.preserve")
    }

    @Test("LaunchctlError descriptions are non-empty")
    func errorDescriptions() {
        let errors: [LaunchctlError] = [
            .commandFailed(exitCode: 1, stderr: "fail"),
            .parsingFailed("bad"),
            .invalidLabel("empty"),
            .plistNotFound(URL(fileURLWithPath: "/tmp/x.plist")),
            .plistReadFailed(URL(fileURLWithPath: "/tmp/x.plist"), "corrupt"),
            .plistWriteFailed(URL(fileURLWithPath: "/tmp/x.plist"), "denied"),
            .domainDirectoryNotFound("/tmp"),
            .jobNotFound("com.test"),
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}
