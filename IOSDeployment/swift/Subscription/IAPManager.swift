// IAPManager.swift
// StoreKit 2 — Apple In-App Purchase manager for BoAnalyst
//
// PRODUCTS (must match App Store Connect exactly):
//   com.boanalyst.app.pro.monthly      — Auto-Renewable, ₹399/month
//   com.boanalyst.app.pro.yearly       — Auto-Renewable, ₹3,999/year
//   com.boanalyst.app.distributor.yearly — Auto-Renewable, ₹24,999/year
//
// All three products live in the SAME subscription group "BoAnalyst Pro"
// so a user can only hold one active subscription at a time.
//
// Apple Small Business Program (enrolled via developer.apple.com):
//   Reduces Apple's commission 30% → 15%.
//   BoAnalyst earns 85% of each transaction.

import StoreKit
import Foundation

// MARK: - Product IDs

enum IAPProduct: String, CaseIterable {
    case proMonthly       = "com.boanalyst.app.pro.monthly"
    case proYearly        = "com.boanalyst.app.pro.yearly"
    case distributorYearly = "com.boanalyst.app.distributor.yearly"

    var displayName: String {
        switch self {
        case .proMonthly:        return "Pro Monthly"
        case .proYearly:         return "Pro Yearly"
        case .distributorYearly: return "Distributors Hub"
        }
    }

    var badge: String {
        switch self {
        case .proMonthly:        return "STARTER"
        case .proYearly:         return "⭐ BEST VALUE"
        case .distributorYearly: return "🎬 DISTRIBUTORS"
        }
    }

    var fallbackPrice: String {
        switch self {
        case .proMonthly:        return "₹499"
        case .proYearly:         return "₹1,399"
        case .distributorYearly: return "₹24,999"
        }
    }

    var period: String {
        switch self {
        case .proMonthly:        return "per month"
        case .proYearly:         return "per year"
        case .distributorYearly: return "per year"
        }
    }

    var isDistributorPlan: Bool { self == .distributorYearly }
    var isProPlan: Bool        { self == .proMonthly || self == .proYearly }
}

// MARK: - Purchase Result

enum PurchaseResult {
    case success(Transaction)
    case pending
    case cancelled
    case failed(Error)
}

// MARK: - IAPManager

@MainActor
final class IAPManager: ObservableObject {

    static let shared = IAPManager()

    // MARK: - Published State

    @Published var products: [Product] = []
    @Published var isProActive: Bool = false
    @Published var isDistributorActive: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var errorMessage: String? = nil
    @Published var activeTransaction: Transaction? = nil

    private var transactionUpdateTask: Task<Void, Never>? = nil
    private let api = APIClient.shared

    // MARK: - Init

    private init() {
        transactionUpdateTask = Task.detached(priority: .background) { [weak self] in
            await self?.listenForTransactionUpdates()
        }
    }

    deinit { transactionUpdateTask?.cancel() }

    // MARK: - Load Products from App Store

    func loadProducts() async {
        do {
            let ids = IAPProduct.allCases.map { $0.rawValue }
            let fetched = try await Product.products(for: ids)
            // Sort: monthly first, yearly second, distributor third
            self.products = fetched.sorted { a, b in
                let order: [String] = [
                    IAPProduct.proMonthly.rawValue,
                    IAPProduct.proYearly.rawValue,
                    IAPProduct.distributorYearly.rawValue
                ]
                let ai = order.firstIndex(of: a.id) ?? 99
                let bi = order.firstIndex(of: b.id) ?? 99
                return ai < bi
            }
        } catch {
            self.errorMessage = "Unable to load subscription options. Please check your connection."
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async -> PurchaseResult {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await notifyBackend(transaction: transaction)
                    await transaction.finish()
                    activeTransaction = transaction
                    updateProStatus(for: transaction)
                    return .success(transaction)
                case .unverified(_, let error):
                    return .failed(error)
                }
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            self.errorMessage = "Purchase failed. Please try again."
            return .failed(error)
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            // After restore, notify backend if there's an active transaction
            if let tx = activeTransaction {
                await notifyBackend(transaction: tx)
            }
        } catch {
            self.errorMessage = "Restore failed. Please try again or contact support."
        }
    }

    // MARK: - Refresh Subscription Status
    // Call on app launch and after sign-in to sync Pro/Distributor badge.

    func refreshSubscriptionStatus() async {
        var hasPro = false
        var hasDistributor = false
        var latestTransaction: Transaction? = nil

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil {
                switch transaction.productID {
                case IAPProduct.proMonthly.rawValue,
                     IAPProduct.proYearly.rawValue:
                    hasPro = true
                    latestTransaction = transaction
                case IAPProduct.distributorYearly.rawValue:
                    hasDistributor = true
                    hasPro = true // distributor also gets pro features
                    latestTransaction = transaction
                default:
                    break
                }
            }
        }

        isProActive = hasPro
        isDistributorActive = hasDistributor
        activeTransaction = latestTransaction

        // Do NOT call notifyBackend on every refresh — only after actual purchases.
        // Calling it here caused new accounts to get auto-activated because StoreKit
        // has old transactions from previous accounts. The backend is the source of truth;
        // notifyBackend is only called in purchase() and restorePurchases().
    }

    // MARK: - Notify Backend

    private func notifyBackend(transaction: Transaction) async {
        guard let endpoint = try? APIEndpoint.verifyAppleReceipt(
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            productId: transaction.productID,
            expiresDate: transaction.expirationDate
        ) else { return }
        _ = try? await api.requestRaw(endpoint)
    }

    // MARK: - Private: Update local Pro/Distributor state after purchase

    private func updateProStatus(for transaction: Transaction) {
        switch transaction.productID {
        case IAPProduct.proMonthly.rawValue, IAPProduct.proYearly.rawValue:
            isProActive = true
        case IAPProduct.distributorYearly.rawValue:
            isProActive = true
            isDistributorActive = true
        default:
            break
        }
    }

    // MARK: - Transaction Update Listener

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                if transaction.revocationDate != nil {
                    // Refunded / revoked
                    await MainActor.run {
                        switch transaction.productID {
                        case IAPProduct.distributorYearly.rawValue:
                            isDistributorActive = false
                            isProActive = false
                            activeTransaction = nil
                        case IAPProduct.proMonthly.rawValue,
                             IAPProduct.proYearly.rawValue:
                            isProActive = false
                            activeTransaction = nil
                        default:
                            break
                        }
                    }
                } else {
                    // Renewal or new purchase
                    await notifyBackend(transaction: transaction)
                    await transaction.finish()
                    await MainActor.run {
                        self.updateProStatus(for: transaction)
                        self.activeTransaction = transaction
                    }
                }
            }
        }
    }
}
