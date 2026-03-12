import Testing
import Foundation
@testable import PlistEditor
@testable import Models

// MARK: - PlistNode Tests

@Suite("PlistNode Tests")
struct PlistNodeTests {
    @Test("fromDictionary creates correct tree structure")
    func fromDictionaryCreatesTree() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/usr/bin/true", "--flag"],
            "EnvironmentVariables": ["PATH": "/usr/bin", "HOME": "/Users/test"],
        ]

        let root = PlistNode.fromDictionary(dict)

        #expect(root.key == "Root")
        if case .dictionary = root.value {} else {
            Issue.record("Root should be dictionary")
        }
        #expect(root.children.count == 3)

        // Children are sorted by key
        let envNode = root.children.first { $0.key == "EnvironmentVariables" }
        #expect(envNode != nil)
        if case .dictionary = envNode?.value {} else {
            Issue.record("EnvironmentVariables should be dictionary")
        }
        #expect(envNode?.children.count == 2)

        let progArgs = root.children.first { $0.key == "ProgramArguments" }
        #expect(progArgs != nil)
        if case .array = progArgs?.value {} else {
            Issue.record("ProgramArguments should be array")
        }
        #expect(progArgs?.children.count == 2)
    }

    @Test("toDictionary round-trips correctly")
    func toDictionaryRoundTrips() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": true,
            "StartInterval": 300,
            "ProgramArguments": ["/usr/bin/echo", "hello"],
        ]

        let root = PlistNode.fromDictionary(dict)
        let result = root.toDictionary()

        #expect(result["Label"] as? String == "com.example.test")
        #expect(result["RunAtLoad"] as? Bool == true)
        #expect(result["StartInterval"] as? Int == 300)
        let args = result["ProgramArguments"] as? [String]
        #expect(args == ["/usr/bin/echo", "hello"])
    }

    @Test("PlistValue typeDescription returns correct strings")
    func typeDescriptions() {
        #expect(PlistValue.string("test").typeDescription == "String")
        #expect(PlistValue.integer(42).typeDescription == "Number")
        #expect(PlistValue.real(3.14).typeDescription == "Real")
        #expect(PlistValue.boolean(true).typeDescription == "Boolean")
        #expect(PlistValue.array.typeDescription == "Array")
        #expect(PlistValue.dictionary.typeDescription == "Dictionary")
        #expect(PlistValue.data(Data()).typeDescription == "Data")
        #expect(PlistValue.date(Date()).typeDescription == "Date")
    }

    @Test("PlistValue displayValue returns formatted values")
    func displayValues() {
        #expect(PlistValue.string("hello").displayValue == "hello")
        #expect(PlistValue.integer(42).displayValue == "42")
        #expect(PlistValue.boolean(true).displayValue == "YES")
        #expect(PlistValue.boolean(false).displayValue == "NO")
        #expect(PlistValue.data(Data([0x01, 0x02])).displayValue == "2 bytes")
    }
}

// MARK: - PlistValidator Tests

@Suite("PlistValidator Tests")
struct PlistValidatorTests {
    let validator = PlistValidator()

