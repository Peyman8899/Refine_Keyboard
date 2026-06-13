import SwiftUI

struct ContentView: View {
    @State private var endpointOverride: String = AppSettings.sharedDefaults.string(forKey: AppSettings.endpointKey) ?? ""
    @State private var showDeveloperSettings = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Install Keyboard") {
                    Text("Open Settings, add RefineKeyboard under Keyboards, then enable Allow Full Access so the keyboard can call your rewrite backend.")
                    Text("The keyboard sends text only when you tap Refine.")
                }

                Section("Rewrite Modes") {
                    Label("Polish grammar and clarity", systemImage: "sparkles")
                    Label("Make text warmer", systemImage: "heart")
                    Label("Make text more professional", systemImage: "briefcase")
                    Label("Shorten while preserving meaning", systemImage: "text.alignleft")
                }

                Section("Service") {
                    Text("Ready to refine messages once the keyboard is enabled.")
                    Button(showDeveloperSettings ? "Hide Developer Settings" : "Developer Settings") {
                        showDeveloperSettings.toggle()
                    }
                }

                if showDeveloperSettings {
                    Section("Developer Override") {
                        TextField(AppSettings.productionEndpoint, text: $endpointOverride)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()

                        Button("Save Override") {
                            AppSettings.sharedDefaults.set(endpointOverride.trimmingCharacters(in: .whitespacesAndNewlines), forKey: AppSettings.endpointKey)
                        }

                        Button("Use Production Endpoint") {
                            endpointOverride = ""
                            AppSettings.sharedDefaults.removeObject(forKey: AppSettings.endpointKey)
                        }
                    }
                }
            }
            .navigationTitle("RefineKeyboard")
        }
    }
}
