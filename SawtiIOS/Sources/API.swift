import Foundation

/// Minimal client for the Sawti API. Tries sawti.online first; on a network-level
/// failure (DNS block, unreachable host) falls back to the mirror domain and sticks
/// to whichever base answered, mirroring the Android app's behaviour.
final class API: ObservableObject {
    static let shared = API()
    private let bases = ["https://sawti.online", "https://sawtdz.basatbelaifa7.workers.dev"]
    private var activeBase = 0

    @Published var token: String = UserDefaults.standard.string(forKey: "sawti_token") ?? "" {
        didSet { UserDefaults.standard.set(token, forKey: "sawti_token") }
    }
    var isLoggedIn: Bool { !token.isEmpty }
    func logout() { token = "" }

    struct Reply {
        var status: Int
        var json: [String: Any]?
        var data: Data?
        var errorText: String {
            if let e = json?["error"] as? String, !e.isEmpty { return e }
            if status == -1 { return "تعذّر الاتصال بالخادم" }
            return "خطأ \(status)"
        }
    }

    private func once(base: String, method: String, path: String, body: [String: Any]?, binary: Bool, timeout: TimeInterval) async -> Reply {
        guard let url = URL(string: base + path) else { return Reply(status: -1, json: nil, data: nil) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = timeout
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if !token.isEmpty { req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let body = body {
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if binary && (200..<300).contains(status) {
                return Reply(status: status, json: nil, data: data)
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            return Reply(status: status, json: json, data: nil)
        } catch {
            return Reply(status: -1, json: nil, data: nil)
        }
    }

    private func request(method: String, path: String, body: [String: Any]? = nil, binary: Bool = false, timeout: TimeInterval = 30) async -> Reply {
        let first = activeBase
        let r = await once(base: bases[first], method: method, path: path, body: body, binary: binary, timeout: timeout)
        if r.status == -1 {
            let second = 1 - first
            let r2 = await once(base: bases[second], method: method, path: path, body: body, binary: binary, timeout: timeout)
            if r2.status != -1 {
                activeBase = second
                return r2
            }
        }
        return r
    }

    func post(_ path: String, _ body: [String: Any], timeout: TimeInterval = 30) async -> Reply {
        await request(method: "POST", path: path, body: body, timeout: timeout)
    }
    func get(_ path: String) async -> Reply { await request(method: "GET", path: path) }
    func getBytes(_ path: String) async -> Reply { await request(method: "GET", path: path, binary: true, timeout: 60) }
    func delete(_ path: String) async -> Reply { await request(method: "DELETE", path: path) }
}
