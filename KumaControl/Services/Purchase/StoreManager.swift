import Foundation
import StoreKit

@Observable
@MainActor
final class StoreManager {
    private(set) var proUnlocked = false

    #if DEBUG
    var debugProOverride: Bool?

    var effectiveProUnlocked: Bool {
        debugProOverride ?? proUnlocked
    }
    #endif
    private(set) var proProduct: Product?
    private(set) var productLoadErrorMessage: String?
    private(set) var purchaseState: PurchaseState = .idle

    @ObservationIgnored
    nonisolated(unsafe) private var transactionListener: Task<Void, Never>?
    private let fetchProducts: @Sendable ([String]) async throws -> [Product]
    private let syncAppStore: @Sendable () async throws -> Void
    private let transactionListenerFactory: @MainActor @Sendable (StoreManager) -> Task<Void, Never>

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case purchased
        case failed(String)
    }

    init(
        fetchProducts: @escaping @Sendable ([String]) async throws -> [Product] = { ids in
            try await Product.products(for: ids)
        },
        syncAppStore: @escaping @Sendable () async throws -> Void = {
            try await AppStore.sync()
        },
        transactionListenerFactory: @escaping @MainActor @Sendable (StoreManager) -> Task<Void, Never>,
        startListeningForTransactions: Bool = true,
        autoRefresh: Bool = true
    ) {
        self.fetchProducts = fetchProducts
        self.syncAppStore = syncAppStore
        self.transactionListenerFactory = transactionListenerFactory
        if startListeningForTransactions {
            transactionListener = transactionListenerFactory(self)
        }
        if autoRefresh {
            Task { await refreshStatus() }
        }
    }

    convenience init(
        fetchProducts: @escaping @Sendable ([String]) async throws -> [Product] = { ids in
            try await Product.products(for: ids)
        },
        syncAppStore: @escaping @Sendable () async throws -> Void = {
            try await AppStore.sync()
        },
        startListeningForTransactions: Bool = true,
        autoRefresh: Bool = true
    ) {
        self.init(
            fetchProducts: fetchProducts,
            syncAppStore: syncAppStore,
            transactionListenerFactory: { manager in StoreManager.makeDefaultTransactionListener(for: manager) },
            startListeningForTransactions: startListeningForTransactions,
            autoRefresh: autoRefresh
        )
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public

    func refreshStatus() async {
        await loadProduct()
        await updateEntitlement()
        clearRecoveredFailureStateIfNeeded()
    }

    func purchasePro() async {
        guard let product = proProduct else { return }
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    applyEntitlementState(isEntitled: true)
                case .unverified(let transaction, let error):
                    await transaction.finish()
                    print("Purchase: Unverified transaction: \(error.localizedDescription)")
                    purchaseState = .failed(error.localizedDescription)
                    await updateEntitlement()
                }
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            print("Purchase: Purchase failed: \(error.localizedDescription)")
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func restorePurchases() async {
        do {
            try await syncAppStore()
            await updateEntitlement()
            clearRecoveredFailureStateIfNeeded()
        } catch {
            print("Purchase: Restore purchases failed: \(error.localizedDescription)")
            purchaseState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func loadProduct() async {
        do {
            let products = try await fetchProducts([AppConstants.proProductId])
            proProduct = products.first
            productLoadErrorMessage = nil
        } catch {
            print("Purchase: Failed to load products: \(error.localizedDescription)")
            proProduct = nil
            productLoadErrorMessage = error.localizedDescription
        }
    }

    private func updateEntitlement() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == AppConstants.proProductId {
                    found = true
                }
            case .unverified(let transaction, let error):
                print("Purchase: Unverified entitlement for \(transaction.productID): \(error.localizedDescription)")
            }
        }
        applyEntitlementState(isEntitled: found)
    }

    func applyEntitlementState(isEntitled: Bool) {
        proUnlocked = isEntitled
        if isEntitled {
            purchaseState = .purchased
        } else if purchaseState == .purchased {
            purchaseState = .idle
        }
    }

    private func clearRecoveredFailureStateIfNeeded() {
        guard case .failed = purchaseState else { return }
        guard productLoadErrorMessage == nil, !proUnlocked else { return }
        purchaseState = .idle
    }

    private static func makeDefaultTransactionListener(for manager: StoreManager) -> Task<Void, Never> {
        Task { @MainActor [weak manager] in
            for await result in Transaction.updates {
                guard let manager else { return }
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    if transaction.productID == AppConstants.proProductId {
                        if transaction.revocationDate != nil {
                            manager.applyEntitlementState(isEntitled: false)
                        } else {
                            manager.applyEntitlementState(isEntitled: true)
                        }
                    }
                case .unverified(let transaction, let error):
                    await transaction.finish()
                    print("Purchase: Unverified update for \(transaction.productID): \(error.localizedDescription)")
                }
            }
        }
    }
}