    @Test("Valid plist passes validation")
    func validPlistPasses() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/usr/bin/true"],
            "RunAtLoad": true,
        ]
        let errors = validator.validate(dict)
        #expect(errors.isEmpty)
    }

    @Test("Missing Label produces error")
    func missingLabelError() {
        let dict: [String: Any] = [
            "ProgramArguments": ["/usr/bin/true"],
        ]
        let errors = validator.validate(dict)
        #expect(errors.contains { $0.key == "Label" && $0.severity == .error })
    }

    @Test("Empty Label produces error")
    func emptyLabelError() {
        let dict: [String: Any] = [
            "Label": "",
        ]
        let errors = validator.validate(dict)
        #expect(errors.contains { $0.key == "Label" })
    }

    @Test("Invalid StartInterval produces error")
    func invalidStartInterval() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "StartInterval": -5,
        ]
        let errors = validator.validate(dict)
        #expect(errors.contains { $0.key == "StartInterval" })
    }

    @Test("Invalid StartCalendarInterval produces error")
    func invalidCalendarInterval() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "StartCalendarInterval": ["Hour": 25],
        ]
        let errors = validator.validate(dict)
        #expect(errors.contains { $0.key.starts(with: "StartCalendarInterval") })
    }

    @Test("Invalid XML produces error")
    func invalidXMLError() {
        let errors = validator.validateXML("this is not xml")
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.key == "XML" && $0.severity == .error })
    }

    @Test("Valid XML passes parsing")
    func validXMLPasses() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.example.test</string>
        </dict>
        </plist>
        """
        let errors = validator.validateXML(xml)
        #expect(errors.isEmpty)
    }
}

// MARK: - StandardEditorViewModel Tests

@Suite("StandardEditorViewModel Tests")
struct StandardEditorViewModelTests {
    @Test("Load from LaunchdJob populates all fields")
    func loadFromJob() {
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        var mutableJob = job
        mutableJob.program = "/usr/bin/echo"
        mutableJob.programArguments = ["/usr/bin/echo", "hello"]
        mutableJob.runAtLoad = true
        mutableJob.keepAlive = false
        mutableJob.startInterval = 60
        mutableJob.standardOutPath = "/tmp/out.log"
        mutableJob.standardErrorPath = "/tmp/err.log"
        mutableJob.workingDirectory = "/tmp"
        mutableJob.userName = "root"
        mutableJob.disabled = false
        mutableJob.environmentVariables = ["PATH": "/usr/bin"]

        let vm = StandardEditorViewModel()
        vm.load(from: mutableJob)

        #expect(vm.label == "com.example.test")
        #expect(vm.program == "/usr/bin/echo")
        #expect(vm.programArguments == ["/usr/bin/echo", "hello"])
        #expect(vm.runAtLoad == true)
        #expect(vm.keepAlive == false)
        #expect(vm.startInterval == 60)
        #expect(vm.standardOutPath == "/tmp/out.log")
        #expect(vm.standardErrorPath == "/tmp/err.log")
        #expect(vm.workingDirectory == "/tmp")
        #expect(vm.userName == "root")
        #expect(vm.disabled == false)
        #expect(vm.environmentVariables.count == 1)
        #expect(vm.environmentVariables.first?.key == "PATH")
    }

    @Test("toDictionary produces correct output")
    func toDictionaryOutput() {
        let vm = StandardEditorViewModel()
        vm.label = "com.example.test"
        vm.program = "/usr/bin/echo"
        vm.programArguments = ["/usr/bin/echo", "hello"]
        vm.runAtLoad = true
        vm.startInterval = 300

        let dict = vm.toDictionary()
        #expect(dict["Label"] as? String == "com.example.test")
        #expect(dict["Program"] as? String == "/usr/bin/echo")
        #expect(dict["ProgramArguments"] as? [String] == ["/usr/bin/echo", "hello"])
        #expect(dict["RunAtLoad"] as? Bool == true)
        #expect(dict["StartInterval"] as? Int == 300)
    }

    @Test("toDictionary merges with original preserving unknown keys")
    func toDictionaryMergesOriginal() {
        let original: [String: Any] = [
            "Label": "com.example.test",
            "CustomKey": "should-be-preserved",
            "MachServices": ["com.example.service": true],
        ]

        let vm = StandardEditorViewModel()
        vm.load(from: original)
        vm.label = "com.example.modified"

        let dict = vm.toDictionary(merging: original)
        #expect(dict["Label"] as? String == "com.example.modified")
        #expect(dict["CustomKey"] as? String == "should-be-preserved")
        #expect(dict["MachServices"] != nil)
    }

    @Test("hasUnsavedChanges detects modifications")
    func detectsChanges() {
        let original: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": false,
            "KeepAlive": false,
            "Disabled": false,
        ]

        let vm = StandardEditorViewModel()
        vm.load(from: original)
        #expect(vm.hasUnsavedChanges == false)

        vm.label = "com.example.changed"
        #expect(vm.hasUnsavedChanges == true)
    }
}

// MARK: - XMLEditorViewModel Tests

@Suite("XMLEditorViewModel Tests")
struct XMLEditorViewModelTests {
    @Test("Load from dictionary produces valid XML")
    func loadFromDictProducesXML() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": true,
        ]
        let vm = XMLEditorViewModel()
        vm.load(from: dict)

        #expect(vm.xmlText.contains("com.example.test"))
        #expect(vm.xmlText.contains("<?xml"))
        #expect(vm.parseError == nil)
    }

    @Test("toDictionary parses back correctly")
    func toDictionaryRoundTrips() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": true,
        ]
        let vm = XMLEditorViewModel()
        vm.load(from: dict)

        let result = vm.toDictionary()
        #expect(result != nil)
        #expect(result?["Label"] as? String == "com.example.test")
        #expect(result?["RunAtLoad"] as? Bool == true)
    }

    @Test("Invalid XML returns nil from toDictionary")
    func invalidXMLReturnsNil() {
        let vm = XMLEditorViewModel()
        vm.xmlText = "this is not valid xml"

        let result = vm.toDictionary()
        #expect(result == nil)
        #expect(vm.parseError != nil)
    }

    @Test("Validate catches errors in XML")
    func validateCatchesErrors() {
        let vm = XMLEditorViewModel()
        vm.xmlText = "not xml at all"

        let errors = vm.validate()
        #expect(!errors.isEmpty)
    }

    @Test("Validate passes for valid XML")
    func validatePassesForValid() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
        ]
        let vm = XMLEditorViewModel()
        vm.load(from: dict)

        let errors = vm.validate()
        #expect(errors.isEmpty)
    }
}
