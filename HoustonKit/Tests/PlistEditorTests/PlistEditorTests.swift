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

    @Test("Load from URL reads file correctly")
    func loadFromURL() throws {
        let dict: [String: Any] = ["Label": "com.example.url"]
        let data = try PropertyListSerialization.data(
            fromPropertyList: dict, format: .xml, options: 0
        )
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xml_test_\(UUID().uuidString).plist")
        try data.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let vm = XMLEditorViewModel()
        try vm.load(from: tmpURL)

        #expect(vm.xmlText.contains("com.example.url"))
        #expect(vm.parseError == nil)
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("hasUnsavedChanges is false after load, true after edit")
    func unsavedChangesTracking() {
        let vm = XMLEditorViewModel()
        vm.load(from: ["Label": "com.example.test"])
        #expect(vm.hasUnsavedChanges == false)

        vm.hasUnsavedChanges = true
        #expect(vm.hasUnsavedChanges == true)
    }
}

// MARK: - ExpertEditorViewModel Tests

@Suite("ExpertEditorViewModel Tests")
struct ExpertEditorViewModelTests {
    @Test("Initialization starts with nil root and no changes")
    func initialization() {
        let vm = ExpertEditorViewModel()
        #expect(vm.rootNode == nil)
        #expect(vm.selectedNodeID == nil)
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("Load from dictionary creates root node")
    func loadFromDictionary() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": true,
        ]
        let vm = ExpertEditorViewModel()
        vm.load(from: dict)

