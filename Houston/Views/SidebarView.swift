import SwiftUI
import Models

struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        List(selection: Binding(
            get: { store.selectedDomain?.rawValue ?? store.selectedFilter?.rawValue },
            set: { newValue in
                if let domain = JobDomainType(rawValue: newValue ?? "") {
                    store.selectedDomain = domain
                    store.selectedFilter = nil
                } else if let filter = AppStore.JobFilter(rawValue: newValue ?? "") {
                    store.selectedFilter = filter
                    store.selectedDomain = nil
                }
            }
        )) {
            Section("Domains") {
                ForEach(JobDomainType.allCases) { domain in
                    Label {
                        HStack {
                            Text(domain.displayName)
                            Spacer()
                            Text("\(store.jobCount(for: domain))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    } icon: {
                        Image(systemName: systemImage(for: domain))
                    }
                    .tag(domain.rawValue)
                }
            }

            Section("Filters") {
                ForEach(AppStore.JobFilter.allCases) { filter in
                    Label {
                        HStack {
                            Text(filter.rawValue)
                            Spacer()
                            Text("\(store.jobCount(for: filter))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    } icon: {
                        Image(systemName: filter.systemImage)
                    }
                    .tag(filter.rawValue)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Houston")
    }

    private func systemImage(for domain: JobDomainType) -> String {
        switch domain {
        case .userAgent: return "person"
        case .globalAgent: return "person.2"
        case .globalDaemon: return "gearshape.2"
        case .systemAgent, .systemDaemon: return "lock.shield"
        case .launchAngel: return "wand.and.stars"
        }
    }
}

#Preview {
    SidebarView()
        .environment(AppStore())
}
