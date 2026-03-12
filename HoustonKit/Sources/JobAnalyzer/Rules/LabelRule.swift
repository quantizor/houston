import Foundation
import Models

/// Validates the Label key in launchd plist files.
public struct LabelRule: AnalysisRule {
    public var name: String { "Label Validation" }

    public init() {}

    public func analyze(job: LaunchdJob, plistContents: [String: Any]) -> [AnalysisResult] {
        var results: [AnalysisResult] = []

        guard let label = plistContents["Label"] as? String else {
            results.append(AnalysisResult(
                severity: .error,
                title: "Missing Label",
                description: "The plist is missing the required Label key.",
                key: "Label",
                suggestion: "Add a Label key with a unique reverse-DNS identifier."
            ))
            return results
        }

        // Check for spaces or special characters
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        if label.unicodeScalars.contains(where: { !allowedCharacters.contains($0) }) {
            results.append(AnalysisResult(
                severity: .warning,
                title: "Label contains special characters",
                description: "The label \"\(label)\" contains spaces or special characters.",
                key: "Label",
                suggestion: "Use only alphanumeric characters, dots, hyphens, and underscores."
            ))
        }

        // Check label matches filename
        let filename = job.plistURL.deletingPathExtension().lastPathComponent
        if label != filename {
            results.append(AnalysisResult(
                severity: .warning,
                title: "Label does not match filename",
                description: "The label \"\(label)\" does not match the plist filename \"\(filename)\".",
                key: "Label",
                suggestion: "Rename the file to \"\(label).plist\" or update the Label to match."
            ))
        }

        return results
    }
}