        #expect(vm.rootNode != nil)
        #expect(vm.rootNode?.key == "Root")
        #expect(vm.rootNode?.children.count == 2)
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("toDictionary returns correct output after load")
    func toDictionaryAfterLoad() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "StartInterval": 300,
        ]
        let vm = ExpertEditorViewModel()
        vm.load(from: dict)

        let result = vm.toDictionary()
        #expect(result != nil)
        #expect(result?["Label"] as? String == "com.example.test")
        #expect(result?["StartInterval"] as? Int == 300)
    }

    @Test("toDictionary returns nil when no root")
    func toDictionaryNilRoot() {
        let vm = ExpertEditorViewModel()
        #expect(vm.toDictionary() == nil)
    }

    @Test("addChild appends node and marks unsaved")
    func addChild() {
        let vm = ExpertEditorViewModel()
        vm.load(from: ["Label": "com.example.test"])

        let rootID = vm.rootNode!.id
        vm.addChild(to: rootID, key: "NewKey", value: .string("NewValue"))

        #expect(vm.rootNode?.children.count == 2)
        let newNode = vm.rootNode?.children.first { $0.key == "NewKey" }
        #expect(newNode != nil)
        if case .string(let s) = newNode?.value {
            #expect(s == "NewValue")
        } else {
            Issue.record("Expected string value")
        }
        #expect(vm.hasUnsavedChanges == true)
    }

    @Test("addChild to nonexistent node does nothing")
    func addChildNonexistentNode() {
        let vm = ExpertEditorViewModel()
        vm.load(from: ["Label": "com.example.test"])

        let fakeID = UUID()
        vm.addChild(to: fakeID, key: "Ghost", value: .string("nope"))

        #expect(vm.rootNode?.children.count == 1)
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("addChild to nil root does nothing")
    func addChildNilRoot() {
        let vm = ExpertEditorViewModel()
        vm.addChild(to: UUID(), key: "Ghost", value: .string("nope"))
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("removeNode removes child and marks unsaved")
    func removeNode() {
        let vm = ExpertEditorViewModel()
        vm.load(from: ["Label": "com.example.test", "RunAtLoad": true])

        let labelNode = vm.rootNode!.children.first { $0.key == "Label" }!
        vm.removeNode(labelNode.id)

        #expect(vm.rootNode?.children.count == 1)
        #expect(vm.rootNode?.children.first?.key == "RunAtLoad")
        #expect(vm.hasUnsavedChanges == true)
    }

    @Test("removeNode clears selection if removed node was selected")
    func removeNodeClearsSelection() {
        let vm = ExpertEditorViewModel()
        vm.load(from: ["Label": "com.example.test"])

        let labelNode = vm.rootNode!.children.first!
        vm.selectedNodeID = labelNode.id
        vm.removeNode(labelNode.id)

        #expect(vm.selectedNodeID == nil)
    }

    @Test("removeNode does not allow removing root")
    func cannotRemoveRoot() {
        let vm = ExpertEditorViewModel()
        vm.load(from: ["Label": "com.example.test"])

        let rootID = vm.rootNode!.id
        vm.removeNode(rootID)

        #expect(vm.rootNode != nil)
        #expect(vm.rootNode?.children.count == 1)
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("removeNode with nil root does nothing")
    func removeNodeNilRoot() {
        let vm = ExpertEditorViewModel()
        vm.removeNode(UUID())
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("removeNode with nonexistent ID does nothing")
    func removeNodeNonexistentID() {
        let vm = ExpertEditorViewModel()
        vm.load(from: ["Label": "com.example.test"])
        vm.removeNode(UUID())
        #expect(vm.rootNode?.children.count == 1)
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("moveNode moves child between parents")
    func moveNode() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "EnvironmentVariables": ["PATH": "/usr/bin"],
        ]
        let vm = ExpertEditorViewModel()
        vm.load(from: dict)

        let labelNode = vm.rootNode!.children.first { $0.key == "Label" }!
        let envNode = vm.rootNode!.children.first { $0.key == "EnvironmentVariables" }!

        vm.moveNode(labelNode.id, to: envNode.id, at: 0)

        // Label should now be under EnvironmentVariables
        #expect(vm.rootNode!.children.count == 1) // only EnvironmentVariables at root
        #expect(envNode.children.contains { $0.key == "Label" })
        #expect(vm.hasUnsavedChanges == true)
    }

    @Test("moveNode clamps index to children count")
    func moveNodeClampsIndex() {
        let vm = ExpertEditorViewModel()
        vm.load(from: ["Label": "com.example.test", "EnvironmentVariables": ["A": "1"]])

        let labelNode = vm.rootNode!.children.first { $0.key == "Label" }!
        let envNode = vm.rootNode!.children.first { $0.key == "EnvironmentVariables" }!

        // Use an index larger than children count
        vm.moveNode(labelNode.id, to: envNode.id, at: 999)

        #expect(envNode.children.contains { $0.key == "Label" })
        #expect(vm.hasUnsavedChanges == true)
    }

    @Test("moveNode with nil root does nothing")
    func moveNodeNilRoot() {
        let vm = ExpertEditorViewModel()
        vm.moveNode(UUID(), to: UUID(), at: 0)
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("addChild with various value types")
    func addChildVariousTypes() {
        let vm = ExpertEditorViewModel()
        vm.load(from: ["Label": "com.example.test"])
        let rootID = vm.rootNode!.id

        vm.addChild(to: rootID, key: "Count", value: .integer(42))
        vm.addChild(to: rootID, key: "Ratio", value: .real(3.14))
        vm.addChild(to: rootID, key: "Enabled", value: .boolean(true))

        let result = vm.toDictionary()
        #expect(result?["Count"] as? Int == 42)
        #expect(result?["Ratio"] as? Double == 3.14)
        #expect(result?["Enabled"] as? Bool == true)
    }
}

// MARK: - PlistEditorViewModel Tests

@Suite("PlistEditorViewModel Tests")
struct PlistEditorViewModelTests {
    @Test("Initialization defaults to standard tab")
    func initialization() {
        let vm = PlistEditorViewModel()
        #expect(vm.activeTab == .standard)
    }

    @Test("Load populates all sub-editors")
    func loadPopulatesAllEditors() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": true,
            "StartInterval": 60,
        ]
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.load(job: job, plistContents: dict)

        #expect(vm.standardEditor.label == "com.example.test")
        #expect(vm.expertEditor.rootNode != nil)
        #expect(vm.xmlEditor.xmlText.contains("com.example.test"))
    }

    @Test("hasUnsavedChanges reflects standard tab")
    func hasUnsavedChangesStandard() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": false,
            "KeepAlive": false,
            "Disabled": false,
        ]
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.activeTab = .standard
        vm.load(job: job, plistContents: dict)
        #expect(vm.hasUnsavedChanges == false)

        vm.standardEditor.label = "com.example.changed"
        #expect(vm.hasUnsavedChanges == true)
    }

    @Test("hasUnsavedChanges reflects expert tab")
    func hasUnsavedChangesExpert() {
        let dict: [String: Any] = ["Label": "com.example.test"]
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.load(job: job, plistContents: dict)
        vm.activeTab = .expert
        #expect(vm.hasUnsavedChanges == false)

        vm.expertEditor.addChild(
            to: vm.expertEditor.rootNode!.id,
            key: "New", value: .string("val")
        )
        #expect(vm.hasUnsavedChanges == true)
    }

    @Test("hasUnsavedChanges reflects xml tab")
    func hasUnsavedChangesXML() {
        let dict: [String: Any] = ["Label": "com.example.test"]
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.load(job: job, plistContents: dict)
        vm.activeTab = .xml
        #expect(vm.hasUnsavedChanges == false)

        vm.xmlEditor.hasUnsavedChanges = true
        #expect(vm.hasUnsavedChanges == true)
    }

    @Test("toDictionary returns from standard tab")
    func toDictionaryStandard() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": false,
            "KeepAlive": false,
            "Disabled": false,
        ]
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.activeTab = .standard
        vm.load(job: job, plistContents: dict)

        let result = vm.toDictionary()
        #expect(result != nil)
        #expect(result?["Label"] as? String == "com.example.test")
    }

    @Test("toDictionary returns from expert tab")
    func toDictionaryExpert() {
        let dict: [String: Any] = ["Label": "com.example.expert"]
        let job = LaunchdJob(
            label: "com.example.expert",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.load(job: job, plistContents: dict)
        vm.activeTab = .expert

        let result = vm.toDictionary()
        #expect(result != nil)
        #expect(result?["Label"] as? String == "com.example.expert")
    }

    @Test("toDictionary returns from xml tab")
    func toDictionaryXML() {
        let dict: [String: Any] = ["Label": "com.example.xml"]
        let job = LaunchdJob(
            label: "com.example.xml",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.load(job: job, plistContents: dict)
        vm.activeTab = .xml

        let result = vm.toDictionary()
        #expect(result != nil)
        #expect(result?["Label"] as? String == "com.example.xml")
    }

    @Test("syncFromActiveTab standard syncs to expert and xml")
    func syncFromStandard() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": false,
            "KeepAlive": false,
            "Disabled": false,
        ]
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.load(job: job, plistContents: dict)
        vm.activeTab = .standard
        vm.standardEditor.label = "com.example.synced"

        vm.syncFromActiveTab()

        // Expert and XML should now reflect the change
        let expertDict = vm.expertEditor.toDictionary()
        #expect(expertDict?["Label"] as? String == "com.example.synced")
        #expect(vm.xmlEditor.xmlText.contains("com.example.synced"))
    }

    @Test("syncFromActiveTab expert syncs to standard and xml")
    func syncFromExpert() {
        let dict: [String: Any] = ["Label": "com.example.test"]
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.load(job: job, plistContents: dict)
        vm.activeTab = .expert

        // Modify expert editor
        let rootID = vm.expertEditor.rootNode!.id
        vm.expertEditor.addChild(to: rootID, key: "RunAtLoad", value: .boolean(true))

        vm.syncFromActiveTab()

        #expect(vm.xmlEditor.xmlText.contains("RunAtLoad"))
    }

    @Test("syncFromActiveTab xml syncs to standard and expert")
    func syncFromXML() {
        let dict: [String: Any] = ["Label": "com.example.test"]
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.load(job: job, plistContents: dict)
        vm.activeTab = .xml

        // The XML was loaded, syncing should work
        vm.syncFromActiveTab()

        #expect(vm.standardEditor.label == "com.example.test")
        #expect(vm.expertEditor.rootNode != nil)
    }

    @Test("syncFromActiveTab xml with invalid XML does not crash")
    func syncFromXMLInvalid() {
        let dict: [String: Any] = ["Label": "com.example.test"]
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = PlistEditorViewModel()
        vm.load(job: job, plistContents: dict)
        vm.activeTab = .xml
        vm.xmlEditor.xmlText = "invalid xml"

        // Should not crash, just not sync
        vm.syncFromActiveTab()
    }

    @Test("EditorTab has correct raw values")
    func editorTabRawValues() {
        #expect(PlistEditorViewModel.EditorTab.standard.rawValue == "Standard")
        #expect(PlistEditorViewModel.EditorTab.expert.rawValue == "Expert")
        #expect(PlistEditorViewModel.EditorTab.xml.rawValue == "XML")
        #expect(PlistEditorViewModel.EditorTab.allCases.count == 3)
    }
}

