// SubscriptionView.swift
// Apple In-App Purchase UI using StoreKit 2
// Plans:
//   Pro Monthly       — com.boanalyst.app.pro.monthly       ₹399/month
//   Pro Yearly        — com.boanalyst.app.pro.yearly        ₹3,999/year
//   Distributors Hub  — com.boanalyst.app.distributor.yearly ₹24,999/year

import SwiftUI
import StoreKit

// MARK: - Plan display metadata (mirrors IAPProduct enum)

private struct PlanInfo {
    let productID: IAPProduct
    let badge: String
    let isPopular: Bool
    let savings: String?
    let features: [String]
}

private let planInfos: [PlanInfo] = [
    PlanInfo(
        productID: .proMonthly,
        badge: "STARTER",
        isPopular: false,
        savings: nil,
        features: [
            "Advanced Movie Analytics",
            "Inside Talks Exclusive Content",
            "Priority Support",
            "Early Access To New Features"
        ]
    ),
    PlanInfo(
        productID: .proYearly,
        badge: "⭐ BEST VALUE",
        isPopular: true,
        savings: "Save ~77% vs monthly",
        features: [
            "Advanced Movie Analytics",
            "Inside Talk — 4 Days Early",
            "Ad-Free Experience",
            "Priority Support",
            "Early Access To New Features"
        ]
    ),
    PlanInfo(
        productID: .distributorYearly,
        badge: "🎬 DISTRIBUTORS",
        isPopular: false,
        savings: "Trade professionals only",
        features: [
            "🎬 Early Inside Updates on Movie Projects",
            "📊 Box Office Predictions & Analysis",
            "💰 Investment Recommendations",
            "🔮 Which Movies to Buy / Distribute",
            "🎯 Exclusive Market Insights",
            "🤝 Direct Access to Industry Contacts",
            "🌟 Priority Support & Consultation",
            "⚡ Inside Talk — 1 Month Early Access"
        ]
    )
]

// MARK: - SubscriptionView

struct SubscriptionView: View {
    @EnvironmentObject private var iapManager: IAPManager
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var selectedIndex: Int = 1   // Default to "Best Value" (yearly)
    @State private var showSuccessBanner = false
    @State private var purchasedPlanName = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var selectedPlan: PlanInfo { planInfos[selectedIndex] }

    private func storeProduct(for plan: PlanInfo) -> Product? {
        iapManager.products.first { $0.id == plan.productID.rawValue }
    }

    private var isCurrentPlanActive: Bool {
        // Backend is the sole source of truth for subscription status display.
        // StoreKit currentEntitlements returns old transactions from previous
        // accounts, causing "Current Plan Active" on new free accounts.
        // StoreKit is still used for purchase/restore in IAPManager.
        let backendPro = authVM.currentUser?.isPro ?? false
        let backendDistributor = authVM.currentUser?.isDistributor ?? false
        if selectedPlan.productID.isDistributorPlan {
            return backendDistributor
        } else {
            return backendPro || backendDistributor
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0A0A0A"), Color(hex: "0F0D00"), Color(hex: "0A0A0A")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection.padding(.top, 72)

                    planTabs
                        .padding(.top, 28)

                    selectedPlanCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    ctaSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    legalSection
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    Spacer(minLength: 40)
                }
            }

            // Close button removed since this is a Tab and cannot be dismissed

