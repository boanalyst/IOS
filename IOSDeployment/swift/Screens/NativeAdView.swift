// NativeAdView.swift
// A highly premium, gold-bordered glassmorphic Native Advanced Ad wrapper for SwiftUI.
// Bridges the Google Mobile Ads SDK GADNativeAdView (UIKit) into SwiftUI layouts seamlessly.

import SwiftUI
import GoogleMobileAds
import UIKit

/// A SwiftUI view that dynamically loads and displays a premium Native Ad.
/// Respects Pro-tier user exemptions and dynamic backend configurations.
struct NativeAdView: View {
    var index: Int = 0
    var listName: String = "default"
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var nativeAd: GADNativeAd? = nil
    @State private var adUnitId: String = "ca-app-pub-5734863079459748/2827053472" // Default Production Native Unit ID
    @State private var isEnabled: Bool = true

    var body: some View {
        let isPro = authViewModel.currentUser?.isPro == true
        
        if isPro || !isEnabled {
            EmptyView()
        } else {
            VStack {
                if let ad = nativeAd {
                    NativeAdRepresentable(nativeAd: ad)
                        .frame(maxWidth: .infinity)
                        .frame(height: 380) // Perfectly fits our beautiful programmatic layout
                        .padding(.vertical, 8)
                } else {
                    EmptyView()
                }
            }
            .task {
                await fetchConfigAndLoad()
            }
        }
    }

    private func fetchConfigAndLoad() async {
        do {
            let config = try await APIClient.shared.request(.getAdConfig, responseType: AdConfigResponse.self)
            if !config.enabled || !config.nativeAdvancedEnabled {
                self.isEnabled = false
                return
            }
            if let iosNative = config.adUnits?.ios?.nativeAdvanced, !iosNative.isEmpty {
                self.adUnitId = iosNative
            }
            self.loadAd()
        } catch {
            print("⚠️ [NativeAdView] Failed to retrieve dynamic configurations: \(error.localizedDescription). Falling back to test credentials.")
            self.loadAd()
        }
    }

    private func loadAd() {
        NativeAdRegistry.shared.getAd(forIndex: index, listName: listName, adUnitId: adUnitId) { loadedAd in
            self.nativeAd = loadedAd
        }
    }
}

// MARK: - NativeAdRepresentable

private struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: GADNativeAd
    
    func makeUIView(context: Context) -> GADNativeAdView {
        let nativeAdView = GADNativeAdView()
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        
        // ── Main Card Container ──
        let cardContainer = UIView()
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0) // Dark slate background
        cardContainer.layer.cornerRadius = 20
        cardContainer.layer.borderWidth = 1.5
        cardContainer.layer.borderColor = UIColor(red: 0.83, green: 0.69, blue: 0.22, alpha: 1.0).cgColor // Gold color (#D4AF37)
        cardContainer.clipsToBounds = true
        nativeAdView.addSubview(cardContainer)
        
        // Pin Card Container to nativeAdView borders
        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 8),
            cardContainer.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 16),
            cardContainer.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -16),
            cardContainer.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -8)
        ])
        
        // ── Top Header Row (Ad Tag + Brand Name) ──
        let headerStack = UIStackView()
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .center
        cardContainer.addSubview(headerStack)
        
        // Ad Badge Tag
        let adBadge = UILabel()
        adBadge.text = "Ad"
        adBadge.textColor = UIColor(red: 0.83, green: 0.69, blue: 0.22, alpha: 1.0)
        adBadge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        adBadge.textAlignment = .center
        adBadge.layer.borderWidth = 1.0
        adBadge.layer.borderColor = UIColor(red: 0.83, green: 0.69, blue: 0.22, alpha: 1.0).cgColor
        adBadge.layer.cornerRadius = 4
        adBadge.clipsToBounds = true
        adBadge.widthAnchor.constraint(equalToConstant: 24).isActive = true
        adBadge.heightAnchor.constraint(equalToConstant: 16).isActive = true
        headerStack.addArrangedSubview(adBadge)
        
        // Brand Name (Advertiser Label)
        let advertiserLabel = UILabel()
        advertiserLabel.text = nativeAd.advertiser ?? "Sponsored"
        advertiserLabel.textColor = UIColor.lightGray
        advertiserLabel.font = UIFont.systemFont(ofSize: 12)
        headerStack.addArrangedSubview(advertiserLabel)
        nativeAdView.advertiserView = advertiserLabel
        
        // ── Middle Row (App Icon + Headline) ──
        let middleStack = UIStackView()
        middleStack.translatesAutoresizingMaskIntoConstraints = false
        middleStack.axis = .horizontal
        middleStack.spacing = 12
        middleStack.alignment = .center
        cardContainer.addSubview(middleStack)
        
        // App Icon
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.layer.cornerRadius = 8
        iconImageView.clipsToBounds = true
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        iconImageView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        if let icon = nativeAd.icon {
            iconImageView.image = icon.image
            middleStack.addArrangedSubview(iconImageView)
            nativeAdView.iconView = iconImageView
        }
        
        // Headline
        let headlineLabel = UILabel()
        headlineLabel.text = nativeAd.headline
        headlineLabel.textColor = .white
        headlineLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        headlineLabel.numberOfLines = 1
        middleStack.addArrangedSubview(headlineLabel)
        nativeAdView.headlineView = headlineLabel
        
        // ── Body Text ──
        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.text = nativeAd.body
        bodyLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        bodyLabel.font = UIFont.systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 2
        cardContainer.addSubview(bodyLabel)
        nativeAdView.bodyView = bodyLabel
        
        // ── Media View ──
        let mediaView = GADMediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.layer.cornerRadius = 10
        mediaView.clipsToBounds = true
        cardContainer.addSubview(mediaView)
        nativeAdView.mediaView = mediaView
        
        // ── Call to Action Button ──
        let ctaButton = UIButton(type: .custom)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        ctaButton.setTitleColor(.black, for: .normal)
        ctaButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        ctaButton.backgroundColor = UIColor(red: 0.83, green: 0.69, blue: 0.22, alpha: 1.0) // Gold
        ctaButton.layer.cornerRadius = 20
        ctaButton.isUserInteractionEnabled = false // Let GADNativeAdView handle user interaction
        cardContainer.addSubview(ctaButton)
        nativeAdView.callToActionView = ctaButton
        
        // ── Layout Constraints ──
        NSLayoutConstraint.activate([
            // Header Row constraints
            headerStack.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 14),
            headerStack.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            
            // Middle Row constraints
            middleStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            middleStack.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            middleStack.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            
            // Body Label constraints
            bodyLabel.topAnchor.constraint(equalTo: middleStack.bottomAnchor, constant: 10),
            bodyLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            bodyLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            
            // Media View constraints
            mediaView.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
            mediaView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            mediaView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            mediaView.heightAnchor.constraint(equalToConstant: 160),
            
            // CTA Button constraints
            ctaButton.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 12),
            ctaButton.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            ctaButton.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            ctaButton.heightAnchor.constraint(equalToConstant: 40),
            ctaButton.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -14)
        ])
        
        // Bind the native ad
        nativeAdView.nativeAd = nativeAd
        
        return nativeAdView
    }
    
    func updateUIView(_ uiView: GADNativeAdView, context: Context) {}
}