// MARK: - Additional StandardEditorViewModel Tests

@Suite("StandardEditorViewModel Edge Cases")
struct StandardEditorViewModelEdgeCaseTests {
    @Test("toDictionary removes empty optional fields")
    func removesEmptyOptionalFields() {
        let vm = StandardEditorViewModel()
        vm.label = "com.example.test"
        // Leave all optional strings empty
        vm.program = ""
        vm.standardOutPath = ""
        vm.standardErrorPath = ""
        vm.workingDirectory = ""
        vm.userName = ""
        vm.programArguments = []
        vm.startInterval = nil

        let dict = vm.toDictionary()
        #expect(dict["Program"] == nil)
        #expect(dict["StandardOutPath"] == nil)
        #expect(dict["StandardErrorPath"] == nil)
        #expect(dict["WorkingDirectory"] == nil)
        #expect(dict["UserName"] == nil)
        #expect(dict["ProgramArguments"] == nil)
        #expect(dict["StartInterval"] == nil)
    }

    @Test("Environment variables with empty keys are excluded")
    func envVarsEmptyKeysExcluded() {
        let vm = StandardEditorViewModel()
        vm.label = "com.example.test"
        vm.environmentVariables = [
            (key: "", value: "should-be-excluded"),
            (key: "VALID", value: "included"),
        ]

        let dict = vm.toDictionary()
        let envDict = dict["EnvironmentVariables"] as? [String: String]
        #expect(envDict != nil)
        #expect(envDict?["VALID"] == "included")
        #expect(envDict?.count == 1)
    }

