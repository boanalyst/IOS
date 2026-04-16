// SubscriptionView.swift
// Apple In-App Purchase UI using StoreKit 2 — Premium Redesign
// Plans:
//   Pro Monthly       — com.boanalyst.app.pro.monthly       ₹399/month
//   Pro Yearly        — com.boanalyst.app.pro.yearly        ₹3,999/year
//   Distributors Hub  — com.boanalyst.app.distributor.yearly ₹24,999/year

import SwiftUI
import StoreKit

// MARK: - Legal URLs (Guideline 3.1.2c)
private enum LegalLinks {
    static let privacyPolicy = URL(string: "https://boanalyst.com/privacy-policy.html")!
    static let termsOfUse   = URL(string: "https://boanalyst.com/terms-of-service.html")!
}

// MARK: - Plan display metadata

private struct PlanInfo {
    let productID: IAPProduct
    let badge: String
    let badgeColor: Color
    let tagline: String
    let savings: String?
    let accentColors: [Color]
    let features: [FeatureItem]
}

private struct FeatureItem {
    let icon: String
    let text: String
}

private let goldA = Color(hex: "FFD700")
private let goldB = Color(hex: "B8860B")
private let platA  = Color(hex: "E8E8E8")
private let platB  = Color(hex: "A0A0A0")

private let planInfos: [PlanInfo] = [
    PlanInfo(
        productID: .proMonthly,
        badge: "STARTER",
        badgeColor: Color(hex: "4FC3F7"),
        tagline: "Begin your analysis journey",
        savings: nil,
        accentColors: [Color(hex: "1A6080"), Color(hex: "0D2D3F")],
        features: [
            FeatureItem(icon: "chart.bar.fill",        text: "Advanced Movie Analytics"),
            FeatureItem(icon: "mic.fill",              text: "Inside Talks Exclusive Content"),
            FeatureItem(icon: "bolt.fill",             text: "Early Access To New Features"),
            FeatureItem(icon: "headphones",            text: "Priority Support")
        ]
    ),
    PlanInfo(
        productID: .proYearly,
        badge: "BEST VALUE",
        badgeColor: goldA,
        tagline: "Everything in Starter · save 77%",
        savings: "Save ₹881/yr vs Monthly",
        accentColors: [Color(hex: "4A3500"), Color(hex: "1C1400")],
        features: [
            FeatureItem(icon: "chart.bar.fill",        text: "Advanced Movie Analytics"),
            FeatureItem(icon: "sparkles",              text: "Ad-Free Experience"),
            FeatureItem(icon: "mic.fill",              text: "Inside Talk — 4 Days Early"),
            FeatureItem(icon: "bolt.fill",             text: "Early Access To New Features"),
            FeatureItem(icon: "headphones",            text: "Priority Support")
        ]
    ),
    PlanInfo(
        productID: .distributorYearly,
        badge: "DISTRIBUTORS",
        badgeColor: platA,
        tagline: "Exclusive intelligence for trade professionals",
        savings: nil,
        accentColors: [Color(hex: "1A1A2E"), Color(hex: "0D0D1A")],
        features: [
            FeatureItem(icon: "film.stack.fill",       text: "Early Inside Updates on Movie Projects"),
            FeatureItem(icon: "chart.line.uptrend.xyaxis", text: "Box Office Predictions & Analysis"),
            FeatureItem(icon: "banknote.fill",         text: "Investment Recommendations"),
            FeatureItem(icon: "scope",                 text: "Which Movies to Buy / Distribute"),
            FeatureItem(icon: "eye.fill",              text: "Exclusive Market Insights"),
            FeatureItem(icon: "person.2.fill",         text: "Direct Access to Industry Contacts"),
            FeatureItem(icon: "calendar.badge.clock",  text: "Inside Talk — 1 Month Early Access")
        ]
    )
]

// MARK: - SubscriptionView

struct SubscriptionView: View {
    @EnvironmentObject private var iapManager: IAPManager
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var selectedIndex: Int = 1
    @State private var showSuccessBanner = false
    @State private var purchasedPlanName = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var shimmerPhase: CGFloat = 0