            if showSuccessBanner {
                successOverlay
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .task { await iapManager.loadProducts() }
        .onChange(of: iapManager.isProActive) { isPro in
            if isPro {
                purchasedPlanName = selectedPlan.productID.displayName
                withAnimation(.spring(response: 0.4)) { showSuccessBanner = true }
                Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    withAnimation(.spring(response: 0.4)) { showSuccessBanner = false }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.goldPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                Circle()
                    .stroke(AppTheme.goldPrimary.opacity(0.2), lineWidth: 1)
                    .frame(width: 80, height: 80)
                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.goldGradient)
            }

            Text("Unlock BoAnalyst Pro")
                .font(.custom("Cinzel-Regular", size: 24))
                .foregroundStyle(AppTheme.goldGradient)
                .multilineTextAlignment(.center)

            Text("India's most comprehensive\nFilm Analysis intelligence platform")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Plan Tabs

    private var planTabs: some View {
        HStack(spacing: 0) {
            ForEach(planInfos.indices, id: \.self) { idx in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedIndex = idx }
                } label: {
                    VStack(spacing: 4) {
                        Text(planInfos[idx].badge)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if planInfos[idx].isPopular {
                            Text("POPULAR")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.goldPrimary)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(selectedIndex == idx ? .black : AppTheme.textSecondary)
                    .background(ZStack {
                        if selectedIndex == idx { AppTheme.goldGradient }
                    })
                }
            }
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.goldPrimary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Selected Plan Card

    private var selectedPlanCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Price header
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    // Live App Store price if loaded, fallback to hardcoded
                    if let product = storeProduct(for: selectedPlan) {
                        Text(product.displayPrice)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                    } else {
                        Text(selectedPlan.productID.fallbackPrice)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    Text(selectedPlan.productID.period)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                if let savings = selectedPlan.savings {
                    Text(savings)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 130)
                }
            }

            Divider().background(AppTheme.goldPrimary.opacity(0.15))

            // Feature list
            VStack(alignment: .leading, spacing: 10) {
                ForEach(selectedPlan.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.goldGradient)
                            .frame(width: 18)
                        Text(feature)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        }
        .padding(20)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.goldPrimary.opacity(0.4), AppTheme.goldPrimary.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.goldPrimary.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 14) {
            if let error = iapManager.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            // Primary subscribe button
            Button {
                Task {
                    if isCurrentPlanActive { return }
                    guard let product = storeProduct(for: selectedPlan) else {
                        await iapManager.loadProducts()
                        if storeProduct(for: selectedPlan) == nil {
                            alertMessage = "In-App Purchases are currently unavailable. Ensure you have accepted the Paid Apps Agreement in App Store Connect."
                            showAlert = true
                        }
                        return
                    }
                    _ = await iapManager.purchase(product)
                }
            } label: {
                ZStack {
                    if iapManager.isPurchasing {
                        ProgressView().tint(.black)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: selectedPlan.productID.isDistributorPlan ? "film.stack.fill" : "crown.fill")
                                .font(.system(size: 14))
                            if isCurrentPlanActive {
                                Text("Current Plan Active")
                                    .font(.system(size: 15, weight: .semibold))
                            } else if let product = storeProduct(for: selectedPlan) {
                                Text("Subscribe · \(product.displayPrice)")
                                    .font(.system(size: 15, weight: .semibold))
                            } else {
                                Text("Subscribe · \(selectedPlan.productID.fallbackPrice)")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(iapManager.isPurchasing
                    ? AnyShapeStyle(AppTheme.goldPrimary.opacity(0.7))
                    : AnyShapeStyle(AppTheme.goldGradient)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppTheme.goldPrimary.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .disabled(iapManager.isPurchasing || isCurrentPlanActive)

            // Restore purchases
            Button {
                Task { await iapManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .disabled(iapManager.isPurchasing)
        }
    }

    // MARK: - Legal Fine Print (Apple REQUIRED)

    private var legalSection: some View {
        Text("Subscription automatically renews unless cancelled at least 24 hours before renewal. Manage or cancel anytime in iPhone Settings → Apple ID → Subscriptions.")
            .font(.system(size: 10))
            .foregroundColor(AppTheme.textMuted)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.goldGradient)
                Text("Welcome to \(purchasedPlanName)!")
                    .font(.custom("Cinzel-Regular", size: 22))
                    .foregroundStyle(AppTheme.goldGradient)
                    .multilineTextAlignment(.center)
                Text("Your subscription is now active.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(36)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppTheme.goldPrimary.opacity(0.4), lineWidth: 1)
            )
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Locked Content Overlay

struct LockedContentOverlay: View {
    let featureName: String
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.goldGradient)

                Text("Pro Feature")
                    .font(.custom("Cinzel-Regular", size: 20))
                    .foregroundStyle(AppTheme.goldGradient)

                Text("\(featureName) is available to Pro members.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Button("Not Now") { isPresented = false }
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(32)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(IAPManager.shared)
}
