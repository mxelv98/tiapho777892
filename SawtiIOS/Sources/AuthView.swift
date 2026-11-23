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
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Text("صوتي")
                    .font(.system(size: 44, weight: .black))
                    .foregroundColor(.white)
                Text("حوّل النص إلى تعليق صوتي بالدارجة الجزائرية")
                    .font(.subheadline)
                    .foregroundColor(Theme.muted)
                VStack(spacing: 12) {
                    if registerMode {
                        TextField("الاسم", text: $name)
                            .textFieldStyle(.plain).padding(12)
                            .background(Theme.card).cornerRadius(12)
                    }
                    TextField("البريد الإلكتروني", text: $email)
                        .textFieldStyle(.plain).padding(12)
                        .background(Theme.card).cornerRadius(12)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("كلمة السر", text: $password)
                        .textFieldStyle(.plain).padding(12)
                        .background(Theme.card).cornerRadius(12)
                }
                .foregroundColor(.white)
                if !error.isEmpty {
                    Text(error).foregroundColor(.red).font(.footnote)
                }
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if busy { ProgressView().tint(.black) }
                        Text(registerMode ? "إنشاء حساب" : "تسجيل الدخول").bold()
                    }
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Theme.emerald).foregroundColor(.black)
                    .cornerRadius(14)
                }
                .disabled(busy)
                Button(registerMode ? "عندك حساب؟ سجّل الدخول" : "ما عندكش حساب؟ أنشئ واحد") {
                    registerMode.toggle()
                    error = ""
                }
                .foregroundColor(Theme.emerald).font(.footnote)
                Spacer()
            }
            .padding(24)
        }
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
