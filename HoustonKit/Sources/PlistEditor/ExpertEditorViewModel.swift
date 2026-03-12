import Foundation
import Observation

@Observable
public final class ExpertEditorViewModel {
    public var rootNode: PlistNode?
    public var selectedNodeID: UUID? = nil
    public var hasUnsavedChanges: Bool = false

    public init() {}

    public func load(from dict: [String: Any]) {
        rootNode = PlistNode.fromDictionary(dict)
        hasUnsavedChanges = false
    }

    public func toDictionary() -> [String: Any]? {
        return rootNode?.toDictionary()
    }

    public func addChild(to nodeID: UUID, key: String, value: PlistValue) {
        guard let root = rootNode,
              let targetNode = root.findNode(by: nodeID) else { return }

        let newNode = PlistNode(key: key, value: value)
        newNode.parent = targetNode
        targetNode.children.append(newNode)
        hasUnsavedChanges = true
    }

    public func removeNode(_ nodeID: UUID) {
        guard let root = rootNode else { return }
        // Don't allow removing root
        if root.id == nodeID { return }

        guard let node = root.findNode(by: nodeID),
              let parent = node.parent else { return }

        parent.children.removeAll { $0.id == nodeID }
        if selectedNodeID == nodeID {
            selectedNodeID = nil
        }
        hasUnsavedChanges = true
    }

    public func moveNode(_ nodeID: UUID, to parentID: UUID, at index: Int) {
        guard let root = rootNode,
              let node = root.findNode(by: nodeID),
              let oldParent = node.parent,
              let newParent = root.findNode(by: parentID) else { return }

        oldParent.children.removeAll { $0.id == nodeID }
        node.parent = newParent
        let clampedIndex = min(index, newParent.children.count)
        newParent.children.insert(node, at: clampedIndex)
        hasUnsavedChanges = true
    }
}