    @Test("Environment variables all empty keys removes the key entirely")
    func envVarsAllEmptyKeysRemoved() {
        let vm = StandardEditorViewModel()
        vm.label = "com.example.test"
        vm.environmentVariables = [
            (key: "", value: "nope"),
        ]

        let dict = vm.toDictionary()
        #expect(dict["EnvironmentVariables"] == nil)
    }

    @Test("validationErrors returns errors for invalid state")
    func validationErrorsReturned() {
        let vm = StandardEditorViewModel()
        vm.load(from: ["Label": ""])

        let errors = vm.validationErrors
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.key == "Label" })
    }

    @Test("validationErrors returns empty for valid state")
    func validationErrorsEmpty() {
        let vm = StandardEditorViewModel()
        vm.load(from: [
            "Label": "com.example.valid",
            "ProgramArguments": ["/usr/bin/true"],
        ])

        let errors = vm.validationErrors
        #expect(errors.isEmpty)
    }

    @Test("Load from job with nil optionals uses defaults")
    func loadFromJobNilOptionals() {
        let job = LaunchdJob(
            label: "com.example.minimal",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )

        let vm = StandardEditorViewModel()
        vm.load(from: job)

        #expect(vm.label == "com.example.minimal")
        #expect(vm.program == "")
        #expect(vm.programArguments == [])
        #expect(vm.runAtLoad == false)
        #expect(vm.keepAlive == false)
        #expect(vm.startInterval == nil)
        #expect(vm.standardOutPath == "")
        #expect(vm.standardErrorPath == "")
        #expect(vm.workingDirectory == "")
        #expect(vm.userName == "")
        #expect(vm.disabled == false)
        #expect(vm.environmentVariables.isEmpty)
    }

    @Test("hasUnsavedChanges is false before loading")
    func noUnsavedChangesBeforeLoad() {
        let vm = StandardEditorViewModel()
        #expect(vm.hasUnsavedChanges == false)
    }

    @Test("hasUnsavedChanges true when no original dict")
    func unsavedChangesNoOriginal() {
        let vm = StandardEditorViewModel()
        let job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        vm.load(from: job)
        // load(from: LaunchdJob) does not set _originalDict,
        // so hasUnsavedChanges should be true since original is nil
        #expect(vm.hasUnsavedChanges == true)
    }

    @Test("Calendar interval loads from dict")
    func calendarIntervalLoad() {
        let vm = StandardEditorViewModel()
        vm.load(from: [
            "Label": "com.example.test",
            "StartCalendarInterval": ["Hour": 9, "Minute": 30, "Weekday": 1]
        ])
        #expect(vm.calendarHour == 9)
        #expect(vm.calendarMinute == 30)
        #expect(vm.calendarWeekday == 1)
        #expect(vm.calendarMonth == nil)
        #expect(vm.calendarDay == nil)
        #expect(vm.hasCalendarInterval == true)
    }

    @Test("Calendar interval round-trips through toDictionary")
    func calendarIntervalRoundTrip() {
        let vm = StandardEditorViewModel()
        vm.load(from: [
            "Label": "com.example.test",
            "StartCalendarInterval": ["Hour": 14, "Day": 15]
        ])
        let dict = vm.toDictionary()
        let cal = dict["StartCalendarInterval"] as? [String: Int]
        #expect(cal?["Hour"] == 14)
        #expect(cal?["Day"] == 15)
        #expect(cal?["Minute"] == nil)
    }

    @Test("Empty calendar interval removes key from dict")
    func calendarIntervalEmpty() {
        let vm = StandardEditorViewModel()
        vm.load(from: [
            "Label": "com.example.test",
            "StartCalendarInterval": ["Hour": 9]
        ])
        vm.calendarHour = nil
        #expect(vm.hasCalendarInterval == false)
        let dict = vm.toDictionary()
        #expect(dict["StartCalendarInterval"] == nil)
    }

    @Test("Calendar interval loads from LaunchdJob")
    func calendarIntervalFromJob() {
        let vm = StandardEditorViewModel()
        var job = LaunchdJob(
            label: "com.example.test",
            domain: .userAgent,
            plistURL: URL(fileURLWithPath: "/tmp/test.plist")
        )
        job.startCalendarInterval = ["Hour": 8, "Minute": 0]
        vm.load(from: job)
        #expect(vm.calendarHour == 8)
        #expect(vm.calendarMinute == 0)
        #expect(vm.hasCalendarInterval == true)
    }
}

