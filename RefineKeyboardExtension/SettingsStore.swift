import Foundation

enum KeyboardSettings {
    static let appGroupID            = "group.com.peyman.RefineKeyboard"
    static let endpointKey           = "rewriteEndpoint"
    static let languageKey           = "rewriteLanguage"
    static let subscriptionActiveKey = "subscriptionActive"
    static let productionEndpoint    = "https://refinekeyboard-api.onrender.com/refine"

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
}
