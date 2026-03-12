import Testing
import Foundation
@testable import Models

@Suite("LaunchdJob Tests")
struct LaunchdJobTests {
    @Test("Init sets id equal to label")
    func initSetsIdEqualToLabel() {
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/com.example.test.plist")
        )
        #expect(job.id == "com.example.test")
        #expect(job.label == "com.example.test")
    }

    @Test("Default status is unloaded")
    func defaultStatusIsUnloaded() {
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.status == .unloaded)
        #expect(job.isEnabled == true)
    }

    @Test("Display name returns last label component")
    func displayNameReturnsLastComponent() {
        let job = LaunchdJob(
            label: "com.example.myagent",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.displayName == "myagent")
    }

    @Test("Display name for single-component label")
    func displayNameSingleComponent() {
        let job = LaunchdJob(
            label: "myagent",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.displayName == "myagent")
    }

    @Test("Executable path prefers program over programArguments")
    func executablePathPrefersProgram() {
        var job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        job.program = "/usr/bin/env"
        job.programArguments = ["/bin/sh", "-c", "echo hello"]
        #expect(job.executablePath == "/usr/bin/env")
    }

    @Test("Executable path falls back to programArguments first element")
    func executablePathFallback() {
        var job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        job.programArguments = ["/bin/sh", "-c", "echo hello"]
        #expect(job.executablePath == "/bin/sh")
    }

    @Test("Executable path is nil when no program or arguments")
    func executablePathNil() {
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        #expect(job.executablePath == nil)
    }
}
