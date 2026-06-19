import SwiftUI

struct OnboardingView: View {
    @Environment(SubscriptionStore.self) private var store
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var page = 0
    @State private var showPaywall = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $page) {
                OnboardingPage(
                    symbol: "keyboard.fill",
                    color: .blue,
                    title: "Your AI Keyboard",
                    description: "RefineKeyboard sits right in your keyboard — tap Refine, Warm, Professional, or Short to instantly rewrite any message with AI."
                ).tag(0)

                OnboardingPage(
                    symbol: "gearshape.fill",
                    color: .orange,
                    title: "Add the Keyboard",
                    description: "Go to Settings → General → Keyboard → Keyboards → Add New Keyboard and select RefineKeyboard.",
                    actionLabel: "Open Settings",
                    action: { openSettings() }
                ).tag(1)

                OnboardingPage(
                    symbol: "lock.open.fill",
                    color: .green,
                    title: "Enable Full Access",
                    description: "Tap RefineKeyboard in your Keyboards list and turn on Allow Full Access. This lets the keyboard reach the AI — we never log what you type."
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == page ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: i == page ? 20 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: page)
                    }
                }

                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Text(page < 2 ? "Continue" : "Choose a Plan")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)

                if page == 2 {
                    Button("Skip for now") {
                        hasCompletedOnboarding = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(onComplete: { hasCompletedOnboarding = true })
                .environment(store)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Single page template

private struct OnboardingPage: View {
    let symbol: String
    let color: Color
    let title: String
    let description: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: symbol)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(color)
            }
            .padding(.bottom, 36)

            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let label = actionLabel, let action {
                Button(action: action) {
                    Label(label, systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .padding(.top, 28)
            }

            Spacer()
            Spacer()
        }
    }
}
