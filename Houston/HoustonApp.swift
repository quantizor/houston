import SwiftUI

@main
struct HoustonApp: App {
    @State private var appStore = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appStore)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)

        MenuBarExtra("Houston", systemImage: "gear.badge") {
            MenuBarWidget()
                .environment(appStore)
        }
    }
}
