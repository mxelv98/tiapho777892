import SwiftUI

@main
struct SawtiApp: App {
    @StateObject private var api = API.shared
    @StateObject private var player = Player()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(api)
                .environmentObject(player)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var api: API

    var body: some View {
        if api.isLoggedIn {
            TabView {
                StudioView()
                    .tabItem { Label("الاستوديو", systemImage: "waveform") }
                HistoryView()
                    .tabItem { Label("السجل", systemImage: "clock.arrow.circlepath") }
                AccountView()
                    .tabItem { Label("الحساب", systemImage: "person.circle") }
            }
            .tint(Color(red: 0.06, green: 0.72, blue: 0.51))
        } else {
            AuthView()
        }
    }
}

enum Theme {
    static let bg = Color(red: 0.086, green: 0.075, blue: 0.059)
    static let card = Color(red: 0.13, green: 0.115, blue: 0.09)
    static let emerald = Color(red: 0.06, green: 0.72, blue: 0.51)
    static let muted = Color.white.opacity(0.55)
}
