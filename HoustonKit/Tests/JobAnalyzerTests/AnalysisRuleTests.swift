import Testing
import Foundation
@testable import JobAnalyzer
@testable import Models

// MARK: - Helper

private func makeJob(
    label: String = "com.example.test",
    filename: String = "com.example.test.plist"
) -> LaunchdJob {
    LaunchdJob(
        label: label,
        domain: .userAgent,
        plistURL: URL(fileURLWithPath: "/tmp/\(filename)")
    )
}

// MARK: - DeprecatedKeyRule Tests

@Suite("DeprecatedKeyRule Tests")
struct DeprecatedKeyRuleTests {
    let rule = DeprecatedKeyRule()

    @Test("Flags OnDemand key")
    func flagsOnDemand() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "OnDemand": true,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.key == "OnDemand")
        #expect(results.first?.severity == .warning)
    }

    @Test("Flags ServiceIPC key")
    func flagsServiceIPC() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ServiceIPC": true,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.key == "ServiceIPC")
    }

    @Test("No results for clean plist")
    func cleanPlist() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "KeepAlive": true,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }

    @Test("Flags HopefullyExitsLast key")
    func flagsHopefullyExitsLast() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "HopefullyExitsLast": true,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.key == "HopefullyExitsLast")
    }

    @Test("Flags HopefullyExitsFirst key")
    func flagsHopefullyExitsFirst() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "HopefullyExitsFirst": true,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.key == "HopefullyExitsFirst")
    }

    @Test("Flags Debug key")
    func flagsDebug() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Debug": true,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.key == "Debug")
    }

    @Test("Flags EnableGlobbing key")
    func flagsEnableGlobbing() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "EnableGlobbing": true,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.key == "EnableGlobbing")
    }
}

// MARK: - ConflictingKeysRule Tests

@Suite("ConflictingKeysRule Tests")
struct ConflictingKeysRuleTests {
    let rule = ConflictingKeysRule()

    @Test("Flags KeepAlive true with RunAtLoad false")
    func keepAliveWithoutRunAtLoad() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "KeepAlive": true,
            "RunAtLoad": false,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.title.contains("KeepAlive") == true)
    }

    @Test("No conflict when KeepAlive true and RunAtLoad true")
    func keepAliveWithRunAtLoad() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "KeepAlive": true,
            "RunAtLoad": true,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let keepAliveResults = results.filter { $0.title.contains("KeepAlive") }
        #expect(keepAliveResults.isEmpty)
    }

    @Test("Flags StartInterval with StartCalendarInterval")
    func conflictingScheduling() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StartInterval": 300,
            "StartCalendarInterval": ["Hour": 12, "Minute": 0],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.title.contains("scheduling") == true)
    }

    @Test("No conflict with single scheduling key")
    func singleScheduling() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StartInterval": 300,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }
}

// MARK: - LabelRule Tests

@Suite("LabelRule Tests")
struct LabelRuleTests {
    let rule = LabelRule()

    @Test("Flags missing Label")
    func missingLabel() {
        let job = makeJob()
        let plist: [String: Any] = [
            "ProgramArguments": ["/bin/echo"],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.severity == .error)
        #expect(results.first?.title == "Missing Label")
    }

    @Test("Flags label mismatch with filename")
    func labelMismatch() {
        let job = makeJob(label: "com.example.test", filename: "com.different.name.plist")
        let plist: [String: Any] = [
            "Label": "com.example.test",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let mismatch = results.filter { $0.title.contains("match") }
        #expect(mismatch.count == 1)
        #expect(mismatch.first?.severity == .warning)
    }

    @Test("Flags label with spaces")
    func labelWithSpaces() {
        let job = makeJob(label: "com.example.my job", filename: "com.example.my job.plist")
        let plist: [String: Any] = [
            "Label": "com.example.my job",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let specialChars = results.filter { $0.title.contains("special") }
        #expect(specialChars.count == 1)
        #expect(specialChars.first?.severity == .warning)
    }

    @Test("Valid label matching filename passes")
    func validLabel() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }
}

// MARK: - CalendarIntervalRule Tests

@Suite("CalendarIntervalRule Tests")
struct CalendarIntervalRuleTests {
    let rule = CalendarIntervalRule()

    @Test("Flags out-of-range Month")
    func outOfRangeMonth() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StartCalendarInterval": ["Month": 13],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.severity == .error)
        #expect(results.first?.title.contains("Month") == true)
    }

    @Test("Flags out-of-range Hour")
    func outOfRangeHour() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StartCalendarInterval": ["Hour": 25],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.title.contains("Hour") == true)
    }

    @Test("Flags out-of-range Minute")
    func outOfRangeMinute() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StartCalendarInterval": ["Minute": 60],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.title.contains("Minute") == true)
    }

    @Test("Flags negative Weekday")
    func negativeWeekday() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StartCalendarInterval": ["Weekday": -1],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
    }

    @Test("Valid calendar interval passes")
    func validInterval() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StartCalendarInterval": ["Hour": 12, "Minute": 30, "Weekday": 1],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }

    @Test("Handles array of calendar intervals")
    func arrayOfIntervals() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StartCalendarInterval": [
                ["Hour": 12, "Minute": 0],
                ["Hour": 25, "Minute": 0],  // invalid
            ],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.severity == .error)
    }

    @Test("No results when key absent")
    func noCalendarInterval() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }
}

