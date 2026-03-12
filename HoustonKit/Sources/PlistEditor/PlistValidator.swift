import Foundation

public struct PlistValidator: Sendable {
    public struct ValidationError: Identifiable, Sendable {
        public let id: UUID
        public let key: String
        public let message: String
        public let severity: ValidationSeverity

        public init(key: String, message: String, severity: ValidationSeverity) {
            self.id = UUID()
            self.key = key
            self.message = message
            self.severity = severity
        }
    }

    public enum ValidationSeverity: Sendable {
        case error, warning
    }

    public init() {}

    public func validate(_ dict: [String: Any]) -> [ValidationError] {
        var errors: [ValidationError] = []

        // Label must exist and be non-empty string
        if let label = dict["Label"] {
            if let labelStr = label as? String {
                if labelStr.isEmpty {
                    errors.append(ValidationError(
                        key: "Label",
                        message: "Label must not be empty",
                        severity: .error
                    ))
                }
            } else {
                errors.append(ValidationError(
                    key: "Label",
                    message: "Label must be a string",
                    severity: .error
                ))
            }
        } else {
            errors.append(ValidationError(
                key: "Label",
                message: "Label is required",
                severity: .error
            ))
        }

        // ProgramArguments must be array of strings if present
        if let progArgs = dict["ProgramArguments"] {
            if let arr = progArgs as? [Any] {
                for (index, item) in arr.enumerated() {
                    if !(item is String) {
                        errors.append(ValidationError(
                            key: "ProgramArguments",
                            message: "Item at index \(index) must be a string",
                            severity: .error
                        ))
                    }
                }
            } else {
                errors.append(ValidationError(
                    key: "ProgramArguments",
                    message: "ProgramArguments must be an array",
                    severity: .error
                ))
            }
        }

        // StartInterval must be positive integer if present
        if let interval = dict["StartInterval"] {
            if let n = interval as? Int {
                if n <= 0 {
                    errors.append(ValidationError(
                        key: "StartInterval",
                        message: "StartInterval must be a positive integer",
                        severity: .error
                    ))
                }
            } else {
                errors.append(ValidationError(
                    key: "StartInterval",
                    message: "StartInterval must be an integer",
                    severity: .error
                ))
            }
        }

        // StartCalendarInterval validation
        if let calInterval = dict["StartCalendarInterval"] {
            let validRanges: [String: ClosedRange<Int>] = [
                "Minute": 0...59,
                "Hour": 0...23,
                "Day": 1...31,
                "Weekday": 0...7,
                "Month": 1...12,
            ]

            func validateCalendarDict(_ d: [String: Any]) {
                for (key, value) in d {
                    if let range = validRanges[key] {
                        if let n = value as? Int {
                            if !range.contains(n) {
                                errors.append(ValidationError(
                                    key: "StartCalendarInterval.\(key)",
                                    message: "\(key) must be in range \(range.lowerBound)...\(range.upperBound)",
                                    severity: .error
                                ))
                            }
                        }
                    }
                }
            }

            if let d = calInterval as? [String: Any] {
                validateCalendarDict(d)
            } else if let arr = calInterval as? [[String: Any]] {
                for d in arr {
                    validateCalendarDict(d)
                }
            }
        }

        // Boolean keys must actually be booleans
        let booleanKeys = [
            "RunAtLoad", "KeepAlive", "Disabled", "EnableGlobbing",
            "AbandonProcessGroup", "StartOnMount", "Debug",
            "InitGroups", "LowPriorityIO", "LowPriorityBackgroundIO",
            "OnDemand", "ServiceIPC",
        ]
        for boolKey in booleanKeys {
            if let value = dict[boolKey] {
                // NSNumber booleans are tricky - we check it's not a non-boolean number
                if value is String || value is [Any] || value is [String: Any] {
                    errors.append(ValidationError(
                        key: boolKey,
                        message: "\(boolKey) must be a boolean",
                        severity: .warning
                    ))
                }
            }
        }

        return errors
    }

    public func validateXML(_ xml: String) -> [ValidationError] {
        var errors: [ValidationError] = []

        guard let data = xml.data(using: .utf8) else {
            errors.append(ValidationError(
                key: "XML",
                message: "Invalid UTF-8 encoding",
                severity: .error
            ))
            return errors
        }

        do {
            let result = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
            if let dict = result as? [String: Any] {
                errors.append(contentsOf: validate(dict))
            }
        } catch {
            errors.append(ValidationError(
                key: "XML",
                message: "Failed to parse XML: \(error.localizedDescription)",
                severity: .error
            ))
        }

        return errors
    }
}