    private var selectedPlan: PlanInfo { planInfos[selectedIndex] }

    private func storeProduct(for plan: PlanInfo) -> Product? {
        iapManager.products.first { $0.id == plan.productID.rawValue }
    }

    private func isActivePlan(_ planInfo: PlanInfo) -> Bool {
        // Use StoreKit's local entitlement as the primary truth for iOS subscriptions
        if let activeTx = iapManager.activeTransaction, activeTx.productID == planInfo.productID.rawValue {
            return true
        }
        
        // Fallback to backend source of truth
        let subscriptionPlan = authVM.currentUser?.subscriptionPlan ?? ""
        switch planInfo.productID {
        case .distributorYearly:
            return subscriptionPlan == "distributors-hub"
        case .proMonthly:
            return subscriptionPlan == "premium-monthly"
        case .proYearly:
            return subscriptionPlan == "premium-yearly"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Background ────────────────────────────────────────────
            Color(hex: "070709").ignoresSafeArea()

            // Subtle radial glow behind selected plan
            RadialGradient(
                colors: [selectedPlan.accentColors[0].opacity(0.35), Color.clear],
                center: .top, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: selectedIndex)

            // ── Scrollable content ────────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                        .padding(.top, 68)
                        .padding(.bottom, 28)

                    // Plan Cards (stacked, full-width)
                    VStack(spacing: 12) {
                        ForEach(planInfos.indices, id: \.self) { idx in
                            PlanCard(
                                plan: planInfos[idx],
                                isSelected: selectedIndex == idx,
                                isActive: isActivePlan(planInfos[idx]),
                                storeProduct: storeProduct(for: planInfos[idx]),
                                shimmerPhase: shimmerPhase
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedIndex = idx
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Legal text
                    legalSection
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 130) // space for sticky CTA
                }
            }

            // ── Sticky CTA Bar ────────────────────────────────────────
            VStack(spacing: 0) {
                // Blur + fade gradient above the bar
                LinearGradient(
                    colors: [Color(hex: "070709").opacity(0), Color(hex: "070709")],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 32)

                ctaBar
                    .background(Color(hex: "070709"))
            }

            // ── Success overlay ───────────────────────────────────────
            if showSuccessBanner {
                successOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .zIndex(10)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .task { await iapManager.loadProducts() }
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
        .onChange(of: iapManager.isProActive) { isPro in
            if isPro {
                purchasedPlanName = selectedPlan.productID.displayName
                withAnimation(.spring(response: 0.4)) { showSuccessBanner = true }
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation(.spring(response: 0.4)) { showSuccessBanner = false }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            // Crown with animated gold ring
            ZStack {
                Circle()
                    .fill(goldA.opacity(0.08))
                    .frame(width: 88, height: 88)
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [goldA, goldB, Color.clear, goldA],
                            center: .center
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(shimmerPhase == 1 ? 360 : 0))
                    .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: shimmerPhase)

                Image(systemName: "crown.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        LinearGradient(colors: [goldA, goldB], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            Text("BoAnalyst Pro")
                .font(.custom("Cinzel-Regular", size: 26))
                .foregroundStyle(
                    LinearGradient(colors: [goldA, goldB], startPoint: .leading, endPoint: .trailing)
                )
                .tracking(2)

            Text("India's premier film intelligence platform")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(hex: "8A8A9A"))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - CTA Bar

    private var ctaBar: some View {
        VStack(spacing: 10) {
            if let error = iapManager.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Required by Guideline 3.1.2(c): show title, length, price before purchase
            if !isActivePlan(selectedPlan) {
                let priceStr: String = {
                    if let p = storeProduct(for: selectedPlan) { return p.displayPrice }
                    return selectedPlan.productID.fallbackPrice
                }()
                // Map period to human-readable subscription length
                let lengthStr: String = {
                    switch selectedPlan.productID {
                    case .proMonthly:        return "1-month subscription"
                    case .proYearly:         return "1-year subscription"
                    case .distributorYearly: return "1-year subscription"
                    }
                }()
                Text("\(selectedPlan.productID.displayName) · \(lengthStr) · \(priceStr)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "8A8A9A"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                // Subscribe / Active button
                Button {
                    Task {
                        if isActivePlan(selectedPlan) { return }
                        guard let product = storeProduct(for: selectedPlan) else {
                            await iapManager.loadProducts()
                            if storeProduct(for: selectedPlan) == nil {
                                alertMessage = "In-App Purchases are currently unavailable. Please try again or contact support."
                                showAlert = true
                            }
                            return
                        }
                        let result = await iapManager.purchase(product)
                        if case .success = result {
                            // Check if backend sync failed (purchase succeeded on Apple but server didn't update)
                            if let syncError = iapManager.errorMessage, !syncError.isEmpty {
                                alertMessage = syncError
                                showAlert = true
                            }
                            // Refresh user data from backend to reflect the new plan.
                            // notifyBackendWithRetry already retried 3 times, so the DB
                            // should be updated by now. A single refresh + one delayed
                            // retry is sufficient. DO NOT call restorePurchases() here —
                            // it creates a cascade of competing backend requests that
                            // cause race conditions during plan upgrades.
                            await authVM.refreshUser()
                            // Retry after 3s in case of propagation delay
                            Task {
                                try? await Task.sleep(nanoseconds: 3_000_000_000)
                                await authVM.refreshUser()
                            }
                        } else if case .failed = result {
                            if let error = iapManager.errorMessage {
                                alertMessage = error
                                showAlert = true
                            }
                        }
                    }
                } label: {
                    ZStack {
                        if iapManager.isPurchasing {
                            ProgressView().tint(.black)
                        } else if isActivePlan(selectedPlan) {
                            Label("Current Plan", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 15, weight: .semibold))
                        } else {
                            let icon = selectedPlan.productID.isDistributorPlan ? "film.stack.fill" : "crown.fill"
                            let priceLabel: String = {
                                if let p = storeProduct(for: selectedPlan) { return p.displayPrice }
                                return selectedPlan.productID.fallbackPrice
                            }()
                            Label("Subscribe · \(priceLabel)", systemImage: icon)
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: isActivePlan(selectedPlan)
                                ? [Color(hex: "2A7A2A"), Color(hex: "1A4A1A")]
                                : iapManager.isPurchasing
                                    ? [goldA.opacity(0.55), goldA.opacity(0.4)]
                                    : [goldA, goldB],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: isActivePlan(selectedPlan) ? Color.green.opacity(0.25) : goldA.opacity(0.28),
                            radius: 14, x: 0, y: 6)
                }
                .disabled(iapManager.isPurchasing || isActivePlan(selectedPlan))

                // Restore — icon-only to save space
                Button {
                    Task {
                        await iapManager.restorePurchases()
                        await authVM.refreshUser()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "8A8A9A"))
                        .frame(width: 52, height: 52)
                        .background(Color(hex: "18181F"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "2A2A35"), lineWidth: 1)
                        )
                }
                .disabled(iapManager.isPurchasing)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Legal
    // Required by Guideline 3.1.2(c): must include functional Privacy Policy
    // and Terms of Use (EULA) links within the app's purchase flow.

    private var legalSection: some View {
        VStack(spacing: 10) {
            Divider()
                .background(Color(hex: "2A2A35"))

            // Subscription disclosure — auto-renewal terms
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period. Manage or cancel anytime in iPhone Settings → Apple ID → Subscriptions.")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "5A5A6A"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // Required functional links — Guideline 3.1.2(c)
            HStack(spacing: 4) {
                Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "4FC3F7"))

                Text("·")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "5A5A6A"))

                Link("Terms of Use (EULA)", destination: LegalLinks.termsOfUse)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "4FC3F7"))
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(goldA.opacity(0.12)).frame(width: 100, height: 100)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(colors: [goldA, goldB], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                Text("You're Pro!")
                    .font(.custom("Cinzel-Regular", size: 24))
                    .foregroundStyle(
                        LinearGradient(colors: [goldA, goldB], startPoint: .leading, endPoint: .trailing)
                    )

                Text("Welcome to \(purchasedPlanName).\nYour subscription is now active.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "A0A0B0"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex: "0F0F16"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(colors: [goldA.opacity(0.5), goldA.opacity(0.05), goldA.opacity(0.2)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 28)
            .shadow(color: goldA.opacity(0.15), radius: 32, x: 0, y: 12)
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: PlanInfo
    let isSelected: Bool
    let isActive: Bool
    let storeProduct: Product?
    let shimmerPhase: CGFloat

    private var priceText: String {
        storeProduct?.displayPrice ?? plan.productID.fallbackPrice
    }

    private var goldA: Color { Color(hex: "FFD700") }
    private var goldB: Color { Color(hex: "B8860B") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Card Header ───────────────────────────────────────────
            HStack(alignment: .center, spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? goldA : Color(hex: "3A3A48"), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(colors: [goldA, goldB], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan.productID.displayName.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isSelected ? goldA : Color(hex: "8A8A9A"))
                            .tracking(1.2)

                        // Badge pill
                        Text(plan.badge)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(plan.badge == "BEST VALUE" ? .black : Color(hex: "0A0A0A"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(plan.badgeColor)
                            )

                        if isActive {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color(hex: "22C55E")))
                        }
                    }

                    Text(plan.tagline)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "6A6A7A"))
                        .lineLimit(1)
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: 1) {
                    Text(priceText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isSelected ? goldA : Color(hex: "C8C8D8"))
                    Text(plan.productID.period)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "5A5A6A"))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, isSelected ? 12 : 18)

