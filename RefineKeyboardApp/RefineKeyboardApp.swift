import SwiftUI

@main
struct RefineKeyboardApp: App {
    @State private var store = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
