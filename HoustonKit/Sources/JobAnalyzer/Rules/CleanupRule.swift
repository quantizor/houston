import Foundation
import Models

/// Recommends cleanup for plists that appear to be junk or orphaned.
public struct CleanupRule: AnalysisRule {
    public var name: String { "Cleanup Recommendation" }

    public init() {}

    public func analyze(job: LaunchdJob, plistContents: [String: Any]) -> [AnalysisResult] {
        var results: [AnalysisResult] = []

        // Empty plist — already handled by LabelRule, but add cleanup suggestion
        if plistContents.isEmpty {
            results.append(AnalysisResult(
                severity: .info,
                title: "Recommended for cleanup",
                description: "This plist is empty and serves no purpose.",
                suggestion: "Delete this file."
            ))
            return results
        }

        // Executable missing + not loaded = orphaned
        let execPath = executablePath(from: plistContents)
        if let path = execPath, !FileManager.default.fileExists(atPath: path) {
            // Skip system framework paths that may not be indexable
            let systemPrefixes = [
                "/System/Library/Frameworks",
                "/System/Library/PrivateFrameworks",
                "/usr/libexec",
                "/System/Library/CoreServices",
            ]
            let isSystemPath = systemPrefixes.contains { path.hasPrefix($0) }

            if !isSystemPath && !job.status.isLoaded {
                results.append(AnalysisResult(
                    severity: .info,
                    title: "Recommended for cleanup",
                    description: "Executable missing and job is not loaded — likely from an uninstalled app.",
                    suggestion: "Delete this file."
                ))
            }
        }

        // No program or arguments defined
        if execPath == nil && plistContents["MachServices"] == nil && plistContents["Sockets"] == nil {
            results.append(AnalysisResult(
                severity: .info,
                title: "Recommended for cleanup",
                description: "No executable, MachServices, or Sockets defined — this plist cannot do anything.",
                suggestion: "Delete this file."
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
