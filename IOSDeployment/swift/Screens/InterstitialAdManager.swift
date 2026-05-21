import GoogleMobileAds
import SwiftUI
import UIKit

class InterstitialAdManager: NSObject, GADFullScreenContentDelegate, ObservableObject {
    private var interstitial: GADInterstitialAd?
    @Published var isAdLoaded = false
    
    // Production iOS Interstitial ID
    private let adUnitID = "ca-app-pub-5734863079459748/5810802867"
    
    private var onAdDismissed: (() -> Void)?

    override init() {
        super.init()
        loadAd()
    }

    func loadAd() {
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: adUnitID,
                               request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                self?.isAdLoaded = false
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            self?.isAdLoaded = true
            print("Interstitial ad loaded successfully.")
        }
    }

    func showAd(from viewController: UIViewController, onDismiss: @escaping () -> Void) {
        if let interstitial = interstitial, isAdLoaded {
            self.onAdDismissed = onDismiss
            interstitial.present(fromRootViewController: viewController)
        } else {
            print("Ad wasn't ready.")
            // If ad is not ready, proceed with the action immediately
            onDismiss()
            loadAd() // Try to load for next time
        }
    }

    // MARK: - GADFullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad dismissed.")
        isAdLoaded = false
        onAdDismissed?()
        onAdDismissed = nil
        loadAd() // Preload the next ad
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad failed to present: \(error.localizedDescription)")
        isAdLoaded = false
        onAdDismissed?()
        onAdDismissed = nil
        loadAd() // Try again
    }
}

// SwiftUI Wrapper to easily access the view controller
struct InterstitialAdController {
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
