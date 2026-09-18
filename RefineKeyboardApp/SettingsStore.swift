import Foundation

enum AppSettings {
    static let appGroupID          = "group.com.peyman.RefineKeyboard"
    static let endpointKey         = "rewriteEndpoint"
    static let appSecretKey        = "stagingAppSecret"
    static let languageKey         = "rewriteLanguage"
    static let subscriptionActiveKey = "subscriptionActive"
    static let productionEndpoint  = "https://refinekeyboard-api.onrender.com/refine"
    static let stagingEndpoint     = "https://refinekeyboard-api-staging.onrender.com/refine"

    static var defaultEndpoint: String {
#if DEBUG
        stagingEndpoint
#else
        productionEndpoint
#endif
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var rewriteEndpoint: String {
#if DEBUG
        let override = sharedDefaults.string(forKey: endpointKey) ?? ""
        return override.isEmpty ? defaultEndpoint : override
#else
        productionEndpoint
#endif
    }

    static var isSubscriptionActive: Bool {
        sharedDefaults.bool(forKey: subscriptionActiveKey)
    }
}
