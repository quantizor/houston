import Foundation
import Observation
import Models

@Observable
public final class StandardEditorViewModel {
    public var label: String = ""
    public var program: String = ""
    public var programArguments: [String] = []
    public var runAtLoad: Bool = false
    public var keepAlive: Bool = false
    public var startInterval: Int? = nil
    public var standardOutPath: String = ""
    public var standardErrorPath: String = ""
    public var workingDirectory: String = ""
    public var userName: String = ""
    public var disabled: Bool = false
    public var environmentVariables: [(key: String, value: String)] = []
    public var calendarMonth: Int?
    public var calendarDay: Int?
    public var calendarWeekday: Int?
    public var calendarHour: Int?
    public var calendarMinute: Int?

    public var hasCalendarInterval: Bool {
        calendarMonth != nil || calendarDay != nil || calendarWeekday != nil || calendarHour != nil || calendarMinute != nil
    }

    private var _originalDict: [String: Any]?
    private var _loaded: Bool = false

    public var hasUnsavedChanges: Bool {
        guard _loaded else { return false }
        let current = toDictionary(merging: _originalDict)
        guard let original = _originalDict else { return true }
        return !NSDictionary(dictionary: current).isEqual(to: original)
    }

    public var validationErrors: [PlistValidator.ValidationError] {
        let validator = PlistValidator()
        return validator.validate(toDictionary(merging: _originalDict))
    }

    public init() {}

    public func load(from job: LaunchdJob) {
        label = job.label
        program = job.program ?? ""
        programArguments = job.programArguments ?? []
        runAtLoad = job.runAtLoad ?? false
        keepAlive = job.keepAlive ?? false
        startInterval = job.startInterval
        standardOutPath = job.standardOutPath ?? ""
        standardErrorPath = job.standardErrorPath ?? ""
        workingDirectory = job.workingDirectory ?? ""
        userName = job.userName ?? ""
        disabled = job.disabled ?? false
        if let envVars = job.environmentVariables {
            environmentVariables = envVars.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
        } else {
            environmentVariables = []
        }
        loadCalendarInterval(job.startCalendarInterval)
        _loaded = true
    }

    public func load(from dict: [String: Any]) {
        _originalDict = dict
        label = dict["Label"] as? String ?? ""
        program = dict["Program"] as? String ?? ""
        programArguments = dict["ProgramArguments"] as? [String] ?? []
        runAtLoad = dict["RunAtLoad"] as? Bool ?? false
        keepAlive = dict["KeepAlive"] as? Bool ?? false
        startInterval = dict["StartInterval"] as? Int
        standardOutPath = dict["StandardOutPath"] as? String ?? ""
        standardErrorPath = dict["StandardErrorPath"] as? String ?? ""
        workingDirectory = dict["WorkingDirectory"] as? String ?? ""
        userName = dict["UserName"] as? String ?? ""
        disabled = dict["Disabled"] as? Bool ?? false
        if let envVars = dict["EnvironmentVariables"] as? [String: String] {
            environmentVariables = envVars.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
        } else {
            environmentVariables = []
        }
        loadCalendarInterval(dict["StartCalendarInterval"] as? [String: Int])
        _loaded = true
    }

    private func loadCalendarInterval(_ cal: [String: Int]?) {
        calendarMonth = cal?["Month"]
        calendarDay = cal?["Day"]
        calendarWeekday = cal?["Weekday"]
        calendarHour = cal?["Hour"]
        calendarMinute = cal?["Minute"]
    }

    public func toDictionary(merging original: [String: Any]? = nil) -> [String: Any] {
        var dict = original ?? _originalDict ?? [:]

        dict["Label"] = label

        if !program.isEmpty {
            dict["Program"] = program
        } else {
            dict.removeValue(forKey: "Program")
        }

        if !programArguments.isEmpty {
            dict["ProgramArguments"] = programArguments
        } else {
            dict.removeValue(forKey: "ProgramArguments")
        }

        dict["RunAtLoad"] = runAtLoad
        dict["KeepAlive"] = keepAlive

        if let interval = startInterval {
            dict["StartInterval"] = interval
        } else {
            dict.removeValue(forKey: "StartInterval")
        }

        if !standardOutPath.isEmpty {
            dict["StandardOutPath"] = standardOutPath
        } else {
            dict.removeValue(forKey: "StandardOutPath")
        }

        if !standardErrorPath.isEmpty {
            dict["StandardErrorPath"] = standardErrorPath
        } else {
            dict.removeValue(forKey: "StandardErrorPath")
        }

        if !workingDirectory.isEmpty {
            dict["WorkingDirectory"] = workingDirectory
        } else {
            dict.removeValue(forKey: "WorkingDirectory")
        }

        if !userName.isEmpty {
            dict["UserName"] = userName
        } else {
            dict.removeValue(forKey: "UserName")
        }

        dict["Disabled"] = disabled

        if hasCalendarInterval {
            var cal: [String: Int] = [:]
            if let v = calendarMonth { cal["Month"] = v }
            if let v = calendarDay { cal["Day"] = v }
            if let v = calendarWeekday { cal["Weekday"] = v }
            if let v = calendarHour { cal["Hour"] = v }
            if let v = calendarMinute { cal["Minute"] = v }
            dict["StartCalendarInterval"] = cal
        } else {
            dict.removeValue(forKey: "StartCalendarInterval")
        }

        if !environmentVariables.isEmpty {
            var envDict: [String: String] = [:]
            for pair in environmentVariables {
                if !pair.key.isEmpty {
                    envDict[pair.key] = pair.value
                }
            }
            if !envDict.isEmpty {
                dict["EnvironmentVariables"] = envDict
            } else {
                dict.removeValue(forKey: "EnvironmentVariables")
            }
        } else {
            dict.removeValue(forKey: "EnvironmentVariables")
        }

        return dict
    }
}