            // ── Expanded feature list (only when selected) ───────────
            if isSelected {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .background(
                            isSelected
                                ? LinearGradient(colors: [goldA.opacity(0.3), Color.clear], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color(hex: "2A2A35"), Color.clear], startPoint: .leading, endPoint: .trailing)
                        )
                        .padding(.horizontal, 18)

                    VStack(alignment: .leading, spacing: 10) {
                        if let savings = plan.savings {
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(goldA)
                                Text(savings)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(goldA)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(goldA.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        ForEach(plan.features, id: \.text) { feature in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(isSelected ? goldA : Color(hex: "5A5A6A"))
                                    .frame(width: 18)

                                Text(feature.text)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "C8C8D8"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color(hex: "0F0F16") : Color(hex: "0C0C12"))

                // Shimmer highlight sweep when selected
                if isSelected {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, goldA.opacity(0.04), Color.clear],
                                    startPoint: .init(x: shimmerPhase - 0.5, y: 0),
                                    endPoint: .init(x: shimmerPhase, y: 1)
                                )
                            )
                    }
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isSelected
                        ? LinearGradient(
                            colors: [goldA.opacity(0.6), goldA.opacity(0.1), goldB.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color(hex: "2A2A35"), Color(hex: "1A1A22")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(
            color: isSelected ? goldA.opacity(0.12) : Color.black.opacity(0.3),
            radius: isSelected ? 20 : 6,
            x: 0, y: isSelected ? 8 : 2
        )
    }
}

// MARK: - Locked Content Overlay

struct LockedContentOverlay: View {
    let featureName: String
    @Binding var isPresented: Bool

    private let goldA = Color(hex: "FFD700")
    private let goldB = Color(hex: "B8860B")

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(goldA.opacity(0.1)).frame(width: 80, height: 80)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(colors: [goldA, goldB], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                Text("Pro Feature")
                    .font(.custom("Cinzel-Regular", size: 20))
                    .foregroundStyle(
                        LinearGradient(colors: [goldA, goldB], startPoint: .leading, endPoint: .trailing)
                    )

                Text("\(featureName) is available\nto Pro members.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "A0A0B0"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button("Not Now") { isPresented = false }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "5A5A6A"))
                    .padding(.top, 4)
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex: "0F0F16"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(goldA.opacity(0.25), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
            .shadow(color: goldA.opacity(0.1), radius: 28, x: 0, y: 10)
        }
    }
}
