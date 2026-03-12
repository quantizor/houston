import SwiftUI
import Models

struct KeyPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedKey: PlistKey? = nil

    private var filteredKeys: [PlistKey] {
        guard !searchText.isEmpty else { return PlistKey.allKeys }
        return PlistKey.allKeys.filter {
            $0.key.localizedCaseInsensitiveContains(searchText)
            || $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func keys(for category: PlistKeyCategory) -> [PlistKey] {
        filteredKeys.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            HSplitView {
                // Key list
                List(selection: $selectedKey) {
                    ForEach(PlistKeyCategory.allCases, id: \.self) { category in
                        let categoryKeys = keys(for: category)
                        if !categoryKeys.isEmpty {
                            Section(category.rawValue.capitalized) {
                                ForEach(categoryKeys) { keyInfo in
                                    KeyRow(keyInfo: keyInfo)
                                        .tag(keyInfo)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .searchable(text: $searchText, prompt: "Search keys...")
                .frame(minWidth: 300)

                // Detail pane
                if let key = selectedKey {
                    KeyDetailPane(keyInfo: key)
                        .frame(minWidth: 300)
                } else {
                    ContentUnavailableView {
                        Label("Select a Key", systemImage: "key")
                    } description: {
                        Text("Choose a launchd plist key to view its documentation.")
                    }
                    .frame(minWidth: 300)
                }
            }
            .navigationTitle("Key Palette")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - Key Row

struct KeyRow: View {
    let keyInfo: PlistKey

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(keyInfo.key)
                        .font(.body.monospaced().weight(.medium))

                    if keyInfo.required {
                        Text("Required")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.red)
                    }
                }

                Text(keyInfo.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(keyInfo.type.rawValue)
                .font(.caption2.monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.blue)
        }
    }
}

// MARK: - Key Detail Pane

struct KeyDetailPane: View {
    let keyInfo: PlistKey

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(keyInfo.key)
                        .font(.title2.monospaced().weight(.bold))

                    HStack(spacing: 8) {
                        Text(keyInfo.type.rawValue)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.blue)

                        Text(keyInfo.category.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.secondary)

                        if keyInfo.required {
                            Text("Required")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.red)
                        }
                    }
                }

                Divider()

                // Full description
                Text(keyInfo.description)
                    .font(.body)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background)
    }
}

// Conformance for List selection
extension PlistKey: @retroactive Hashable {
    public static func == (lhs: PlistKey, rhs: PlistKey) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    KeyPaletteView()
}
