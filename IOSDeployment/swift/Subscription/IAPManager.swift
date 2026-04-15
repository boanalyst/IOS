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

    // After purchase() sends a transaction to the backend, block the listener
    // from overriding it for 30 seconds. This prevents Apple Sandbox replays
    // of old transactions (from previous accounts on the same Apple ID) from
    // overriding the plan the user JUST purchased.
    private var purchaseCooldownUntil: Date = .distantPast

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
                        // Block listener from overriding this purchase for 30 seconds
                        purchaseCooldownUntil = Date().addingTimeInterval(30)
                        print("🍎 IAPManager: ✅ Purchase + backend sync complete for \(transaction.productID) — listener blocked for 30s")
                    } else {
                        // Backend notification failed even after retries.
                        // Do NOT mark notified — the listener may succeed on next launch.
                        // Still finish the transaction with Apple (Apple requires this).
                        print("⚠️ IAPManager: Backend notification failed for \(transaction.id) — will retry on next app launch via listener")
                        // CRITICAL: Surface this error to the user so they know to take action
                        self.errorMessage = "Purchase completed but server sync failed. Please tap 'Restore Purchases' or restart the app to activate your plan."
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
            // After restore, notify backend with the HIGHEST active entitlement
            // (not just activeTransaction which might be stale/wrong tier)
            if let highestTx = await getHighestActiveEntitlement() {
                let txIdStr = String(highestTx.id)
                if !hasNotifiedTransaction(txIdStr) {
                    let backendNotified = await notifyBackendWithRetry(transaction: highestTx)
                    if backendNotified {
                        markTransactionNotified(txIdStr)
                    }
                }
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
    }

    /// DISABLED: Auto-syncing Apple entitlements on login was causing the
    /// "every plan auto-subscribes" bug. In Apple Sandbox (and potentially
    /// production with shared Apple IDs), old test purchases persist as active
    /// entitlements on the device. When ANY user signs in, this method would
    /// find those stale entitlements and push them to the backend — auto-
    /// subscribing users who never purchased anything.
    ///
    /// The correct subscription flows are:
    ///   1. `purchase()` — user explicitly buys a plan → notifies backend ✅
    ///   2. `restorePurchases()` — user taps "Restore" button → notifies backend ✅
    ///   3. Transaction listener — catches renewals → notifies backend ✅
    ///
    /// There is NO safe way to auto-sync on login because Apple entitlements
    /// are tied to the Apple ID, not the backend user. We cannot verify that
    /// the entitlement on this device actually belongs to the user who just
    /// signed in.
    ///
    /// If a user purchased on another device and needs to activate here,
    /// they can tap "Restore Purchases" in the subscription screen.
    func syncSubscriptionWithBackend(backendPlan: String?) async {
        // NO-OP: Intentionally disabled to prevent stale entitlements from
        // auto-subscribing users on login. See comment above.
        print("🍎 IAPManager: syncSubscriptionWithBackend — DISABLED (use Restore Purchases instead)")
    }

    // MARK: - Notify Backend

    /// Sends the transaction to the backend and returns true if the backend
    /// confirmed success (success: true). Returns false on network failure or
    /// backend error so the caller can decide whether to mark the txn as notified.
    @discardableResult
    @MainActor
    private func notifyBackend(transaction: Transaction) async -> Bool {
        print("🍎 IAPManager: notifyBackend called — productId=\(transaction.productID), txnId=\(transaction.id), originalTxnId=\(transaction.originalID)")
        
        guard let endpoint = try? APIEndpoint.verifyAppleReceipt(
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            productId: transaction.productID,
            expiresDate: transaction.expirationDate
        ) else {
            let msg = "Failed to create API request"
            self.errorMessage = msg
            print("🍎 IAPManager: ❌ \(msg)")
            return false
        }
        
        print("🍎 IAPManager: Calling backend at \(endpoint.path) with productId=\(transaction.productID)")
        
        do {
            let response = try await api.requestRaw(endpoint)
            let success = response["success"] as? Bool ?? false
            let ignored = response["ignored"] as? Bool ?? false
            let duplicate = response["duplicate"] as? Bool ?? false
            let blocked = response["blocked"] as? Bool ?? false
            let plan = response["plan"] as? String ?? "unknown"
            let message = response["message"] as? String ?? "No message"
            let errorDetails = response["error"] as? String ?? ""
            
            print("🍎 IAPManager: Backend response — success=\(success), ignored=\(ignored), duplicate=\(duplicate), blocked=\(blocked), plan=\(plan), message=\(message)")
            
            if !success && !ignored && !duplicate {
                let msg = "Backend Sync Failed: \(message)\n\(errorDetails)"
                self.errorMessage = msg
                print("🍎 IAPManager: ❌ \(msg)")
            } else if ignored {
                // Not an error, but let's clear errorMessage just in case
            }
            
            // ignored / duplicate are also considered "handled" — no retry needed
            return success || ignored || duplicate
        } catch {
            let errorStr = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let msg = "Network/API Error: \(errorStr)"
            self.errorMessage = msg
            print("🍎 IAPManager: ❌ \(msg)")
            return false
        }
    }

    /// Retries notifyBackend up to 3 times with exponential back-off.
    /// Returns true if any attempt succeeds.
    @MainActor
    private func notifyBackendWithRetry(transaction: Transaction, maxAttempts: Int = 3) async -> Bool {
        self.errorMessage = nil // Clear previous errors
        for attempt in 1...maxAttempts {
            let ok = await notifyBackend(transaction: transaction)
            if ok {
                print("🍎 IAPManager: Backend notified successfully on attempt \(attempt) for txn \(transaction.id)")
                self.errorMessage = nil // Success, clear any retry errors
                return true
            }
            if attempt < maxAttempts {
                let delayNs = UInt64(attempt) * 2_000_000_000 // 2s, 4s back-off
                print("🍎 IAPManager: Attempt \(attempt) failed — retrying in \(attempt * 2)s…")
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
        print("🍎 IAPManager: All \(maxAttempts) backend notification attempts failed for txn \(transaction.id)")
        // errorMessage is already set by the last call to notifyBackend
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

    // MARK: - Determine Highest Active Entitlement
    //
    // Checks Transaction.currentEntitlements to find the highest-tier subscription
    // the user ACTUALLY owns right now. This is the critical filter that prevents
    // StoreKit historical replays from overriding the correct plan.
    //
    // Apple's currentEntitlements ONLY contains subscriptions that are genuinely
    // active (paid, not expired, not revoked). Historical replays are NOT included.
    // By cross-referencing against this, we ensure we only forward the correct
    // subscription to our backend.

    private func getHighestActiveEntitlement() async -> Transaction? {
        let planRank: [String: Int] = [
            IAPProduct.proMonthly.rawValue: 1,
            IAPProduct.proYearly.rawValue: 2,
            IAPProduct.distributorYearly.rawValue: 3
        ]

        var highestTransaction: Transaction? = nil
        var highestRank = 0

        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.revocationDate == nil {
                let rank = planRank[tx.productID] ?? 0
                if rank > highestRank {
                    highestRank = rank
                    highestTransaction = tx
                }
            }
        }

        return highestTransaction
    }

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
                    } else if Date() < purchaseCooldownUntil {
                        // A purchase() just completed and sent its transaction to the backend.
                        // Block ALL listener-driven backend calls for 30 seconds to prevent
                        // Apple Sandbox replays from overriding the purchased plan.
                        print("🍎 IAPManager: Transaction \(txIdStr) for \(transaction.productID) BLOCKED — purchase cooldown active until \(purchaseCooldownUntil)")
                        markTransactionNotified(txIdStr)
                    } else {
                        // *** CRITICAL FIX: Cross-check against currentEntitlements ***
                        //
                        // StoreKit fires Transaction.updates for ALL transactions in the
                        // subscription group — including historical replays of old plans.
                        // If we blindly forward every update, a replayed premium-yearly
                        // transaction will OVERRIDE a fresh premium-monthly purchase
                        // (because yearly has higher rank on the backend).
                        //
                        // The fix: check currentEntitlements to find which subscription
                        // is ACTUALLY active. Only notify the backend with that one.
                        // If the incoming transaction isn't the active entitlement, skip it.

                        let highestActive = await getHighestActiveEntitlement()

                        if let activeEntitlement = highestActive {
                            if transaction.productID == activeEntitlement.productID {
                                print("🍎 IAPManager: Transaction \(txIdStr) for \(transaction.productID) IS the active entitlement — notifying backend")

                                let txToSend = activeEntitlement
                                let txToSendIdStr = String(txToSend.id)

                                if !hasNotifiedTransaction(txToSendIdStr) {
                                    let backendNotified = await notifyBackendWithRetry(transaction: txToSend)
                                    if backendNotified {
                                        markTransactionNotified(txToSendIdStr)
                                        if txIdStr != txToSendIdStr {
                                            markTransactionNotified(txIdStr)
                                        }
                                    }
                                } else {
                                    print("🍎 IAPManager: Active entitlement \(txToSendIdStr) already notified — skipping")
                                    markTransactionNotified(txIdStr)
                                }
                            } else {
                                print("🍎 IAPManager: Transaction \(txIdStr) for \(transaction.productID) is NOT the active entitlement (\(activeEntitlement.productID)) — SKIPPING")
                                markTransactionNotified(txIdStr)
                            }
                        } else {
                            print("🍎 IAPManager: No active entitlement found, forwarding transaction \(txIdStr) for \(transaction.productID) to backend")
                            let backendNotified = await notifyBackendWithRetry(transaction: transaction)
                            if backendNotified {
                                markTransactionNotified(txIdStr)
                            }
                        }
                    }

                    await transaction.finish()
                    // Refresh full subscription status from currentEntitlements
                    // instead of using updateProStatus(for: transaction) which would
                    // set incorrect UI state if the incoming transaction is a lower-tier replay.
                    await refreshSubscriptionStatus()
                }
            }
        }
    }
}
