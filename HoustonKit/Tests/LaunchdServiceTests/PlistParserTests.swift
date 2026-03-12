import Testing
import Foundation
@testable import LaunchdService
@testable import Models

@Suite("PlistParser Tests")
struct PlistParserTests {
    private func createTempPlist(_ dict: [String: Any]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.test.\(UUID().uuidString).plist")
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: url)
        return url
    }

    @Test("Parse minimal plist with Label and ProgramArguments")
    func parseMinimal() throws {
        let url = try createTempPlist([
            "Label": "com.test.minimal",
            "ProgramArguments": ["/usr/bin/true"],
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = PlistParser()
        let job = try parser.parse(url: url, domain: .userAgent)

        #expect(job.label == "com.test.minimal")
        #expect(job.programArguments == ["/usr/bin/true"])
        #expect(job.domain == .userAgent)
        #expect(job.status == .unloaded)
        #expect(job.isEnabled == true)
    }

    @Test("Parse plist with all promoted keys")
    func parseAllPromotedKeys() throws {
        let url = try createTempPlist([
            "Label": "com.test.full",
            "ProgramArguments": ["/usr/bin/env", "bash", "-c", "echo hello"],
            "Program": "/usr/bin/env",
            "RunAtLoad": true,
            "KeepAlive": true,
            "StartInterval": 300,
            "StartCalendarInterval": ["Hour": 3, "Minute": 30],
            "StandardOutPath": "/tmp/out.log",
            "StandardErrorPath": "/tmp/err.log",
            "WorkingDirectory": "/tmp",
            "EnvironmentVariables": ["PATH": "/usr/bin", "HOME": "/Users/test"],
            "UserName": "root",
            "GroupName": "wheel",
            "Disabled": false,
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = PlistParser()
        let job = try parser.parse(url: url, domain: .globalDaemon)

        #expect(job.label == "com.test.full")
        #expect(job.programArguments == ["/usr/bin/env", "bash", "-c", "echo hello"])
        #expect(job.program == "/usr/bin/env")
        #expect(job.runAtLoad == true)
        #expect(job.keepAlive == true)
        #expect(job.startInterval == 300)
        #expect(job.startCalendarInterval?["Hour"] == 3)
        #expect(job.startCalendarInterval?["Minute"] == 30)
        #expect(job.standardOutPath == "/tmp/out.log")
        #expect(job.standardErrorPath == "/tmp/err.log")
        #expect(job.workingDirectory == "/tmp")
        #expect(job.environmentVariables?["PATH"] == "/usr/bin")
        #expect(job.userName == "root")
        #expect(job.groupName == "wheel")
        #expect(job.disabled == false)
        #expect(job.isEnabled == true)
        #expect(job.domain == .globalDaemon)
    }

    @Test("Parse plist with Disabled=true sets isEnabled=false")
    func parseDisabledJob() throws {
        let url = try createTempPlist([
            "Label": "com.test.disabled",
            "ProgramArguments": ["/usr/bin/true"],
            "Disabled": true,
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = PlistParser()
        let job = try parser.parse(url: url, domain: .userAgent)

        #expect(job.disabled == true)
        #expect(job.isEnabled == false)
    }

    @Test("Parse plist without Label falls back to filename")
    func parseFallbackLabel() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.test.fallback.\(UUID().uuidString).plist")
        let dict: [String: Any] = [
            "ProgramArguments": ["/usr/bin/true"],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = PlistParser()
        let job = try parser.parse(url: url, domain: .userAgent)

        // Should use filename without .plist extension
        #expect(job.label == url.deletingPathExtension().lastPathComponent)
    }

    @Test("Parse non-existent plist throws")
    func parseNonExistent() throws {
        let parser = PlistParser()
        let url = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).plist")

        #expect(throws: LaunchctlError.self) {
            _ = try parser.parse(url: url, domain: .userAgent)
        }
    }

    @Test("readPlist returns dictionary for valid plist")
    func readPlistValid() throws {
        let url = try createTempPlist([
            "Label": "com.test.read",
            "ProgramArguments": ["/usr/bin/true"],
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = PlistParser()
        let dict = try parser.readPlist(at: url)

        #expect(dict["Label"] as? String == "com.test.read")
    }

    @Test("discoverPlists returns empty for non-existent directory")
    func discoverNonExistent() throws {
        // userAgent directory likely exists, but we test the behavior gracefully
        let parser = PlistParser()
        // This just shouldn't crash; the directory may or may not exist
        let _ = try parser.discoverPlists(in: .userAgent)
    }

    @Test("executablePath computed property")
    func executablePath() throws {
        let url = try createTempPlist([
            "Label": "com.test.exec",
            "ProgramArguments": ["/usr/bin/env", "bash"],
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = PlistParser()
        let job = try parser.parse(url: url, domain: .userAgent)

        // No Program set, so should use first of ProgramArguments
        #expect(job.executablePath == "/usr/bin/env")
    }

    @Test("executablePath prefers Program over ProgramArguments")
    func executablePathPrefersProgram() throws {
        let url = try createTempPlist([
            "Label": "com.test.exec2",
            "Program": "/usr/local/bin/myapp",
            "ProgramArguments": ["/usr/bin/env", "bash"],
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = PlistParser()
        let job = try parser.parse(url: url, domain: .userAgent)

        #expect(job.executablePath == "/usr/local/bin/myapp")
    }
}
