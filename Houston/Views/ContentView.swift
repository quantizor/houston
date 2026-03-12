import SwiftUI
import Models

struct ContentView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } content: {
            JobListView()
                .navigationSplitViewColumnWidth(min: 320, ideal: 400, max: 600)
        } detail: {
            DetailView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await store.refreshJobs() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store.isLoading)
            }

            ToolbarItem(placement: .keyboard) {
                Button {
                    store.showingKeyPalette = true
                } label: {
                    Text("Key Palette")
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $store.showingKeyPalette) {
            KeyPaletteView()
        }
        .task {
            await store.ensureHelperInstalled()
            await store.refreshJobs()
        }
        .onChange(of: store.isLoading) { _, isLoading in
            if !isLoading {
                AccessibilityNotification.Announcement("Jobs loaded").post()
            }
        }
        .toast(store.currentToast)
    }
}

#Preview {
    ContentView()
        .environment(AppStore())
} 
