import Foundation

struct SavedTone: Codable {
    var name: String
    var instruction: String
}

enum KeyboardSettings {
    static let appGroupID            = "group.com.peyman.RefineKeyboard"
    static let endpointKey           = "rewriteEndpoint"
    static let appSecretKey          = "stagingAppSecret"
    static let languageKey           = "rewriteLanguage"
    static let subscriptionActiveKey = "subscriptionActive"
    static let freeUsageCountKey     = "freeAIUsageCount"
    static let freeUsageLimit        = 5
    static let productionEndpoint    = "https://refinekeyboard-api.onrender.com/refine"
    static let stagingEndpoint       = "https://refinekeyboard-api-staging.onrender.com/refine"
    static let productionSpeakEndpoint = "https://refinekeyboard-api.onrender.com/speak"
    static let stagingSpeakEndpoint  = "https://refinekeyboard-api-staging.onrender.com/speak"
    static let productionAppSecret   = "rkp_f863dcf9d283f019826616eb9461bb20c258faf0"
    static let translateLanguageKey  = "translateLanguage"

    static var translateLanguage: String {
        sharedDefaults.string(forKey: translateLanguageKey) ?? "English"
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var rewriteEndpoint: String {
#if DEBUG
        let override = sharedDefaults.string(forKey: endpointKey) ?? ""
        return override.isEmpty ? stagingEndpoint : override
#else
        productionEndpoint
#endif
    }

    static var speakEndpoint: String {
#if DEBUG
        let rewriteURL = rewriteEndpoint
        if rewriteURL.hasSuffix("/refine") {
            return String(rewriteURL.dropLast("/refine".count)) + "/speak"
        }
        return stagingSpeakEndpoint
#else
        productionSpeakEndpoint
#endif
    }

    static var appSecret: String {
#if DEBUG
        let stagingSecret = sharedDefaults.string(forKey: appSecretKey) ?? ""
        return stagingSecret
#else
        productionAppSecret
#endif
    }

    static var rewriteLanguage: String {
        let language = sharedDefaults.string(forKey: languageKey) ?? ""
        return language.isEmpty ? "Auto" : language
    }

    static var isSubscriptionActive: Bool {
        sharedDefaults.bool(forKey: subscriptionActiveKey)
    }

    static var freeUsesRemaining: Int {
        let used = sharedDefaults.integer(forKey: freeUsageCountKey)
        return max(0, freeUsageLimit - used)
    }

    static var canUseAI: Bool {
        isSubscriptionActive || freeUsesRemaining > 0
    }

    static func consumeFreeUse() {
        guard !isSubscriptionActive else { return }
        let used = sharedDefaults.integer(forKey: freeUsageCountKey)
        sharedDefaults.set(used + 1, forKey: freeUsageCountKey)
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
