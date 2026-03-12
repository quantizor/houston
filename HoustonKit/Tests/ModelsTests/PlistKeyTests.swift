import Testing
@testable import Models

@Suite("PlistKey Tests")
struct PlistKeyTests {
    @Test("allKeys is not empty and has at least 36 keys")
    func allKeysNotEmpty() {
        #expect(PlistKey.allKeys.count >= 36)
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
}
