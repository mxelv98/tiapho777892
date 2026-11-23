import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var api: API
    @EnvironmentObject var player: Player
    @State private var items: [Generation] = []
    @State private var loading = false
    @State private var playingId = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("السجل").font(.largeTitle.bold()).foregroundColor(.white)
                    .padding(.top, 8)
                if loading && items.isEmpty {
                    HStack { Spacer(); ProgressView().tint(Glass.emerald); Spacer() }
                        .padding(.top, 60)
                } else if items.isEmpty {
                    Text("ما عندك حتى توليد حتى الآن")
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 40)
                } else {
                    ForEach(items) { g in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(g.voiceName ?? g.voiceId ?? "صوت").bold().foregroundColor(.white)
                                Text(g.text ?? "")
                                    .font(.footnote).foregroundColor(.white.opacity(0.55))
                                    .lineLimit(2)
                            }
                            Spacer()
                            Button {
                                Task { await remove(g) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.footnote).foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(GlassPressStyle())
                            Button {
                                Task { await play(g) }
                            } label: {
                                Image(systemName: (player.isPlaying && playingId == g.id) ? "pause.fill" : "play.fill")
                                    .font(.body).foregroundColor(Glass.ink)
                                    .frame(width: 40, height: 40)
                                    .background(LinearGradient(colors: [Color(red: 0.20, green: 0.90, blue: 0.66), Glass.emerald], startPoint: .top, endPoint: .bottom))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(GlassPressStyle())
                        }
                        .padding(14)
                        .glassCard(corner: 18)
                    }
                }
                if player.currentFile != nil {
                    PlayerCard()
                }
                Spacer(minLength: 84)
            }
            .padding(16)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        let r = await api.get("/api/generations")
        loading = false
        if let arr = r.json?["generations"] as? [[String: Any]],
           let data = try? JSONSerialization.data(withJSONObject: arr),
           let decoded = try? JSONDecoder().decode([Generation].self, from: data) {
            items = decoded
        }
    }

    private func play(_ g: Generation) async {
        if playingId == g.id && player.currentFile != nil {
            player.toggle()
            return
        }
        guard let url = g.audioUrl else { return }
        let r = await api.getBytes(url)
        if let data = r.data {
            playingId = g.id
            player.play(data: data, name: "sawti-\(g.id).mp3")
        }
    }

    private func remove(_ g: Generation) async {
        _ = await api.delete("/api/generations/\(g.id)")
        items.removeAll { $0.id == g.id }
    }
}
