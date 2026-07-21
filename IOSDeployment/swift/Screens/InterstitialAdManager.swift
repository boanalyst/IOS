import GoogleMobileAds
import SwiftUI
import UIKit

@MainActor
class InterstitialAdManager: NSObject, FullScreenContentDelegate, ObservableObject {
    private var interstitial: InterstitialAd?
    @Published var isAdLoaded = false
    
    // Production iOS Interstitial ID
    private let adUnitID = "ca-app-pub-5734863079459748/5810802867"
    
    private var onAdDismissed: (() -> Void)?

    override init() {
        super.init()
        loadAd()
    }

    func loadAd() {
        let request = Request()
        InterstitialAd.load(with: adUnitID,
                            request: request) { [weak self] ad, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let error = error {
                    print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                    self.isAdLoaded = false
                    return
                }
                self.interstitial = ad
                self.interstitial?.fullScreenContentDelegate = self
                self.isAdLoaded = true
                print("Interstitial ad loaded successfully.")
            }
        }
    }

    func showAd(from viewController: UIViewController, onDismiss: @escaping () -> Void) {
        print("ℹ️ [InterstitialAdManager] Interstitial Ads are disabled for App Store compliance.")
        // Immediately invoke dismiss callback if one is provided
        onDismiss()
        return
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        print("Ad dismissed.")
        isAdLoaded = false
        onAdDismissed?()
        onAdDismissed = nil
        loadAd() // Preload the next ad
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad failed to present: \(error.localizedDescription)")
        isAdLoaded = false
        onAdDismissed?()
        onAdDismissed = nil
        loadAd() // Try again
    }
}

// SwiftUI Wrapper to easily access the view controller
struct InterstitialAdController {
    @MainActor
    static func showAd(manager: InterstitialAdManager, onDismiss: @escaping () -> Void) {
        // Find the topmost view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            onDismiss()
            return
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        manager.showAd(from: topVC, onDismiss: onDismiss)
    }
}
