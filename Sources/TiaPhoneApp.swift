import SwiftUI

@main
struct TiaPhoneApp: App {
    @StateObject private var store = ProjectStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: ProjectStore
    var body: some View {
        Group {
            if store.project != nil {
                ProjectView()
            } else {
                PortalView()
            }
        }
        // TIA Portal is a light desktop app. Forcing the light scheme keeps
        // dark text on the light panes even when the phone is in Dark Mode
        // (v1 bug: white text on white panes in Dark Mode).
        .preferredColorScheme(.light)
    }
}
