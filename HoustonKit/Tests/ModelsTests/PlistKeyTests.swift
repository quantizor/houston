import Testing
@testable import Models

@Suite("PlistKey Tests")
struct PlistKeyTests {
    @Test("allKeys is not empty and has at least 41 keys")
    func allKeysNotEmpty() {
        #expect(PlistKey.allKeys.count >= 41)
    }

    @Test("Label key is required")
    func labelKeyIsRequired() {
        let labelKey = PlistKey.allKeys.first { $0.key == "Label" }
        #expect(labelKey != nil)
        #expect(labelKey?.required == true)
        #expect(labelKey?.category == .identification)
        #expect(labelKey?.type == .string)
    }

    @Test("All categories are represented")
    func allCategoriesPresent() {
        let representedCategories = Set(PlistKey.allKeys.map(\.category))
        for category in PlistKeyCategory.allCases {
            #expect(representedCategories.contains(category), "Missing category: \(category)")
        }
    }

    @Test("Deprecated keys exist")
    func deprecatedKeysExist() {
        let deprecated = PlistKey.allKeys.filter { $0.category == .deprecated }
        #expect(deprecated.count >= 2)
        let keys = deprecated.map(\.key)
        #expect(keys.contains("OnDemand"))
        #expect(keys.contains("ServiceIPC"))
    }

    @Test("All keys have unique ids")
    func uniqueIds() {
        let ids = PlistKey.allKeys.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("New plist keys are present")
    func newPlistKeysExist() {
        let keyNames = PlistKey.allKeys.map(\.key)
        #expect(keyNames.contains("AssociatedBundleIdentifiers"))
        #expect(keyNames.contains("EnablePressuredExit"))
        #expect(keyNames.contains("EnableTransactions"))
        #expect(keyNames.contains("LaunchEvents"))
        #expect(keyNames.contains("MaterializeDatalessFiles"))
    }

    @Test("lookup returns correct key for known names")
    func lookupKnownKeys() {
        let label = PlistKey.lookup("Label")
        #expect(label != nil)
        #expect(label?.key == "Label")
        #expect(label?.required == true)

        let program = PlistKey.lookup("Program")
        #expect(program != nil)
        #expect(program?.category == .execution)

        let startInterval = PlistKey.lookup("StartInterval")
        #expect(startInterval != nil)
        #expect(startInterval?.type == .integer)
    }

    @Test("lookup returns nil for unknown key")
    func lookupUnknownKey() {
        #expect(PlistKey.lookup("NonExistentKey") == nil)
        #expect(PlistKey.lookup("") == nil)
    }
}
