import Foundation
import Observation

public enum PlistValue: Sendable {
    case string(String)
    case integer(Int)
    case real(Double)
    case boolean(Bool)
    case date(Date)
    case data(Data)
    case array
    case dictionary

    public var typeDescription: String {
        switch self {
        case .string: return "String"
        case .integer: return "Number"
        case .real: return "Real"
        case .boolean: return "Boolean"
        case .date: return "Date"
        case .data: return "Data"
        case .array: return "Array"
        case .dictionary: return "Dictionary"
        }
    }

    public var displayValue: String {
        switch self {
        case .string(let s): return s
        case .integer(let n): return "\(n)"
        case .real(let d): return "\(d)"
        case .boolean(let b): return b ? "YES" : "NO"
        case .date(let d):
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: d)
        case .data(let d): return "\(d.count) bytes"
        case .array: return ""
        case .dictionary: return ""
        }
    }
}

@Observable
public final class PlistNode: Identifiable, @unchecked Sendable {
    public let id: UUID
    public var key: String
    public var value: PlistValue
    public var children: [PlistNode]
    @ObservationIgnored public weak var parent: PlistNode?

    public init(key: String, value: PlistValue, children: [PlistNode] = []) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.children = children
        for child in children {
            child.parent = self
        }
    }

    /// Returns children for OutlineGroup (nil for leaf nodes to stop disclosure).
    public var optionalChildren: [PlistNode]? {
        children.isEmpty ? nil : children
    }

    /// Whether this node is a leaf (no children, not a container type).
    public var isLeaf: Bool {
        switch value {
        case .dictionary, .array: return false
        default: return true
        }
    }

    public static func fromDictionary(_ dict: [String: Any]) -> PlistNode {
        let root = PlistNode(key: "Root", value: .dictionary)
        root.children = buildChildren(from: dict, parent: root)
        return root
    }

    private static func buildChildren(from dict: [String: Any], parent: PlistNode) -> [PlistNode] {
        return dict.sorted(by: { $0.key < $1.key }).map { key, value in
            let node = nodeFromValue(key: key, value: value)
            node.parent = parent
            return node
        }
    }

    private static func nodeFromValue(key: String, value: Any) -> PlistNode {
        switch value {
        case let s as String:
            return PlistNode(key: key, value: .string(s))
        case let b as Bool where type(of: value) == type(of: true):
            return PlistNode(key: key, value: .boolean(b))
        case let n as Int:
            return PlistNode(key: key, value: .integer(n))
        case let d as Double:
            return PlistNode(key: key, value: .real(d))
        case let date as Date:
            return PlistNode(key: key, value: .date(date))
        case let data as Data:
            return PlistNode(key: key, value: .data(data))
        case let arr as [Any]:
            let node = PlistNode(key: key, value: .array)
            node.children = arr.enumerated().map { index, item in
                let child = nodeFromValue(key: "Item \(index)", value: item)
                child.parent = node
                return child
            }
            return node
        case let dict as [String: Any]:
            let node = PlistNode(key: key, value: .dictionary)
            node.children = buildChildren(from: dict, parent: node)
            return node
        default:
            return PlistNode(key: key, value: .string("\(value)"))
        }
    }

    public func toDictionary() -> [String: Any] {
        switch value {
        case .dictionary:
            var dict: [String: Any] = [:]
            for child in children {
                dict[child.key] = child.toAny()
            }
            return dict
        default:
            return [key: toAny()]
        }
    }

    func toAny() -> Any {
        switch value {
        case .string(let s): return s
        case .integer(let n): return n
        case .real(let d): return d
        case .boolean(let b): return b
        case .date(let d): return d
        case .data(let d): return d
        case .array:
            return children.map { $0.toAny() }
        case .dictionary:
            var dict: [String: Any] = [:]
            for child in children {
                dict[child.key] = child.toAny()
            }
            return dict
        }
    }

    func findNode(by id: UUID) -> PlistNode? {
        if self.id == id { return self }
        for child in children {
            if let found = child.findNode(by: id) { return found }
        }
        return nil
    }
}
