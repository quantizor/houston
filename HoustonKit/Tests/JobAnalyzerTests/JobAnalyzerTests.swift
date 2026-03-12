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

// MARK: - JobAnalyzer Tests

@Suite("JobAnalyzer Tests")
struct JobAnalyzerTests {

    @Test("Analyzer initializes with default rules")
    func defaultInit() {
        let analyzer = JobAnalyzer()
        // Should have all built-in rules
        #expect(analyzer.errorCount == 0)
        #expect(analyzer.warningCount == 0)
    }

    @Test("Analyzer with custom rules")
    func customRules() {
        let analyzer = JobAnalyzer(rules: [DeprecatedKeyRule()])
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/bin/echo", "hello"],
        ]
        let results = analyzer.analyze(job: job, plistContents: plist)
        #expect(results.isEmpty)
    }

    @Test("Valid agent produces no errors")
    func validAgent() {
        let analyzer = JobAnalyzer()
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/bin/echo", "hello"],
            "RunAtLoad": true,
        ]
        let results = analyzer.analyze(job: job, plistContents: plist)
        let errors = results.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    @Test("Deprecated keys are flagged")
    func deprecatedKeys() {
        let analyzer = JobAnalyzer()
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/bin/echo", "hello"],
            "OnDemand": true,
            "ServiceIPC": true,
        ]
        let results = analyzer.analyze(job: job, plistContents: plist)
        let deprecatedResults = results.filter { $0.title.contains("Deprecated") }
        #expect(deprecatedResults.count == 2)
    }

    @Test("Missing executable is flagged")
    func missingExecutable() {
        let analyzer = JobAnalyzer()
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/nonexistent/path/to/binary"],
        ]
        let results = analyzer.analyze(job: job, plistContents: plist)
        let execErrors = results.filter { $0.title == "Executable not found" }
        #expect(execErrors.count == 1)
        #expect(execErrors.first?.severity == .error)
    }

    @Test("analyzeAll processes multiple jobs")
    func analyzeAll() {
        let analyzer = JobAnalyzer()
        let job1 = makeJob(label: "com.example.one", filename: "com.example.one.plist")
        let plist1: [String: Any] = [
            "Label": "com.example.one",
            "ProgramArguments": ["/bin/echo"],
        ]
        let job2 = makeJob(label: "com.example.two", filename: "com.example.two.plist")
        let plist2: [String: Any] = [
            "Label": "com.example.two",
            "ProgramArguments": ["/nonexistent/binary"],
        ]

        let allResults = analyzer.analyzeAll(jobs: [(job1, plist1), (job2, plist2)])
        #expect(allResults.count == 2)
        #expect(allResults["com.example.one"] != nil)
        #expect(allResults["com.example.two"] != nil)

        // job2 should have the missing executable error
        let job2Errors = allResults["com.example.two"]!.filter { $0.severity == .error }
        #expect(job2Errors.contains { $0.title == "Executable not found" })
    }

    @Test("Error and warning counts")
    func counts() {
        let analyzer = JobAnalyzer()
        let job = makeJob()
        let plist: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/nonexistent/binary"],
            "OnDemand": true,
        ]
        _ = analyzer.analyze(job: job, plistContents: plist)
        #expect(analyzer.errorCount >= 1)
        #expect(analyzer.warningCount >= 1)
    }
}
