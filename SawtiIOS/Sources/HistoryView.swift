import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var api: API
    @EnvironmentObject var player: Player
    @State private var items: [Generation] = []
    @State private var loading = false
    @State private var playingId = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack {
                    if loading && items.isEmpty {
                        Spacer()
                        ProgressView().tint(Theme.emerald)
                        Spacer()
                    } else if items.isEmpty {
                        Spacer()
                        Text("ما عندك حتى توليد حتى الآن").foregroundColor(Theme.muted)
                        Spacer()
                    } else {
                        List {
                            ForEach(items) { g in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(g.voiceName ?? g.voiceId ?? "صوت").bold().foregroundColor(.white)
                                        Spacer()
                                        Button {
                                            Task { await play(g) }
                                        } label: {
                                            Image(systemName: (player.isPlaying && playingId == g.id) ? "pause.circle.fill" : "play.circle.fill")
                                                .font(.title2).foregroundColor(Theme.emerald)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Text(g.text ?? "")
                                        .font(.footnote).foregroundColor(Theme.muted)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(Theme.card)
                            }
                            .onDelete { idx in
                                Task { await delete(at: idx) }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    if player.currentFile != nil {
                        PlayerCard().padding(12)
                    }
                }
            }
            .navigationTitle("السجل")
            .task { await load() }
            .refreshable { await load() }
        }
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

    private func delete(at offsets: IndexSet) async {
        for i in offsets {
            let g = items[i]
            _ = await api.delete("/api/generations/\(g.id)")
        }
        items.remove(atOffsets: offsets)
    }
}