// MARK: - OutputPathRule Tests

@Suite("OutputPathRule Tests")
struct OutputPathRuleTests {
    let rule = OutputPathRule()

    @Test("Flags non-existent directory for StandardOutPath")
    func nonExistentOutDir() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StandardOutPath": "/nonexistent/dir/out.log",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.severity == .warning)
        #expect(results.first?.key == "StandardOutPath")
    }

    @Test("Flags non-existent directory for StandardErrorPath")
    func nonExistentErrDir() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StandardErrorPath": "/nonexistent/dir/err.log",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.key == "StandardErrorPath")
    }

    @Test("Valid output path passes")
    func validOutputPath() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "StandardOutPath": "/tmp/out.log",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }

    @Test("No results when keys absent")
    func noOutputPaths() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }
}

// MARK: - MissingExecutableRule Tests

@Suite("MissingExecutableRule Tests")
struct MissingExecutableRuleTests {
    let rule = MissingExecutableRule()

    @Test("Flags missing executable")
    func missingExecutable() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/nonexistent/path/binary"],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.severity == .error)
    }

    @Test("Existing executable passes")
    func existingExecutable() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/bin/echo"],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }

    @Test("Program key takes precedence")
    func programKey() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": "/nonexistent/path/binary",
            "ProgramArguments": ["/bin/echo"],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.key == "Program")
    }

    @Test("Skips system framework paths")
    func skipsFrameworkPaths() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": "/System/Library/Frameworks/SomeFramework.framework/Versions/A/SomeBinary",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }

    @Test("No results when no executable specified")
    func noExecutable() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }
}

// MARK: - CleanupRule Tests

@Suite("CleanupRule Tests")
struct CleanupRuleTests {
    let rule = CleanupRule()

    @Test("Flags empty plist for cleanup")
    func emptyPlist() {
        let job = makeJob()
        let plist: [String: Any] = [:]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.severity == .info)
        #expect(results.first?.title == "Recommended for cleanup")
        #expect(results.first?.description.contains("empty") == true)
    }

    @Test("Flags plist with no executable, no MachServices, no Sockets")
    func noExecutableNoServices() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": true,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.description.contains("No executable") == true)
    }

    @Test("Does not flag plist with MachServices")
    func hasMachServices() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "MachServices": ["com.example.service": true],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }

    @Test("Does not flag plist with Sockets")
    func hasSockets() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Sockets": ["Listeners": ["SockServiceName": "ssh"]],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }

    @Test("Does not flag plist with valid ProgramArguments")
    func hasValidProgramArguments() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/bin/echo", "hello"],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        // Should not flag no-executable since ProgramArguments is present
        let noExecResults = results.filter { $0.description.contains("No executable") }
        #expect(noExecResults.isEmpty)
    }

    @Test("Does not flag plist with Program key")
    func hasProgramKey() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": "/usr/bin/true",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let noExecResults = results.filter { $0.description.contains("No executable") }
        #expect(noExecResults.isEmpty)
    }

    @Test("Flags orphaned executable when not loaded and not system path")
    func orphanedExecutable() {
        var job = makeJob()
        job.status = .unloaded
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": "/opt/nonexistent-app-\(UUID().uuidString)/binary",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let orphanResults = results.filter { $0.description.contains("missing") }
        #expect(orphanResults.count == 1)
        #expect(orphanResults.first?.severity == .info)
    }

    @Test("Does not flag missing executable on system path")
    func systemPathExecutable() {
        var job = makeJob()
        job.status = .unloaded
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": "/usr/libexec/somebinary",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let orphanResults = results.filter { $0.description.contains("missing") }
        #expect(orphanResults.isEmpty)
    }

    @Test("Does not flag missing executable when job is loaded")
    func loadedJobMissingExec() {
        var job = makeJob()
        job.status = .loaded(lastExitCode: 0)
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": "/opt/nonexistent-app-\(UUID().uuidString)/binary",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let orphanResults = results.filter { $0.description.contains("missing") }
        #expect(orphanResults.isEmpty)
    }

    @Test("Does not flag missing executable in system frameworks path")
    func systemFrameworkPath() {
        var job = makeJob()
        job.status = .unloaded
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": "/System/Library/Frameworks/SomeFramework.framework/binary",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let orphanResults = results.filter { $0.description.contains("missing") }
        #expect(orphanResults.isEmpty)
    }

    @Test("Does not flag missing executable in CoreServices path")
    func coreServicesPath() {
        var job = makeJob()
        job.status = .unloaded
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": "/System/Library/CoreServices/SomeService",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let orphanResults = results.filter { $0.description.contains("missing") }
        #expect(orphanResults.isEmpty)
    }

    @Test("Orphan check uses ProgramArguments first element when no Program key")
    func orphanedViaProgramArguments() {
        var job = makeJob()
        job.status = .unloaded
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/opt/nonexistent-app-\(UUID().uuidString)/binary", "--flag"],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let orphanResults = results.filter { $0.description.contains("missing") }
        #expect(orphanResults.count == 1)
    }
}

