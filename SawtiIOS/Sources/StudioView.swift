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
    private var selected: Voice? { voices.first { $0.id == selectedVoice } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("الاستوديو").font(.largeTitle.bold()).foregroundColor(.white)
                    Spacer()
                }
                .padding(.top, 8)

                // Text card
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .bottomLeading) {
                        TextEditor(text: $text)
                            .frame(height: 138)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(.white)
                        if text.isEmpty {
                            Text("اكتب النص هنا بالدارجة...")
                                .foregroundColor(.white.opacity(0.35))
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    HStack {
                        Text("\(text.count) حرف").font(.caption).foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Button {
                            Task { await improve() }
                        } label: {
                            HStack(spacing: 6) {
                                if improving { ProgressView().tint(Glass.ink).scaleEffect(0.8) }
                                Image(systemName: "wand.and.stars")
                                Text("حسّن النص").bold()
                            }
                            .font(.footnote)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(LinearGradient(colors: [Color(red: 0.20, green: 0.90, blue: 0.66), Glass.emerald], startPoint: .top, endPoint: .bottom))
                            .foregroundColor(Glass.ink)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(GlassPressStyle())
                        .disabled(improving || text.isEmpty)
                        if previousText != nil {
                            Button("تراجع") {
                                text = previousText ?? text
                                previousText = nil
                            }
                            .foregroundColor(Glass.emerald).font(.footnote.bold())
                        }
                    }
                }
                .padding(16)
                .glassCard()

                // Voice picker
                Text("الصوت").font(.headline).foregroundColor(.white)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(voices) { v in
                        Button {
                            selectedVoice = v.id
                        } label: {
                            VStack(spacing: 4) {
                                Text(v.name).bold().lineLimit(1)
                                Text("\(v.dialectLabel) • \(v.genderLabel)")
                                    .font(.caption2).foregroundColor(.white.opacity(0.55)).lineLimit(1)
                                if v.isPremium == true {
                                    Label("مميز", systemImage: "lock.fill")
                                        .font(.caption2).foregroundColor(Glass.gold)
                                }
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .glassCard(corner: 16, tint: selectedVoice == v.id ? Glass.emerald : .clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(selectedVoice == v.id ? Glass.emerald.opacity(0.8) : Color.clear, lineWidth: 1.5)
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(GlassPressStyle())
                    }
                }

                // Tone chips
                Text("النبرة").font(.headline).foregroundColor(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tones, id: \.self) { t in
                            Button(t) { tone = t }
                                .font(.footnote.bold())
                                .padding(.horizontal, 15).padding(.vertical, 9)
                                .background(
                                    Capsule().fill(tone == t
                                        ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.20, green: 0.90, blue: 0.66), Glass.emerald], startPoint: .top, endPoint: .bottom))
                                        : AnyShapeStyle(Color.white.opacity(0.07)))
                                )
                                .overlay(Capsule().strokeBorder(Glass.rim(tone == t ? 0.4 : 1), lineWidth: 1))
                                .foregroundColor(tone == t ? Glass.ink : .white)
                                .buttonStyle(GlassPressStyle())
                        }
                    }
                    .padding(.vertical, 2)
                }

                if !message.isEmpty {
                    Text(message).font(.footnote).foregroundColor(.orange)
                }

                // Generate
                Button {
                    Task { await generate() }
                } label: {
                    HStack {
                        if busy { ProgressView().tint(Glass.ink) }
                        Image(systemName: "waveform")
                        Text("توليد الصوت").font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity).padding(16)
                    .background(LinearGradient(colors: [Color(red: 0.20, green: 0.90, blue: 0.66), Glass.emerald], startPoint: .top, endPoint: .bottom))
                    .foregroundColor(Glass.ink)
                    .cornerRadius(22)
                    .shadow(color: Glass.emerald.opacity(0.45), radius: 16, y: 8)
                }
                .buttonStyle(GlassPressStyle(scale: 0.98))
                .disabled(busy || text.isEmpty || selectedVoice.isEmpty)
                .opacity(busy || text.isEmpty || selectedVoice.isEmpty ? 0.55 : 1)

                if player.currentFile != nil {
                    PlayerCard()
                }
                Spacer(minLength: 84)
            }
            .padding(16)
        }
        .task { await loadVoices() }
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
        HStack(spacing: 14) {
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3).foregroundColor(Glass.ink)
                    .frame(width: 48, height: 48)
                    .background(LinearGradient(colors: [Color(red: 0.20, green: 0.90, blue: 0.66), Glass.emerald], startPoint: .top, endPoint: .bottom))
                    .clipShape(Circle())
                    .shadow(color: Glass.emerald.opacity(0.45), radius: 10, y: 4)
            }
            .buttonStyle(GlassPressStyle())
            Slider(value: Binding(
                get: { player.progress },
                set: { player.seek(to: $0) }
            ))
            .tint(Glass.emerald)
            if let f = player.currentFile {
                ShareLink(item: f) {
                    Image(systemName: "square.and.arrow.up").foregroundColor(.white)
                }
            }
        }
        .padding(14)
        .glassPill()
    }
}
