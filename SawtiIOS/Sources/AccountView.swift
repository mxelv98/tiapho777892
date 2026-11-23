import SwiftUI

struct AccountView: View {
    @EnvironmentObject var api: API
    @State private var user: SawtiUser?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 56)).foregroundColor(Theme.emerald)
                        Text(user?.name ?? "…").font(.title3.bold()).foregroundColor(.white)
                        Text(user?.email ?? "").font(.footnote).foregroundColor(Theme.muted)
                    }
                    .padding(.top, 24)
                    VStack(spacing: 0) {
                        row(label: "الباقة", value: user?.planName ?? user?.plan ?? "—")
                        Divider().background(Color.white.opacity(0.08))
                        row(label: "الرصيد المتبقي", value: user?.remainingTokens.map { "\(fmt($0)) نقطة" } ?? "—")
                        Divider().background(Color.white.opacity(0.08))
                        row(label: "المستعمل", value: user?.usedTokens.map { "\(fmt($0)) نقطة" } ?? "—")
                    }
                    .background(Theme.card).cornerRadius(16)
                    .padding(.horizontal, 16)
                    Button("تسجيل الخروج") {
                        api.logout()
                    }
                    .foregroundColor(.red).font(.footnote.bold())
                    .padding(.top, 8)
                    Spacer()
                    Text("صوتي — نسخة تجريبية iOS 1.0")
                        .font(.caption2).foregroundColor(Theme.muted)
                }
            }
            .navigationTitle("الحساب")
            .task { await load() }
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(Theme.muted)
            Spacer()
            Text(value).foregroundColor(.white).bold()
        }
        .padding(14)
    }

    private func fmt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func load() async {
        let r = await api.get("/api/me")
        if let u = r.json?["user"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: u),
           let decoded = try? JSONDecoder().decode(SawtiUser.self, from: data) {
            user = decoded
        }
    }
}
