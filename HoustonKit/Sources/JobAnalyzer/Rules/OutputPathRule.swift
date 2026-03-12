import Foundation
import Models

/// Checks that parent directories of StandardOutPath and StandardErrorPath exist and are writable.
public struct OutputPathRule: AnalysisRule {
    public var name: String { "Output Path Check" }

    public init() {}

    public func analyze(job: LaunchdJob, plistContents: [String: Any]) -> [AnalysisResult] {
        var results: [AnalysisResult] = []

        let pathKeys = ["StandardOutPath", "StandardErrorPath"]
        for key in pathKeys {
            if let path = plistContents[key] as? String {
                results.append(contentsOf: checkOutputPath(path, key: key))
            }
        }

        return results
    }

    private func checkOutputPath(_ path: String, key: String) -> [AnalysisResult] {
        var results: [AnalysisResult] = []
        let fileManager = FileManager.default
        let parentDir = (path as NSString).deletingLastPathComponent

        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: parentDir, isDirectory: &isDirectory) {
            results.append(AnalysisResult(
                severity: .warning,
                title: "Output directory does not exist",
                description: "The parent directory \"\(parentDir)\" for \(key) does not exist.",
                key: key,
                suggestion: "Create the directory: mkdir -p \"\(parentDir)\""
            ))
        } else if isDirectory.boolValue && !fileManager.isWritableFile(atPath: parentDir) {
            results.append(AnalysisResult(
                severity: .warning,
                title: "Output directory not writable",
                description: "The parent directory \"\(parentDir)\" for \(key) is not writable.",
                key: key,
                suggestion: "Check permissions: chmod u+w \"\(parentDir)\""
            ))
        }

        return results
    }
}
