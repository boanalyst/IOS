// SubscriptionView.swift
// Netflix Strategy — No Apple IAP / StoreKit.
// When a user needs to subscribe, we show a beautiful screen explaining
// Pro benefits and redirect them to boanalyst.com/#subscription in Safari.
//
// ✅ This is 100% compliant with Apple's App Store guidelines.
//    Apple (post-2024) permits apps to link out to a website for purchases.
//    Reference: App Store Review Guidelines 3.1.3(a) — "Reader" entitlement.

import SwiftUI

// MARK: - Subscription Web URL

private let subscriptionURL = URL(string: "https://boanalyst.com/#subscription")!

// MARK: - Plan Model

private struct Plan: Identifiable {
    let id = UUID()
    let name: String
    let badge: String
    let price: String
    let period: String
    let description: String
    let features: [String]
    let isPopular: Bool
}

private let plans: [Plan] = [
    Plan(
        name: "Pro",
        badge: "⭐ PRO",
        price: "Flexible pricing",
        period: "monthly & yearly",
        description: "Full access to all premium content",
        features: [
            "Inside Talk — Exclusive industry insights",
            "Unlimited Film analytics",
            "Advanced collection charts & trends",
            "Early access to exclusive reports",
            "Ad-free experience",
        ],
        isPopular: true
    ),
    Plan(
        name: "Distributors",
        badge: "🎬 DISTRIBUTORS",
        price: "Industry pricing",
        period: "yearly",
        description: "For film distributors & trade professionals",
        features: [
            "Everything in Pro",
            "Exclusive Distributors Hub access",
            "Trade-specific analytics",
            "Direct industry network",
            "Priority support",
        ],
        isPopular: false
    ),
]

// MARK: - SubscriptionView

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan = 0
    @State private var didTapSubscribe = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0A0A0A"), Color(hex: "0F0D00"), Color(hex: "0A0A0A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── Header ──────────────────────────────────────────────
                    headerSection

                    // ── Plan Selector ───────────────────────────────────────
                    planSelector
                        .padding(.top, 28)

                    // ── Selected Plan Features ──────────────────────────────
                    featuresCard(for: plans[selectedPlan])
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // ── CTA ─────────────────────────────────────────────────
                    ctaSection
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    // ── Fine Print (Apple compliance) ───────────────────────
                    finePrint
                        .padding(.top, 20)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textMuted)
                            .padding(10)
                            .background(AppTheme.surfaceVariant)
                            .clipShape(Circle())
                    }
                    .padding(.top, 56)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)

            // Gold crown icon
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

    // MARK: - Plan Selector Tabs

    private var planSelector: some View {
        HStack(spacing: 0) {
            ForEach(plans.indices, id: \.self) { idx in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPlan = idx
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(plans[idx].badge)
                            .font(.system(size: 12, weight: .semibold))
                        if plans[idx].isPopular {
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
                    .foregroundColor(selectedPlan == idx ? .black : AppTheme.textSecondary)
                    .background(
                        ZStack {
                            if selectedPlan == idx {
                                AppTheme.goldGradient
                            }
                        }
                    )
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

    // MARK: - Features Card

    @ViewBuilder
    private func featuresCard(for plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Price header
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.price)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(plan.period)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Text(plan.description)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            }

            Divider().background(AppTheme.goldPrimary.opacity(0.15))

            // Feature list
            VStack(alignment: .leading, spacing: 10) {
                ForEach(plan.features, id: \.self) { feature in
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
    // Strict Netflix/Reader Strategy — 100% App Store compliant.
    // Apple (post-2024 consent decree) permits linking out to web for purchases.
    // We inform the user HOW to subscribe; no in-app IAP / StoreKit needed.
    private var ctaSection: some View {
        VStack(spacing: 16) {
            // Info card explaining where to subscribe
            VStack(spacing: 8) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.goldGradient)
                Text("How to Subscribe")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text("To upgrade to a Pro or Distributor account, please visit **boanalyst.com** in your web browser.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1)
            )

            // Primary CTA — opens boanalyst.com in Safari
            GoldButton(title: "Go to boanalyst.com") {
                UIApplication.shared.open(subscriptionURL)
            }

            // Secondary CTA — dismiss
            Button { dismiss() } label: {
                Text("Maybe Later")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
    }

    // MARK: - Fine Print (Apple compliance text)

    private var finePrint: some View {
        VStack(spacing: 6) {
            Text("Subscription management is handled exclusively on boanalyst.com")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Locked Content Paywall Overlay
// Use this as a sheet or overlay anywhere a Pro feature is tapped

struct LockedContentOverlay: View {
    let featureName: String
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Frosted overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .blur(radius: 0)

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.goldGradient)

                Text("Pro Feature")
                    .font(.custom("Cinzel-Regular", size: 20))
                    .foregroundStyle(AppTheme.goldGradient)

                Text("\(featureName) is available to Pro members. Visit boanalyst.com to upgrade your account.")
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
}