// MARK: - Additional PlistValidator Tests

@Suite("PlistValidator Edge Cases")
struct PlistValidatorEdgeCaseTests {
    let validator = PlistValidator()

    @Test("Non-string Label produces error")
    func nonStringLabel() {
        let dict: [String: Any] = ["Label": 123]
        let errors = validator.validate(dict)
        #expect(errors.contains { $0.key == "Label" && $0.message.contains("must be a string") })
    }

    @Test("Non-integer StartInterval produces error")
    func nonIntegerStartInterval() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "StartInterval": "not a number",
        ]
        let errors = validator.validate(dict)
        #expect(errors.contains { $0.key == "StartInterval" && $0.message.contains("must be an integer") })
    }

    @Test("Non-array ProgramArguments produces error")
    func nonArrayProgramArguments() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": "not an array",
        ]
        let errors = validator.validate(dict)
        #expect(errors.contains { $0.key == "ProgramArguments" && $0.message.contains("must be an array") })
    }

    @Test("ProgramArguments with non-string items produces errors")
    func programArgumentsNonStringItems() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "ProgramArguments": ["/usr/bin/true", 42, true] as [Any],
        ]
        let errors = validator.validate(dict)
        #expect(errors.contains { $0.key == "ProgramArguments" && $0.message.contains("index") })
    }

    @Test("Boolean key with string value produces warning")
    func booleanKeyStringValue() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "RunAtLoad": "yes",
        ]
        let errors = validator.validate(dict)
        #expect(errors.contains { $0.key == "RunAtLoad" && $0.severity == .warning })
    }

    @Test("StartCalendarInterval array is validated")
    func calendarIntervalArray() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "StartCalendarInterval": [
                ["Hour": 25],
                ["Minute": 70],
            ],
        ]
        let errors = validator.validate(dict)
        #expect(errors.contains { $0.key == "StartCalendarInterval.Hour" })
        #expect(errors.contains { $0.key == "StartCalendarInterval.Minute" })
    }

    @Test("Valid StartCalendarInterval passes")
    func validCalendarInterval() {
        let dict: [String: Any] = [
            "Label": "com.example.test",
            "StartCalendarInterval": ["Hour": 12, "Minute": 30],
        ]
        let errors = validator.validate(dict)
        #expect(errors.isEmpty)
    }
}

