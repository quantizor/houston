import Foundation
import Models

public struct PlistWriter: Sendable {
    public init() {}

    /// Write a LaunchdJob's promoted fields back into a plist dictionary and save.
    /// Preserves any unknown keys already in the file.
    public func write(job: LaunchdJob, to url: URL) throws {
        guard !job.label.isEmpty else {
            throw LaunchctlError.invalidLabel("Label must not be empty")
        }

        // Read existing plist if it exists, otherwise start fresh
        var dict: [String: Any]
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            dict = (try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil
            ) as? [String: Any]) ?? [:]
        } else {
            dict = [:]
        }

        mergePromotedFields(from: job, into: &dict)
        try writeDictionary(dict, to: url)
    }

    /// Update a single key in a plist file, preserving all other keys.
    public func updateKey(_ key: String, value: Any, in url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LaunchctlError.plistNotFound(url)
        }

        let data = try Data(contentsOf: url)
        guard var dict = try PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String: Any] else {
            throw LaunchctlError.plistReadFailed(url, "Not a valid dictionary plist")
        }

        dict[key] = value
        try writeDictionary(dict, to: url)
    }

    /// Create a new plist file with minimal required keys.
    public func createNew(label: String, programArguments: [String], at url: URL) throws {
        guard !label.isEmpty else {
            throw LaunchctlError.invalidLabel("Label must not be empty")
        }

        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArguments,
        ]

        try writeDictionary(dict, to: url)
    }

    /// Create plist data for a new job without writing to disk.
    /// Used when the privileged helper will handle writing.
    public func createNewData(label: String, programArguments: [String]) throws -> Data {
        guard !label.isEmpty else {
            throw LaunchctlError.invalidLabel("Label must not be empty")
        }

        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArguments,
        ]

        return try serializeDictionary(dict)
    }

    /// Serialize a job's promoted fields to plist Data without writing to disk.
    /// Used when the privileged helper will handle writing.
    public func writeData(job: LaunchdJob) throws -> Data {
        guard !job.label.isEmpty else {
            throw LaunchctlError.invalidLabel("Label must not be empty")
        }

        // Read existing plist if it exists, otherwise start fresh
        var dict: [String: Any]
        if FileManager.default.fileExists(atPath: job.plistURL.path) {
            let data = try Data(contentsOf: job.plistURL)
            dict = (try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil
            ) as? [String: Any]) ?? [:]
        } else {
            dict = [:]
        }

        mergePromotedFields(from: job, into: &dict)
        return try serializeDictionary(dict)
    }

    // MARK: - Private

    /// Merge all promoted fields from a job into a plist dictionary.
    /// Sets values when present; removes keys when nil (so cleared fields don't linger).
    private func mergePromotedFields(from job: LaunchdJob, into dict: inout [String: Any]) {
        dict["Label"] = job.label

        if let value = job.programArguments { dict["ProgramArguments"] = value }
        else { dict.removeValue(forKey: "ProgramArguments") }

        if let value = job.program { dict["Program"] = value }
        else { dict.removeValue(forKey: "Program") }

        if let value = job.runAtLoad { dict["RunAtLoad"] = value }
        else { dict.removeValue(forKey: "RunAtLoad") }

        if let value = job.keepAlive { dict["KeepAlive"] = value }
        else { dict.removeValue(forKey: "KeepAlive") }

        if let value = job.startInterval { dict["StartInterval"] = value }
        else { dict.removeValue(forKey: "StartInterval") }

        if let value = job.startCalendarInterval { dict["StartCalendarInterval"] = value }
        else { dict.removeValue(forKey: "StartCalendarInterval") }

        if let value = job.standardOutPath { dict["StandardOutPath"] = value }
        else { dict.removeValue(forKey: "StandardOutPath") }

        if let value = job.standardErrorPath { dict["StandardErrorPath"] = value }
        else { dict.removeValue(forKey: "StandardErrorPath") }

        if let value = job.workingDirectory { dict["WorkingDirectory"] = value }
        else { dict.removeValue(forKey: "WorkingDirectory") }

        if let value = job.environmentVariables { dict["EnvironmentVariables"] = value }
        else { dict.removeValue(forKey: "EnvironmentVariables") }

        if let value = job.userName { dict["UserName"] = value }
        else { dict.removeValue(forKey: "UserName") }

        if let value = job.groupName { dict["GroupName"] = value }
        else { dict.removeValue(forKey: "GroupName") }

        if let value = job.disabled { dict["Disabled"] = value }
        else { dict.removeValue(forKey: "Disabled") }

        if let value = job.processType { dict["ProcessType"] = value }
        else { dict.removeValue(forKey: "ProcessType") }
    }

    private func serializeDictionary(_ dict: [String: Any]) throws -> Data {
        return try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .xml,
            options: 0
        )
    }

    private func writeDictionary(_ dict: [String: Any], to url: URL) throws {
        let data: Data
        do {
            data = try PropertyListSerialization.data(
                fromPropertyList: dict,
                format: .xml,
                options: 0
            )
        } catch {
            throw LaunchctlError.plistWriteFailed(url, error.localizedDescription)
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw LaunchctlError.plistWriteFailed(url, error.localizedDescription)
        }
    }
}
