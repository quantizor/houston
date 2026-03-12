import Foundation
import Models

/// Checks if the executable referenced by Program or ProgramArguments[0] exists on disk.
public struct MissingExecutableRule: AnalysisRule {
    public var name: String { "Missing Executable" }

    /// Framework/system paths that may not be directly indexable.
    private static let skipPrefixes: [String] = [
        "/System/Library/Frameworks",
        "/System/Library/PrivateFrameworks",
        "/usr/libexec",
        "/System/Library/CoreServices",
    ]

    public init() {}

    public func analyze(job: LaunchdJob, plistContents: [String: Any]) -> [AnalysisResult] {
        guard let executablePath = executablePath(from: plistContents) else {
            return []
        }

        // Skip paths that are in framework/system directories which may not be indexable.
        for prefix in Self.skipPrefixes {
            if executablePath.hasPrefix(prefix) {
                return []
            }
        }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: executablePath) {
            return [
                AnalysisResult(
                    severity: .error,
                    title: "Executable not found",
                    description: "The executable at \"\(executablePath)\" does not exist on disk.",
                    key: plistContents["Program"] != nil ? "Program" : "ProgramArguments",
                    suggestion: "Verify the path is correct or reinstall the associated application."
                )
            ]
        }

        return []
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
