import Foundation
import Models

public struct PlistParser: Sendable {
    public init() {}

    /// Parse a single plist file into a LaunchdJob.
    public func parse(url: URL, domain: JobDomainType) throws -> LaunchdJob {
        let dict = try readPlist(at: url)

        let label: String
        if let plistLabel = dict["Label"] as? String, !plistLabel.isEmpty {
            label = plistLabel
        } else {
            label = url.deletingPathExtension().lastPathComponent
        }

        var job = LaunchdJob(
            label: label,
            domain: domain,
            plistURL: url,
            status: .unloaded,
            isEnabled: true
        )

        // Promoted keys
        job.programArguments = dict["ProgramArguments"] as? [String]
        job.program = dict["Program"] as? String
        job.runAtLoad = dict["RunAtLoad"] as? Bool
        job.keepAlive = dict["KeepAlive"] as? Bool
        job.startInterval = dict["StartInterval"] as? Int
        job.standardOutPath = dict["StandardOutPath"] as? String
        job.standardErrorPath = dict["StandardErrorPath"] as? String
        job.workingDirectory = dict["WorkingDirectory"] as? String
        job.environmentVariables = dict["EnvironmentVariables"] as? [String: String]
        job.userName = dict["UserName"] as? String
        job.groupName = dict["GroupName"] as? String
        job.disabled = dict["Disabled"] as? Bool

        if let calendarInterval = dict["StartCalendarInterval"] as? [String: Int] {
            job.startCalendarInterval = calendarInterval
        }

        if let isDisabled = job.disabled {
            job.isEnabled = !isDisabled
        }

        return job
    }

    /// Discover all plist files in a domain directory.
    public func discoverPlists(in domain: JobDomainType) throws -> [URL] {
        let directoryPath = domain.directory
        let fm = FileManager.default

        guard fm.fileExists(atPath: directoryPath) else {
            return []
        }

        let directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        let contents = try fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return contents.filter { $0.pathExtension == "plist" }
    }

    /// Read raw plist as dictionary.
    public func readPlist(at url: URL) throws -> [String: Any] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            throw LaunchctlError.plistNotFound(url)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LaunchctlError.plistReadFailed(url, error.localizedDescription)
        }

        guard let plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw LaunchctlError.plistReadFailed(url, "Not a valid dictionary plist")
        }

        return plist
    }
}
