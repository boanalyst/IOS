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

    // MARK: - Notified Transaction ID Tracking
    //
    // We persist a set of transaction IDs that have already been sent to our
    // backend. This is the correct, precise way to decide whether to call
    // notifyBackend from the transaction update listener:
    //
    //   • A REAL new purchase/renewal   → new transactionId not in the set → notify ✅
    //   • A HISTORICAL replayed txn      → transactionId never seen by THIS app
    //                                      install... BUT it may not be in our set
    //                                      either! So we rely on the BACKEND guards
    //                                      (cross-user ownership check, expiry check)
    //                                      to reject those. The set prevents double-
    //                                      notifying within the same install lifecycle.
    //   • A re-delivered renewal         → transactionId IS already in the set → skip ✅
    //
    // The set is stored in UserDefaults and cleared on logout so it doesn't
    // grow unbounded across account switches.

    private static let notifiedTxnsKey = "boanalyst_iap_notified_txn_ids"

    private var notifiedTransactionIds: Set<String> {
        get {
            let arr = UserDefaults.standard.stringArray(forKey: Self.notifiedTxnsKey) ?? []
            return Set(arr)
        }
        set {
            // Cap the stored set at 200 entries to avoid indefinite growth
            let capped = Array(newValue.prefix(200))
            UserDefaults.standard.set(capped, forKey: Self.notifiedTxnsKey)
        }
    }

    private func markTransactionNotified(_ transactionId: String) {
        var current = notifiedTransactionIds
        current.insert(transactionId)
        notifiedTransactionIds = current
    }

    private func hasNotifiedTransaction(_ transactionId: String) -> Bool {
        return notifiedTransactionIds.contains(transactionId)
    }

    /// Call this on logout so the set is reset for the next account.
    /// This prevents a logged-out transaction ID from blocking a new
    /// legitimate activation after the user switches accounts.
    func clearNotifiedTransactions() {
        UserDefaults.standard.removeObject(forKey: Self.notifiedTxnsKey)
        print("🍎 IAPManager: Cleared notified transaction ID cache (logout)")
    }

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
                    // Notify backend FIRST with retry — only mark as notified after
                    // confirmed success. This prevents the silent-failure bug where
                    // a network blip marks the txn as notified but the backend never
                    // actually received it, causing the plan to stay unchanged forever.
                    let backendNotified = await notifyBackendWithRetry(transaction: transaction)
                    if backendNotified {
                        markTransactionNotified(String(transaction.id))
                    } else {
                        // Backend notification failed even after retries.
                        // Do NOT mark notified — the listener may succeed on next launch.
                        // Still finish the transaction with Apple (Apple requires this).
                        print("⚠️ IAPManager: Backend notification failed for \(transaction.id) — will retry on next app launch via listener")
                    }
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

    /// Sends the transaction to the backend and returns true if the backend
    /// confirmed success (success: true). Returns false on network failure or
    /// backend error so the caller can decide whether to mark the txn as notified.
    @discardableResult
    private func notifyBackend(transaction: Transaction) async -> Bool {
        guard let endpoint = try? APIEndpoint.verifyAppleReceipt(
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            productId: transaction.productID,
            expiresDate: transaction.expirationDate
        ) else { return false }
        do {
            let response = try await api.requestRaw(endpoint)
            let success = response["success"] as? Bool ?? false
            let ignored = response["ignored"] as? Bool ?? false
            let duplicate = response["duplicate"] as? Bool ?? false
            // ignored / duplicate are also considered "handled" — no retry needed
            return success || ignored || duplicate
        } catch {
            print("🍎 IAPManager: notifyBackend error: \(error.localizedDescription)")
            return false
        }
    }

    /// Retries notifyBackend up to 3 times with exponential back-off.
    /// Returns true if any attempt succeeds.
    private func notifyBackendWithRetry(transaction: Transaction, maxAttempts: Int = 3) async -> Bool {
        for attempt in 1...maxAttempts {
            let ok = await notifyBackend(transaction: transaction)
            if ok {
                print("🍎 IAPManager: Backend notified successfully on attempt \(attempt) for txn \(transaction.id)")
                return true
            }
            if attempt < maxAttempts {
                let delayNs = UInt64(attempt) * 2_000_000_000 // 2s, 4s back-off
                print("🍎 IAPManager: Attempt \(attempt) failed — retrying in \(attempt * 2)s…")
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
        print("🍎 IAPManager: All \(maxAttempts) backend notification attempts failed for txn \(transaction.id)")
        return false
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
    //
    // This listener fires for ALL StoreKit transaction events:
    //   1. A genuine new purchase (user just bought) ← want to notify backend
    //   2. A subscription auto-renewal              ← want to notify backend
    //   3. StoreKit replaying old device transactions when a new user signs in ← DO NOT notify
    //
    // The correct guard is a PERSISTENT SET of already-notified transaction IDs
    // stored in UserDefaults. Each StoreKit transaction has a unique, stable
    // `id` (UInt64). If we've already hit the backend with a given ID, we skip it.
    //
    // WHY NOT A TIME WINDOW?
    //   A time window (e.g. "< 5 minutes old") breaks renewals: StoreKit delivers
    //   renewal events even if the app was in the background for hours, so the
    //   renewal's purchaseDate might be 6+ hours old — yet it IS a legitimate new
    //   billing event that the backend needs to know about.
    //
    // HOW THIS CORRECTLY HANDLES THE 3 SCENARIOS:
    //   1. New purchase  → purchase() already called notifyBackend AND marked the ID
    //                      → listener sees ID in set → skips (no double-notify) ✅
    //   2. Auto-renewal  → StoreKit delivers a brandnew transactionId
    //                      → NOT in our set → notifyBackend called → ID marked ✅
    //   3. Historical replay → old txnId not in our set (first run), BUT backend's
    //                          GUARD 3 (cross-user ownership) rejects it as it
    //                          belongs to a different account, AND GUARD 2 rejects
    //                          it if expired. If it somehow passes backend guards
    //                          (e.g. the old account never used this backend),
    //                          the 1-hour backend dedup cache will prevent
    //                          repeat calls. ✅

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                if transaction.revocationDate != nil {
                    // Refunded / revoked — update local UI state only. No backend call
                    // needed here because the subscription expiry checker on the server
                    // will handle this, and the user's plan should be downgraded to free.
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
                    let txIdStr = String(transaction.id)

                    if hasNotifiedTransaction(txIdStr) {
                        // Already sent this transaction to the backend (e.g., via purchase()
                        // or a previous run of this listener). Skip to avoid duplicates.
                        print("🍎 IAPManager: Transaction \(txIdStr) already notified — skipping backend call")
                    } else {
                        // CRITICAL SANDBOX GUARD: Verify this transaction is CURRENTLY ACTIVE
                        // in the subscription group before notifying the backend.
                        //
                        // Problem: All three plans share ONE subscription group. When a user
                        // subscribes to Monthly, Apple Sandbox also replays historical Yearly
                        // transactions (from the subscription group history) that are NOT in
                        // our notifiedTransactionIds set (new install / new account). These
                        // replays arrive milliseconds after the real purchase and cause the
                        // backend to wrongly set premium-yearly instead of premium-monthly.
                        //
                        // Fix: Check Transaction.currentEntitlements first. This returns ONLY
                        // the ACTUALLY ACTIVE subscription right now. If this transaction's ID
                        // is not among the current entitlements, it is a historical replay and
                        // must NOT be sent to the backend.
                        var isCurrentEntitlement = false
                        for await entResult in Transaction.currentEntitlements {
                            if case .verified(let entTx) = entResult,
                               String(entTx.id) == txIdStr {
                                isCurrentEntitlement = true
                                break
                            }
                        }

                        if isCurrentEntitlement {
                            print("🍎 IAPManager: New current transaction \(txIdStr) for \(transaction.productID) — notifying backend")
                            let ok = await notifyBackendWithRetry(transaction: transaction)
                            if ok {
                                markTransactionNotified(txIdStr)
                            }
                            // If it failed, leave it un-marked so next listener fire retries
                        } else {
                            // This is a historical replay from the subscription group.
                            // Mark it as notified so we never process it later, but do NOT
                            // call the backend — it would overwrite a legitimate current plan.
                            print("🍎 IAPManager: Transaction \(txIdStr) for \(transaction.productID) is NOT a current entitlement — marking as seen but skipping backend (historical replay)")
                            markTransactionNotified(txIdStr)
                        }
                    }

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
