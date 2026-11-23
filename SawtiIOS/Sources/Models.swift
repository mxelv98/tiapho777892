import Foundation

struct Voice: Identifiable, Decodable {
    var id: String
    var name: String
    var gender: String?
    var isPremium: Bool?
    var dialect: String?
    var description: String?

    var dialectLabel: String {
        switch dialect ?? "" {
        case "dz-algiers": return "العاصمة"
        case "oranian": return "وهران"
        case "setifian": return "سطيف"
        case "annabi": return "عنابة"
        case "saharan": return "الجنوب"
        default: return "الجزائر"
        }
    }
    var genderLabel: String { gender == "female" ? "أنثى" : "ذكر" }
}

struct SawtiUser: Decodable {
    var id: String
    var name: String?
    var email: String?
    var plan: String?
    var planName: String?
    var remainingTokens: Int?
    var quotaTokens: Int?
    var usedTokens: Int?
}

struct Generation: Identifiable, Decodable {
    var id: String
    var voiceId: String?
    var voiceName: String?
    var text: String?
    var audioUrl: String?
    var createdAt: String?
}
