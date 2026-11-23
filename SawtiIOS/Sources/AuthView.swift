import SwiftUI

struct AuthView: View {
    @EnvironmentObject var api: API
    @State private var registerMode = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error = ""

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 20) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.90, blue: 0.66), Glass.emerald], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 76, height: 76)
                        .shadow(color: Glass.emerald.opacity(0.5), radius: 18, y: 8)
                    Image(systemName: "waveform")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Glass.ink)
                }
                Text("صوتي")
                    .font(.system(size: 40, weight: .black))
                    .foregroundColor(.white)
                Text("حوّل النص إلى تعليق صوتي بالدارجة الجزائرية")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))

                VStack(spacing: 14) {
                    HStack(spacing: 4) {
                        segButton("تسجيل الدخول", active: !registerMode) { registerMode = false; error = "" }
                        segButton("حساب جديد", active: registerMode) { registerMode = true; error = "" }
                    }
                    .padding(4)
                    .glassPill()

                    if registerMode {
                        field("الاسم", text: $name)
                    }
                    field("البريد الإلكتروني", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("كلمة السر", text: $password)
                        .padding(14)
                        .glassCard(corner: 16)
                        .foregroundColor(.white)

                    if !error.isEmpty {
                        Text(error).foregroundColor(.red).font(.footnote)
                    }
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if busy { ProgressView().tint(Glass.ink) }
                            Text(registerMode ? "إنشاء حساب" : "تسجيل الدخول").bold()
                        }
                        .frame(maxWidth: .infinity).padding(15)
                        .background(LinearGradient(colors: [Color(red: 0.20, green: 0.90, blue: 0.66), Glass.emerald], startPoint: .top, endPoint: .bottom))
                        .foregroundColor(Glass.ink)
                        .cornerRadius(18)
                        .shadow(color: Glass.emerald.opacity(0.4), radius: 14, y: 6)
                    }
                    .buttonStyle(GlassPressStyle())
                    .disabled(busy)
                }
                .padding(20)
                .glassCard(corner: 28)
                .padding(.horizontal, 20)
                Spacer()
            }
        }
    }

    private func segButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.footnote.bold())
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(Capsule().fill(active ? Color.white.opacity(0.85) : Color.clear))
                .foregroundColor(active ? .black : .white.opacity(0.7))
        }
        .buttonStyle(GlassPressStyle())
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(14)
            .glassCard(corner: 16)
            .foregroundColor(.white)
    }

    private func submit() async {
        busy = true
        error = ""
        var body: [String: Any] = ["email": email.trimmingCharacters(in: .whitespaces), "password": password]
        if registerMode { body["name"] = name }
        let r = await api.post(registerMode ? "/api/auth/register" : "/api/auth/login", body)
        busy = false
        if let tok = r.json?["token"] as? String, !tok.isEmpty {
            api.token = tok
        } else {
            error = r.errorText
        }
    }
}
