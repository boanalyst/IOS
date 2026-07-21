// AppOpenAdManager.swift
// Handles loading and displaying AdMob App Open ads for iOS.
// Integrates with the processes lifecycle and remote backend ad configurations.

import Foundation
import GoogleMobileAds
import UIKit

/// A highly premium, background-aware App Open Ad Manager for iOS.
/// Leverages the Google Mobile Ads SDK.
/// Handles dynamic configuration, active background cooldowns, and Pro-tier exemption.
@MainActor
class AppOpenAdManager: NSObject, FullScreenContentDelegate {
    static let shared = AppOpenAdManager()
    
    private var appOpenAd: AppOpenAd?
    private var isLoadingAd = false
    private var lastShownTime: Date?
    
    // Default AdMob Production App Open Ad Unit ID for iOS
    private var adUnitId = "ca-app-pub-5734863079459748/7171520374"
    private var cooldownSeconds: TimeInterval = 4 * 60 * 60 // 4 hours in seconds
    
    private override init() {
        super.init()
        // Allow the first ad to load immediately on cold start by leaving lastShownTime as nil
        
        // Listen to application foregrounding notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func applicationWillEnterForeground() {
        showAdIfAvailable()
    }
    
    /// Starts prefetching config and ad. Call this on app launch.
    func initialize() {
        fetchConfigAndLoad()
    }
    
    func fetchConfigAndLoad() {
        if UserDefaults.standard.bool(forKey: "is_user_pro") {
            print("ℹ️ [AppOpenAdManager] Local Pro status active. Bypassing configuration fetch.")
            self.appOpenAd = nil
            return
        }
        
        Task { @MainActor in
            do {
                let config = try await APIClient.shared.request(.getAdConfig, responseType: AdConfigResponse.self)
                
                // Server-side + client-side bypass check
                if !config.enabled || !config.appOpenEnabled {
                    print("ℹ️ [AppOpenAdManager] App Open Ads are disabled via dynamic configuration.")
                    self.appOpenAd = nil
                    return
                }
                
                if let iosOpen = config.adUnits?.ios?.appOpen, !iosOpen.isEmpty {
                    self.adUnitId = iosOpen
                }
                self.cooldownSeconds = config.cooldownHours * 60 * 60
                print("ℹ️ [AppOpenAdManager] Dynamic configuration loaded successfully. Cooldown is \(config.cooldownHours) hours.")
                
                self.loadAd()
            } catch {
                print("⚠️ [AppOpenAdManager] Failed to fetch remote configuration: \(error.localizedDescription). Falling back to test credentials.")
                self.loadAd()
            }
        }
    }
    
    private func loadAd() {
        if UserDefaults.standard.bool(forKey: "is_user_pro") {
            self.appOpenAd = nil
            return
        }
        guard !isLoadingAd && appOpenAd == nil else { return }
        
        isLoadingAd = true
        print("ℹ️ [AppOpenAdManager] Loading App Open Ad with Unit ID: \(adUnitId)")
        
        AppOpenAd.load(with: adUnitId, request: Request()) { [weak self] ad, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoadingAd = false
                
                if let error = error {
                    print("⚠️ [AppOpenAdManager] App Open Ad failed to load: \(error.localizedDescription)")
                    return
                }
                
                self.appOpenAd = ad
                self.appOpenAd?.fullScreenContentDelegate = self
                print("✅ [AppOpenAdManager] App Open Ad loaded successfully and ready for presentation.")
            }
        }
    }
    
    func showAdIfAvailable() {
        // Disabled per Apple App Store Review Guidelines (Guideline 4 - Design)
        // Apps cannot force users to view an advertisement prior to using the app.
        print("ℹ️ [AppOpenAdManager] App Open Ads are disabled for App Store compliance.")
        self.appOpenAd = nil
    }
    
    // MARK: - FullScreenContentDelegate Callbacks
    
    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) {
        print("✅ [AppOpenAdManager] Ad presented full screen.")
    }
    
    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("⚠️ [AppOpenAdManager] Ad failed to present: \(error.localizedDescription)")
        appOpenAd = nil
        loadAd() // Prefetch next ad
    }
    
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        print("✅ [AppOpenAdManager] Ad dismissed. Updating cooldown timer.")
        appOpenAd = nil
        lastShownTime = Date()
        loadAd() // Prefetch next ad
    }
    
    // MARK: - View Controller Helper
    
    private func getTopMostViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        
        var topController = rootViewController
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }
}
