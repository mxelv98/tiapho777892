import SwiftUI

struct AccountView: View {
    @EnvironmentObject var api: API
    @State private var user: SawtiUser?

    private var usageFraction: Double {
        guard let q = user?.quotaTokens, q > 0, let used = user?.usedTokens else { return 0 }
        return min(1, Double(used) / Double(q))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("الحساب").font(.largeTitle.bold()).foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                            .frame(width: 78, height: 78)
                            .overlay(Circle().strokeBorder(Glass.rim(), lineWidth: 1))
                        Image(systemName: "person.fill")
                            .font(.system(size: 32)).foregroundColor(Glass.emerald)
                    }
                    Text(user?.name ?? "…").font(.title3.bold()).foregroundColor(.white)
                    Text(user?.email ?? "").font(.footnote).foregroundColor(.white.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(user?.planName ?? user?.plan ?? "—", systemImage: "crown.fill")
                            .font(.headline).foregroundColor(.white)
                        Spacer()
                        Text("الباقة الحالية").font(.caption).foregroundColor(Glass.gold)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.10))
                            Capsule()
                                .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.90, blue: 0.66), Glass.emerald], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * usageFraction)
                        }
                    }
                    .frame(height: 8)
                    HStack {
                        Text("المتبقي: \(user?.remainingTokens.map { fmt($0) } ?? "—") نقطة")
                        Spacer()
                        Text("المستعمل: \(user?.usedTokens.map { fmt($0) } ?? "—")")
                    }
                    .font(.caption).foregroundColor(.white.opacity(0.65))
                }
                .padding(18)
                .glassCard(tint: Glass.emerald)

                Button("تسجيل الخروج") {
                    api.logout()
                }
                .foregroundColor(.red).font(.footnote.bold())
                .padding(.top, 4)

                Text("صوتي — نسخة تجريبية iOS 1.0")
                    .font(.caption2).foregroundColor(.white.opacity(0.35))
                Spacer(minLength: 84)
            }
            .padding(16)
        }
        .task { await load() }
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
