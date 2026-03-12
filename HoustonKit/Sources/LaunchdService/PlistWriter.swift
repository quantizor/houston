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

        // Merge promoted fields
        dict["Label"] = job.label

        if let programArguments = job.programArguments {
            dict["ProgramArguments"] = programArguments
        }
        if let program = job.program {
            dict["Program"] = program
        }
        if let runAtLoad = job.runAtLoad {
            dict["RunAtLoad"] = runAtLoad
        }
        if let keepAlive = job.keepAlive {
            dict["KeepAlive"] = keepAlive
        }
        if let startInterval = job.startInterval {
            dict["StartInterval"] = startInterval
        }
        if let startCalendarInterval = job.startCalendarInterval {
            dict["StartCalendarInterval"] = startCalendarInterval
        }
        if let standardOutPath = job.standardOutPath {
            dict["StandardOutPath"] = standardOutPath
        }
        if let standardErrorPath = job.standardErrorPath {
            dict["StandardErrorPath"] = standardErrorPath
        }
        if let workingDirectory = job.workingDirectory {
            dict["WorkingDirectory"] = workingDirectory
        }
        if let environmentVariables = job.environmentVariables {
            dict["EnvironmentVariables"] = environmentVariables
        }
        if let userName = job.userName {
            dict["UserName"] = userName
        }
        if let groupName = job.groupName {
            dict["GroupName"] = groupName
        }
        if let disabled = job.disabled {
            dict["Disabled"] = disabled
        }

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

        // Merge promoted fields
        dict["Label"] = job.label

        if let programArguments = job.programArguments {
            dict["ProgramArguments"] = programArguments
        }
        if let program = job.program {
            dict["Program"] = program
        }
        if let runAtLoad = job.runAtLoad {
            dict["RunAtLoad"] = runAtLoad
        }
        if let keepAlive = job.keepAlive {
            dict["KeepAlive"] = keepAlive
        }
        if let startInterval = job.startInterval {
            dict["StartInterval"] = startInterval
        }
        if let startCalendarInterval = job.startCalendarInterval {
            dict["StartCalendarInterval"] = startCalendarInterval
        }
        if let standardOutPath = job.standardOutPath {
            dict["StandardOutPath"] = standardOutPath
        }
        if let standardErrorPath = job.standardErrorPath {
            dict["StandardErrorPath"] = standardErrorPath
        }
        if let workingDirectory = job.workingDirectory {
            dict["WorkingDirectory"] = workingDirectory
        }
        if let environmentVariables = job.environmentVariables {
            dict["EnvironmentVariables"] = environmentVariables
        }
        if let userName = job.userName {
            dict["UserName"] = userName
        }
        if let groupName = job.groupName {
            dict["GroupName"] = groupName
        }
        if let disabled = job.disabled {
            dict["Disabled"] = disabled
        }

        return try serializeDictionary(dict)
    }

    // MARK: - Private

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
