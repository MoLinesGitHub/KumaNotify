import Foundation
import StoreKit
import os

@Observable
@MainActor
final class StoreManager {
    private(set) var proUnlocked = false

    #if DEBUG
    var debugProOverride: Bool? = nil

    var effectiveProUnlocked: Bool {
        debugProOverride ?? proUnlocked
    }
    #endif
    private(set) var proProduct: Product?
    private(set) var productLoadErrorMessage: String?
    private(set) var purchaseState: PurchaseState = .idle

    private var transactionListener: Task<Void, Never>?
    private let fetchProducts: @Sendable ([String]) async throws -> [Product]
    private let syncAppStore: @Sendable () async throws -> Void

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
        startListeningForTransactions: Bool = true,
        autoRefresh: Bool = true
    ) {
        self.fetchProducts = fetchProducts
        self.syncAppStore = syncAppStore
        if startListeningForTransactions {
            transactionListener = listenForTransactions()
        }
        if autoRefresh {
            Task { await refreshStatus() }
        }
    }

    // MARK: - Public

    func refreshStatus() async {
        await loadProduct()
        await updateEntitlement()
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
                    Logger.app.error("Unverified transaction: \(error.localizedDescription)")
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
            Logger.app.error("Purchase failed: \(error.localizedDescription)")
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func restorePurchases() async {
        do {
            try await syncAppStore()
            await updateEntitlement()
        } catch {
            Logger.app.error("Restore purchases failed: \(error.localizedDescription)")
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
            Logger.app.error("Failed to load products: \(error.localizedDescription)")
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
                Logger.app.warning("Unverified entitlement for \(transaction.productID): \(error.localizedDescription)")
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

    private func listenForTransactions() -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    if transaction.productID == AppConstants.proProductId {
                        if transaction.revocationDate != nil {
                            self?.applyEntitlementState(isEntitled: false)
                        } else {
                            self?.applyEntitlementState(isEntitled: true)
                        }
                    }
                case .unverified(let transaction, let error):
                    await transaction.finish()
                    Logger.app.warning("Unverified update for \(transaction.productID): \(error.localizedDescription)")
                }
            }
        }
    }
}
