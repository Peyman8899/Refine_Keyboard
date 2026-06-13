import Foundation

enum AppSettings {
    static let appGroupID = "group.com.peyman.RefineKeyboard"
    static let endpointKey = "rewriteEndpoint"
    static let productionEndpoint = "https://api.refinekeyboard.app/refine"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var rewriteEndpoint: String {
        let override = sharedDefaults.string(forKey: endpointKey) ?? ""
        return override.isEmpty ? productionEndpoint : override
    }
}