// MARK: - PermissionRule Tests

@Suite("PermissionRule Tests")
struct PermissionRuleTests {
    let rule = PermissionRule()

    @Test("No results when executable exists and is executable")
    func executableExists() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": "/bin/echo",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let execResults = results.filter { $0.title.contains("executable") }
        #expect(execResults.isEmpty)
    }

    @Test("No results when executable does not exist on disk")
    func executableMissing() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": "/nonexistent/path/binary",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        // PermissionRule only flags files that exist but lack +x
        #expect(results.isEmpty)
    }

    @Test("No results when no executable specified")
    func noExecutable() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }

    @Test("Uses ProgramArguments first element when no Program key")
    func programArgumentsFallback() {
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/bin/echo", "hello"],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        let execResults = results.filter { $0.title.contains("executable") }
        #expect(execResults.isEmpty)
    }

    @Test("Flags non-executable file via Program key")
    func nonExecutableViaProgram() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let scriptURL = tmpDir.appendingPathComponent("test-noexec-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        // Create a file without execute permission
        try "hello".write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: scriptURL.path)

        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "Program": scriptURL.path,
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.severity == .warning)
        #expect(results.first?.title.contains("not marked as executable") == true)
        #expect(results.first?.key == "Program")
    }

    @Test("Flags non-executable file via ProgramArguments")
    func nonExecutableViaProgramArguments() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let scriptURL = tmpDir.appendingPathComponent("test-noexec-args-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        try "hello".write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: scriptURL.path)

        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": [scriptURL.path, "--flag"],
        ]
        let results = rule.analyze(job: job, plistContents: plist)
        #expect(results.count == 1)
        #expect(results.first?.key == "ProgramArguments")
        #expect(results.first?.suggestion?.contains("chmod") == true)
    }

    @Test("Plist readability check passes for readable file")
    func plistReadable() {
        // The default makeJob uses /tmp/<filename> which doesn't exist,
        // so no plist readability warning is produced
        let job = makeJob()
        let plist: [String: Any] = ["Label": "com.example.test"]
        let results = rule.analyze(job: job, plistContents: plist)
        let readResults = results.filter { $0.title.contains("readable") }
        #expect(readResults.isEmpty)
    }
}

// MARK: - AnalysisResult Tests

@Suite("AnalysisResult Tests")
struct AnalysisResultTests {
    @Test("AnalysisResult stores all properties")
    func storesAllProperties() {
        let result = AnalysisResult(
            severity: .error,
            title: "Test Title",
            description: "Test Description",
            key: "TestKey",
            suggestion: "Fix it"
        )
        #expect(result.severity == .error)
        #expect(result.title == "Test Title")
        #expect(result.description == "Test Description")
        #expect(result.key == "TestKey")
        #expect(result.suggestion == "Fix it")
    }

    @Test("AnalysisResult has unique id")
    func uniqueId() {
        let a = AnalysisResult(severity: .info, title: "A", description: "A")
        let b = AnalysisResult(severity: .info, title: "A", description: "A")
        #expect(a.id != b.id)
    }

    @Test("AnalysisResult key and suggestion default to nil")
    func defaultNilOptionals() {
        let result = AnalysisResult(severity: .warning, title: "T", description: "D")
        #expect(result.key == nil)
        #expect(result.suggestion == nil)
    }

    @Test("Severity comparison: info < warning < error")
    func severityOrdering() {
        #expect(AnalysisResult.Severity.info < .warning)
        #expect(AnalysisResult.Severity.warning < .error)
        #expect(AnalysisResult.Severity.info < .error)
        #expect(!(AnalysisResult.Severity.error < .info))
        #expect(!(AnalysisResult.Severity.warning < .info))
        #expect(!(AnalysisResult.Severity.error < .warning))
    }

    @Test("Severity equal values are not less than each other")
    func severityEqualNotLess() {
        #expect(!(AnalysisResult.Severity.info < .info))
        #expect(!(AnalysisResult.Severity.warning < .warning))
        #expect(!(AnalysisResult.Severity.error < .error))
    }

    @Test("Severity rawValue strings")
    func severityRawValues() {
        #expect(AnalysisResult.Severity.error.rawValue == "error")
        #expect(AnalysisResult.Severity.warning.rawValue == "warning")
        #expect(AnalysisResult.Severity.info.rawValue == "info")
    }

    @Test("Severity CaseIterable contains all cases")
    func severityAllCases() {
        #expect(AnalysisResult.Severity.allCases.count == 3)
        #expect(AnalysisResult.Severity.allCases.contains(.error))
        #expect(AnalysisResult.Severity.allCases.contains(.warning))
        #expect(AnalysisResult.Severity.allCases.contains(.info))
    }

    @Test("Severity Comparable allows sorting")
    func severitySorting() {
        let severities: [AnalysisResult.Severity] = [.error, .info, .warning]
        let sorted = severities.sorted()
        #expect(sorted == [.info, .warning, .error])
    }
}
