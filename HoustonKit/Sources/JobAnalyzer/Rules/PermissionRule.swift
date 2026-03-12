import Foundation
import Models

/// Checks executable and plist file permissions.
public struct PermissionRule: AnalysisRule {
    public var name: String { "Permission Check" }

    public init() {}

    public func analyze(job: LaunchdJob, plistContents: [String: Any]) -> [AnalysisResult] {
        var results: [AnalysisResult] = []
        let fileManager = FileManager.default

        // Check executable is +x
        if let executablePath = executablePath(from: plistContents),
           fileManager.fileExists(atPath: executablePath) {
            if !fileManager.isExecutableFile(atPath: executablePath) {
                results.append(AnalysisResult(
                    severity: .warning,
                    title: "Executable not marked as executable",
                    description: "The file at \"\(executablePath)\" is not executable.",
                    key: plistContents["Program"] != nil ? "Program" : "ProgramArguments",
                    suggestion: "Run: chmod +x \"\(executablePath)\""
                ))
            }
        }

        // Check plist file is readable
        let plistPath = job.plistURL.path
        if fileManager.fileExists(atPath: plistPath),
           !fileManager.isReadableFile(atPath: plistPath) {
            results.append(AnalysisResult(
                severity: .warning,
                title: "Plist file not readable",
                description: "The plist file at \"\(plistPath)\" is not readable by the current user.",
                suggestion: "Check file permissions with: ls -la \"\(plistPath)\""
            ))
        }

        return results
    }

    private func executablePath(from plistContents: [String: Any]) -> String? {
        if let program = plistContents["Program"] as? String {
            return program
        }
        if let args = plistContents["ProgramArguments"] as? [String], let first = args.first {
            return first
        }
        return nil
    }
}
