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
    @State private var tab = 0

    private let tabs: [(title: String, icon: String)] = [
        ("الاستوديو", "waveform"),
        ("السجل", "clock.arrow.circlepath"),
        ("الحساب", "person.circle")
    ]

    var body: some View {
        if api.isLoggedIn {
            ZStack(alignment: .bottom) {
                AuroraBackground()
                Group {
                    switch tab {
                    case 0: StudioView()
                    case 1: HistoryView()
                    default: AccountView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Floating Liquid Glass tab bar
                HStack(spacing: 4) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { tab = i }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tabs[i].icon)
                                if tab == i {
                                    Text(tabs[i].title).font(.footnote.bold())
                                }
                            }
                            .foregroundColor(tab == i ? Glass.ink : .white.opacity(0.75))
                            .padding(.horizontal, tab == i ? 16 : 13)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(tab == i ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.20, green: 0.90, blue: 0.66), Glass.emerald], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.clear))
                                    .shadow(color: tab == i ? Glass.emerald.opacity(0.45) : .clear, radius: 10, y: 4)
                            )
                        }
                        .buttonStyle(GlassPressStyle())
                    }
                }
                .padding(6)
                .glassPill()
                .padding(.bottom, 10)
            }
        } else {
            AuthView()
        }
    }
}
