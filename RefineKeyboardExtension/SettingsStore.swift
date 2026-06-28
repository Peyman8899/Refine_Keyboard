import Foundation

struct SavedTone: Codable {
    var name: String
    var instruction: String
}

enum KeyboardSettings {
    static let appGroupID            = "group.com.peyman.RefineKeyboard"
    static let endpointKey           = "rewriteEndpoint"
    static let languageKey           = "rewriteLanguage"
    static let subscriptionActiveKey = "subscriptionActive"
    static let productionEndpoint    = "https://refinekeyboard-api.onrender.com/refine"
    static let speakEndpoint         = "https://refinekeyboard-api.onrender.com/speak"
    static let appSecret             = "rkp_f863dcf9d283f019826616eb9461bb20c258faf0"
    static let translateLanguageKey  = "translateLanguage"

    static var translateLanguage: String {
        sharedDefaults.string(forKey: translateLanguageKey) ?? "English"
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var rewriteEndpoint: String {
        let override = sharedDefaults.string(forKey: endpointKey) ?? ""
        return override.isEmpty ? productionEndpoint : override
    }

    static var rewriteLanguage: String {
        let language = sharedDefaults.string(forKey: languageKey) ?? ""
        return language.isEmpty ? "Auto" : language
    }

    static var isSubscriptionActive: Bool {
        sharedDefaults.bool(forKey: subscriptionActiveKey)
    }

    static var savedTones: [SavedTone] {
        get {
            guard let data = sharedDefaults.data(forKey: "savedTones"),
                  let tones = try? JSONDecoder().decode([SavedTone].self, from: data)
            else { return [] }
            return tones
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                sharedDefaults.set(data, forKey: "savedTones")
            }
        }
    }
}
