import Foundation
import Observation
import Models
import LaunchdService

@Observable
public final class PlistEditorViewModel {
    public enum EditorTab: String, CaseIterable, Sendable {
        case standard = "Standard"
        case expert = "Expert"
        case xml = "XML"
    }

    public var activeTab: EditorTab = .standard
    public var standardEditor = StandardEditorViewModel()
    public var expertEditor = ExpertEditorViewModel()
    public var xmlEditor = XMLEditorViewModel()

    public var hasUnsavedChanges: Bool {
        switch activeTab {
        case .standard: return standardEditor.hasUnsavedChanges
        case .expert: return expertEditor.hasUnsavedChanges
        case .xml: return xmlEditor.hasUnsavedChanges
        }
    }

    private var originalDict: [String: Any]?

    public init() {}

    public func load(job: LaunchdJob, plistContents: [String: Any]) {
        originalDict = plistContents
        standardEditor.load(from: plistContents)
        expertEditor.load(from: plistContents)
        xmlEditor.load(from: plistContents)
    }

    public func syncFromActiveTab() {
        switch activeTab {
        case .standard:
            let dict = standardEditor.toDictionary(merging: originalDict)
            expertEditor.load(from: dict)
            xmlEditor.load(from: dict)
        case .expert:
            if let dict = expertEditor.toDictionary() {
                standardEditor.load(from: dict)
                xmlEditor.load(from: dict)
            }
        case .xml:
            if let dict = xmlEditor.toDictionary() {
                standardEditor.load(from: dict)
                expertEditor.load(from: dict)
            }
        }
    }

    public func toDictionary() -> [String: Any]? {
        switch activeTab {
        case .standard:
            return standardEditor.toDictionary(merging: originalDict)
        case .expert:
            return expertEditor.toDictionary()
        case .xml:
            return xmlEditor.toDictionary()
        }
    }
}
