import SwiftUI

struct StudioView: View {
    @EnvironmentObject var api: API
    @EnvironmentObject var player: Player
    @State private var text = ""
    @State private var previousText: String?
    @State private var voices: [Voice] = []
    @State private var selectedVoice = ""
    @State private var tone = "عادية"
    @State private var busy = false
    @State private var improving = false
    @State private var message = ""

    private let tones = ["عادية", "هادئ", "حماسي", "مقنع", "ودي", "احترافي", "فاخر", "مستعجل", "قصصي", "عاطفي"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ZStack(alignment: .bottomLeading) {
                            TextEditor(text: $text)
                                .frame(height: 150)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(Theme.card)
                                .cornerRadius(16)
                                .foregroundColor(.white)
                            Text("\(text.count) حرف")
                                .font(.caption).foregroundColor(Theme.muted)
                                .padding(10)
                        }
                        HStack(spacing: 10) {
                            Button {
                                Task { await improve() }
                            } label: {
                                HStack {
                                    if improving { ProgressView().tint(.black) }
                                    Text("حسّن النص").bold()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(Theme.emerald).foregroundColor(.black).cornerRadius(20)
                            }
                            .disabled(improving || text.isEmpty)
                            if previousText != nil {
                                Button("تراجع") {
                                    text = previousText ?? text
                                    previousText = nil
                                }
                                .foregroundColor(Theme.emerald).font(.footnote)
                            }
                        }
                        Text("الصوت").font(.headline).foregroundColor(.white)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                            ForEach(voices) { v in
                                Button {
                                    selectedVoice = v.id
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(v.name).bold().lineLimit(1)
                                        Text("\(v.dialectLabel) • \(v.genderLabel)")
                                            .font(.caption2).foregroundColor(Theme.muted).lineLimit(1)
                                        if v.isPremium == true {
                                            Text("🔒 مميز").font(.caption2).foregroundColor(.yellow)
                                        }
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(selectedVoice == v.id ? Theme.emerald.opacity(0.25) : Theme.card)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedVoice == v.id ? Theme.emerald : Color.clear, lineWidth: 1.5))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                }
                            }
                        }
                        Text("النبرة").font(.headline).foregroundColor(.white)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tones, id: \.self) { t in
                                    Button(t) { tone = t }
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(tone == t ? Theme.emerald : Theme.card)
                                        .foregroundColor(tone == t ? .black : .white)
                                        .cornerRadius(18).font(.footnote.bold())
                                }
                            }
                        }
                        if !message.isEmpty {
                            Text(message).font(.footnote).foregroundColor(.orange)
                        }
                        Button {
                            Task { await generate() }
                        } label: {
                            HStack {
                                if busy { ProgressView().tint(.black) }
                                Text("توليد الصوت").bold()
                            }
                            .frame(maxWidth: .infinity).padding(15)
                            .background(Theme.emerald).foregroundColor(.black).cornerRadius(16)
                        }
                        .disabled(busy || text.isEmpty || selectedVoice.isEmpty)
                        if player.currentFile != nil {
                            PlayerCard()
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("الاستوديو")
            .task { await loadVoices() }
        }
    }

    private func loadVoices() async {
        let r = await api.get("/api/voices")
        if let arr = r.json?["voices"] as? [[String: Any]],
           let data = try? JSONSerialization.data(withJSONObject: arr),
           let decoded = try? JSONDecoder().decode([Voice].self, from: data) {
            voices = decoded
            if selectedVoice.isEmpty { selectedVoice = decoded.first?.id ?? "" }
        }
    }

    private func improve() async {
        improving = true
        let r = await api.post("/api/improve", ["text": text])
        improving = false
        if let improved = r.json?["text"] as? String, !improved.isEmpty {
            previousText = text
            text = improved
        } else {
            message = r.errorText
        }
    }

    private func generate() async {
        busy = true
        message = ""
        var body: [String: Any] = ["scriptText": text, "voiceId": selectedVoice]
        if tone != "عادية" { body["tone"] = tone }
        let r = await api.post("/api/tts", body, timeout: 150)
        if let gen = r.json?["generation"] as? [String: Any], let url = gen["audioUrl"] as? String {
            let audio = await api.getBytes(url)
            busy = false
            if let data = audio.data {
                player.play(data: data, name: "sawti-\(Int(Date().timeIntervalSince1970)).mp3")
            } else {
                message = audio.errorText
            }
        } else {
            busy = false
            message = r.errorText
        }
    }
}

struct PlayerCard: View {
    @EnvironmentObject var player: Player

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3).foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Theme.emerald).clipShape(Circle())
                }
                Slider(value: Binding(
                    get: { player.progress },
                    set: { player.seek(to: $0) }
                ))
                .tint(Theme.emerald)
                if let f = player.currentFile {
                    ShareLink(item: f) {
                        Image(systemName: "square.and.arrow.up").foregroundColor(.white)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(16)
    }
}
