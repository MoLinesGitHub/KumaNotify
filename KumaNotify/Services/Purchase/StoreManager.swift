import Foundation
import StoreKit
import os

@Observable
@MainActor
final class StoreManager {
    private(set) var proUnlocked = false
    private(set) var proProduct: Product?
    private(set) var purchaseState: PurchaseState = .idle

    private var transactionListener: Task<Void, Never>?

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case purchased
        case failed(String)
    }

    init() {
        transactionListener = listenForTransactions()
        Task { await refreshStatus() }
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
                    proUnlocked = true
                    purchaseState = .purchased
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
        try? await AppStore.sync()
        await updateEntitlement()
    }

    // MARK: - Private

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [AppConstants.proProductId])
            proProduct = products.first
        } catch {
            Logger.app.error("Failed to load products: \(error.localizedDescription)")
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
        proUnlocked = found
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    if transaction.productID == AppConstants.proProductId {
                        if transaction.revocationDate != nil {
                            self?.proUnlocked = false
                        } else {
                            self?.proUnlocked = true
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