// MARK: - Additional PlistNode Tests

@Suite("PlistNode Edge Cases")
struct PlistNodeEdgeCaseTests {
    @Test("isLeaf returns true for scalar types")
    func isLeafScalar() {
        let node = PlistNode(key: "test", value: .string("hello"))
        #expect(node.isLeaf == true)

        let intNode = PlistNode(key: "num", value: .integer(42))
        #expect(intNode.isLeaf == true)

        let boolNode = PlistNode(key: "flag", value: .boolean(true))
        #expect(boolNode.isLeaf == true)
    }

    @Test("isLeaf returns false for container types")
    func isLeafContainer() {
        let dictNode = PlistNode(key: "dict", value: .dictionary)
        #expect(dictNode.isLeaf == false)

        let arrayNode = PlistNode(key: "arr", value: .array)
        #expect(arrayNode.isLeaf == false)
    }

    @Test("optionalChildren returns nil for empty children")
    func optionalChildrenEmpty() {
        let node = PlistNode(key: "leaf", value: .string("hello"))
        #expect(node.optionalChildren == nil)
    }

    @Test("optionalChildren returns children when present")
    func optionalChildrenPresent() {
        let child = PlistNode(key: "child", value: .string("val"))
        let parent = PlistNode(key: "parent", value: .dictionary, children: [child])
        #expect(parent.optionalChildren != nil)
        #expect(parent.optionalChildren?.count == 1)
    }

    @Test("findNode locates deeply nested nodes")
    func findNodeDeep() {
        let dict: [String: Any] = [
            "Outer": ["Inner": "value"],
        ]
        let root = PlistNode.fromDictionary(dict)

        let outerNode = root.children.first { $0.key == "Outer" }
        let innerNode = outerNode?.children.first { $0.key == "Inner" }
        #expect(innerNode != nil)

        let found = root.findNode(by: innerNode!.id)
        #expect(found?.key == "Inner")
    }

    @Test("findNode returns nil for nonexistent ID")
    func findNodeNotFound() {
        let root = PlistNode.fromDictionary(["Label": "test"])
        #expect(root.findNode(by: UUID()) == nil)
    }

    @Test("displayValue for real, date, array, dictionary")
    func displayValueAdditional() {
        #expect(PlistValue.real(2.5).displayValue == "2.5")
        #expect(PlistValue.array.displayValue == "")
        #expect(PlistValue.dictionary.displayValue == "")

        let date = Date(timeIntervalSince1970: 0)
        let dateValue = PlistValue.date(date)
        #expect(!dateValue.displayValue.isEmpty)
    }

    @Test("toDictionary on non-dictionary node wraps in dict")
    func toDictionaryNonRoot() {
        let node = PlistNode(key: "myKey", value: .string("myVal"))
        let dict = node.toDictionary()
        #expect(dict["myKey"] as? String == "myVal")
    }

    @Test("fromDictionary handles Data values")
    func fromDictionaryData() {
        let dict: [String: Any] = [
            "BinaryData": Data([0x01, 0x02, 0x03]),
        ]
        let root = PlistNode.fromDictionary(dict)
        let dataNode = root.children.first { $0.key == "BinaryData" }
        #expect(dataNode != nil)
        if case .data(let d) = dataNode?.value {
            #expect(d.count == 3)
        } else {
            Issue.record("Expected data value")
        }
    }

    @Test("fromDictionary handles Date values")
    func fromDictionaryDate() {
        let now = Date()
        let dict: [String: Any] = ["Created": now]
        let root = PlistNode.fromDictionary(dict)
        let dateNode = root.children.first { $0.key == "Created" }
        #expect(dateNode != nil)
        if case .date = dateNode?.value {} else {
            Issue.record("Expected date value")
        }
    }

    @Test("fromDictionary handles Double values")
    func fromDictionaryDouble() {
        let dict: [String: Any] = ["Ratio": 3.14 as Double]
        let root = PlistNode.fromDictionary(dict)
        let node = root.children.first { $0.key == "Ratio" }
        #expect(node != nil)
        if case .real(let d) = node?.value {
            #expect(d == 3.14)
        } else {
            Issue.record("Expected real value")
        }
    }
}
