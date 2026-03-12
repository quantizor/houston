import SwiftUI
import AppKit

@main
struct HoustonApp: App {
    @State private var appStore = AppStore()

    init() {
        #if DEBUG
        // InjectionIII: hot-reload view bodies during development
        // Install from: https://github.com/johnno1962/InjectionIII
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/macOSInjection.bundle")?.load()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appStore)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    // Set dock icon from bundled PNG to bypass macOS squircle masking
                    if let url = Bundle.main.url(forResource: "DockIcon", withExtension: "png"),
                       let image = NSImage(contentsOf: url) {
                        NSApp.applicationIconImage = image
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)

        MenuBarExtra("Houston", systemImage: "gear.badge") {
            MenuBarWidget()
                .environment(appStore)
        }
    }
}
