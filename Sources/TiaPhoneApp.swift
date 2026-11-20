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
        if store.project != nil {
            ProjectView()
        } else {
            PortalView()
        }
    }
}
