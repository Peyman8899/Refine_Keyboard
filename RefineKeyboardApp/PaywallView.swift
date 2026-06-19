import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onComplete: (() -> Void)? = nil

    @State private var selectedProductID = SubscriptionStore.yearlyID

    private var monthly: Product? { store.products.first { $0.id == SubscriptionStore.monthlyID } }
    private var yearly:  Product? { store.products.first { $0.id == SubscriptionStore.yearlyID  } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 8)
                        .padding(.bottom, 32)

                    features
                        .padding(.bottom, 32)

                    pricingCards
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    subscribeButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    restoreButton
                    legalText
                        .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
            .navigationTitle("RefineKeyboard Pro")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: store.isSubscribed) { _, active in
            if active { onComplete?(); dismiss() }
        }
        .alert("Something went wrong", isPresented: .constant(store.errorMessage != nil)) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Text("Upgrade to Pro")
                .font(.title.bold())
            Text("Unlimited AI rewrites in every app")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 14) {
            FeatureRow(symbol: "sparkles",     color: .blue,   text: "Unlimited Polish, Warm, Professional & Short rewrites")
            FeatureRow(symbol: "globe",        color: .green,  text: "Translate to 70+ languages directly from your keyboard")
            FeatureRow(symbol: "bolt.fill",    color: .orange, text: "Instant results powered by the latest AI models")
            FeatureRow(symbol: "lock.fill",    color: .purple, text: "Privacy-first — text is never stored or logged")
        }
        .padding(.horizontal, 28)
    }

    private var pricingCards: some View {
        VStack(spacing: 12) {
            if let product = yearly {
                PricingCard(
                    product: product,
                    badge: "Best Value",
                    subtitle: monthlyEquivalent(for: product),
                    isSelected: selectedProductID == product.id
                ) { selectedProductID = product.id }
            } else {
                PricingCard(
                    fallbackTitle: "Yearly",
                    fallbackPrice: "$19.99 / year",
                    badge: "Best Value",
                    subtitle: "Only $1.67 / month",
                    isSelected: selectedProductID == SubscriptionStore.yearlyID
                ) { selectedProductID = SubscriptionStore.yearlyID }
            }

            if let product = monthly {
                PricingCard(
                    product: product,
                    isSelected: selectedProductID == product.id
                ) { selectedProductID = product.id }
            } else {
                PricingCard(
                    fallbackTitle: "Monthly",
                    fallbackPrice: "$2.99 / month",
                    isSelected: selectedProductID == SubscriptionStore.monthlyID
                ) { selectedProductID = SubscriptionStore.monthlyID }
            }
        }
    }

    private var subscribeButton: some View {
        Button {
            Task {
                let target = store.products.first { $0.id == selectedProductID }
                if let product = target {
                    await store.purchase(product)
                }
            }
        } label: {
            Group {
                if store.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Subscribe Now")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(store.isPurchasing)
    }

    private var restoreButton: some View {
        Button {
            Task { await store.restore() }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private var legalText: some View {
        Text("Subscription renews automatically. Cancel anytime in your Apple ID settings. By subscribing you agree to our Terms of Service and Privacy Policy.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func monthlyEquivalent(for product: Product) -> String {
        let monthly = product.price / 12
        return "\(product.priceFormatStyle.format(monthly)) / month"
    }
}

// MARK: - Supporting views

private struct FeatureRow: View {
    let symbol: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct PricingCard: View {
    var product: Product? = nil
    var fallbackTitle: String = ""
    var fallbackPrice: String = ""
    var badge: String? = nil
    var subtitle: String? = nil
    let isSelected: Bool
    let onSelect: () -> Void

    private var title: String {
        product?.displayName ?? fallbackTitle
    }
    private var price: String {
        product?.displayPrice.appending(subscriptionSuffix ?? "") ?? fallbackPrice
    }
    private var subscriptionSuffix: String? {
        guard let period = product?.subscription?.subscriptionPeriod else { return nil }
        switch period.unit {
        case .month: return " / month"
        case .year:  return " / year"
        default:     return nil
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(price)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? Color.accentColor.opacity(0.06) : Color(.secondarySystemGroupedBackground))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
