import StoreKit
import Observation

// Product IDs must match exactly what you create in App Store Connect.
// For local testing: add a StoreKit Configuration file in Xcode
// (File > New > File > StoreKit Configuration File) with these same IDs,
// then set it in Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration.

@MainActor
@Observable
final class SubscriptionStore {

    static let monthlyID = "com.peyman.RefineKeyboard.pro.monthly"
    static let yearlyID  = "com.peyman.RefineKeyboard.pro.yearly"

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var isPurchasing = false
    var errorMessage: String?

    nonisolated(unsafe) private var transactionListener: Task<Void, Error>?

    init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshStatus() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public API

    func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else { return }
                await refreshStatus()
                await tx.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Internal

    func refreshStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productType == .autoRenewable,
               tx.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
        AppSettings.sharedDefaults.set(active, forKey: AppSettings.subscriptionActiveKey)
    }

    private func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.monthlyID, Self.yearlyID])
                .sorted { $0.price < $1.price }
        } catch {
            // Products unavailable in simulator without a StoreKit configuration file
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await self?.refreshStatus()
                    await tx.finish()
                }
            }
        }
    }
}
