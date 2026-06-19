import SwiftUI

struct HomeView: View {
    @Environment(SubscriptionStore.self) private var store
    @State private var showPaywall = false
    @State private var showDeveloperSettings = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var endpointOverride: String = AppSettings.sharedDefaults.string(forKey: AppSettings.endpointKey) ?? ""

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                setupSection
                featuresSection
                settingsSection
                developerSection
            }
            .navigationTitle("RefineKeyboard")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(store)
            }
        }
    }

    // MARK: - Sections

    private var subscriptionSection: some View {
        Section {
            if store.isSubscribed {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pro Active")
                            .font(.headline)
                        Text("All AI features unlocked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Manage") {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to Pro")
                            .font(.headline)
                        Text("Unlock unlimited AI rewrites")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("View Plans") {
                        showPaywall = true
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Subscription")
        }
    }

    private var setupSection: some View {
        Section {
            SetupStep(
                number: "1",
                title: "Add RefineKeyboard",
                subtitle: "Settings → General → Keyboard → Keyboards",
                symbol: "plus.circle.fill",
                color: .blue
            )
            Button {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            } label: {
                Label("Open Settings", systemImage: "arrow.up.right")
                    .font(.subheadline)
            }

            SetupStep(
                number: "2",
                title: "Enable Full Access",
                subtitle: "Tap RefineKeyboard → Allow Full Access → On",
                symbol: "lock.open.fill",
                color: .green
            )
        } header: {
            Text("Keyboard Setup")
        } footer: {
            Text("Full Access is required for the keyboard to reach the AI. We never log your keystrokes.")
        }
    }

    private var featuresSection: some View {
        Section("AI Rewrite Modes") {
            FeatureItem(icon: "sparkles",        color: .blue,   name: "Refine",       detail: "Fix grammar, spelling and clarity")
            FeatureItem(icon: "heart.fill",      color: .pink,   name: "Warm",         detail: "Make messages friendlier and kinder")
            FeatureItem(icon: "briefcase.fill",  color: .indigo, name: "Professional", detail: "Clear, polished, workplace-ready")
            FeatureItem(icon: "text.alignleft",  color: .orange, name: "Short",        detail: "Concise without losing meaning")
        }
    }

    private var settingsSection: some View {
        Section("Settings") {
            NavigationLink {
                LanguageSettingsView()
            } label: {
                Label("Output Language", systemImage: "globe")
            }

            Link(destination: URL(string: "https://peyman8899.github.io/Refine_Keyboard/privacy.html")!) {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }

            Button {
                showDeveloperSettings.toggle()
            } label: {
                Label("Developer Settings", systemImage: "hammer.fill")
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var developerSection: some View {
        if showDeveloperSettings {
            Section {
                TextField(AppSettings.productionEndpoint, text: $endpointOverride)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())

                HStack {
                    Button("Save") {
                        AppSettings.sharedDefaults.set(
                            endpointOverride.trimmingCharacters(in: .whitespacesAndNewlines),
                            forKey: AppSettings.endpointKey
                        )
                    }
                    Spacer()
                    Button("Reset", role: .destructive) {
                        endpointOverride = ""
                        AppSettings.sharedDefaults.removeObject(forKey: AppSettings.endpointKey)
                    }
                }
            } header: {
                Text("API Endpoint Override")
            } footer: {
                Text("Leave blank to use the production endpoint.")
            }
        }
    }
}

// MARK: - Supporting Views

private struct SetupStep: View {
    let number: String
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct FeatureItem: View {
    let icon: String
    let color: Color
    let name: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.body)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Language Settings

private struct LanguageSettingsView: View {
    private let languages = ["Auto", "English", "Spanish", "French", "German", "Italian",
                             "Portuguese", "Dutch", "Swedish", "Norwegian", "Danish", "Finnish",
                             "Polish", "Czech", "Hungarian", "Romanian", "Greek", "Turkish",
                             "Russian", "Ukrainian", "Hebrew", "Arabic", "Persian", "Hindi",
                             "Chinese Simplified", "Chinese Traditional", "Japanese", "Korean",
                             "Vietnamese", "Thai", "Indonesian", "Filipino"]

    @State private var selected: String = AppSettings.sharedDefaults.string(forKey: AppSettings.languageKey) ?? "Auto"

    var body: some View {
        List(languages, id: \.self) { lang in
            Button {
                selected = lang
                AppSettings.sharedDefaults.set(lang == "Auto" ? nil : lang, forKey: AppSettings.languageKey)
            } label: {
                HStack {
                    Text(lang).foregroundStyle(Color.primary)
                    Spacer()
                    if lang == selected {
                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .navigationTitle("Output Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}
