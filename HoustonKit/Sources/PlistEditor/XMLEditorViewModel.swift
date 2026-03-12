import Foundation
import Observation

@Observable
public final class XMLEditorViewModel {
    public var xmlText: String = ""
    public var hasUnsavedChanges: Bool = false
    public var parseError: String? = nil

    private var _originalXML: String = ""

    public init() {}

    public func load(from dict: [String: Any]) {
        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: dict,
                format: .xml,
                options: 0
            )
            xmlText = String(data: data, encoding: .utf8) ?? ""
        } catch {
            xmlText = ""
            parseError = error.localizedDescription
        }
        _originalXML = xmlText
        hasUnsavedChanges = false
        parseError = nil
    }

    public func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        xmlText = String(data: data, encoding: .utf8) ?? ""
        _originalXML = xmlText
        hasUnsavedChanges = false
        parseError = nil
    }

    public func toDictionary() -> [String: Any]? {
        guard let data = xmlText.data(using: .utf8) else {
            parseError = "Invalid UTF-8 encoding"
            return nil
        }

        do {
            let result = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
            parseError = nil
            return result as? [String: Any]
        } catch {
            parseError = error.localizedDescription
            return nil
        }
    }

    public func validate() -> [PlistValidator.ValidationError] {
        let validator = PlistValidator()
        return validator.validateXML(xmlText)
    }
}
