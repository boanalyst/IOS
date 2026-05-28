import GoogleMobileAds
import SwiftUI
import UIKit

@MainActor
class RewardedAdManager: NSObject, FullScreenContentDelegate, ObservableObject {
    private var rewardedAd: RewardedAd?
    @Published var isAdLoaded = false
    
    // Production iOS Rewarded Ad Unit ID
    private let adUnitID = "ca-app-pub-5734863079459748/9414850424"
    
    private var onRewardEarned: (() -> Void)?

    override init() {
        super.init()
        loadAd()
    }

    func loadAd() {
        let request = Request()
        RewardedAd.load(with: adUnitID,
                        request: request) { [weak self] ad, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let error = error {
                    print("Failed to load rewarded ad with error: \(error.localizedDescription)")
                    self.isAdLoaded = false
                    return
                }
                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isAdLoaded = true
                print("Rewarded ad loaded successfully.")
            }
        }
    }

    private var onDismissedWithoutReward: (() -> Void)?

    func showAd(from viewController: UIViewController,
                onRewardEarned: @escaping () -> Void,
                onDismissedWithoutReward: (() -> Void)? = nil) {
        if let rewardedAd = rewardedAd, isAdLoaded {
            self.onRewardEarned = onRewardEarned
            self.onDismissedWithoutReward = onDismissedWithoutReward
            rewardedAd.present(from: viewController) {
                // User earned reward (watched full ad)
                print("User earned reward.")
                self.onRewardEarned?()
                self.onRewardEarned = nil
                self.onDismissedWithoutReward = nil
            }
        } else {
            print("Rewarded Ad wasn't ready.")
            // Allow if it fails to load (not the user's fault)
            onRewardEarned()
            loadAd()
        }
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        print("Rewarded Ad dismissed.")
        isAdLoaded = false
        if onRewardEarned != nil {
            // User dismissed early without earning — DON'T unlock content
            print("User dismissed rewarded ad early — no reward granted.")
            onDismissedWithoutReward?()
        }
        // Clean up
        onRewardEarned = nil
        onDismissedWithoutReward = nil
        loadAd() // Preload the next ad
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Rewarded Ad failed to present: \(error.localizedDescription)")
        isAdLoaded = false
        // Since it failed to present (not the user's fault), let them through
        onRewardEarned?()
        onRewardEarned = nil
        onDismissedWithoutReward = nil
        loadAd()
    }
}

struct RewardedAdController {
    @MainActor
    static func showAd(manager: RewardedAdManager,
                       onRewardEarned: @escaping () -> Void,
                       onDismissedWithoutReward: (() -> Void)? = nil) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Could not find root view controller to present rewarded ad.")
            onRewardEarned()
            return
        }
        
        var currentVC = rootViewController
        while let presentedVC = currentVC.presentedViewController {
            currentVC = presentedVC
        }
        
        manager.showAd(from: currentVC, onRewardEarned: onRewardEarned, onDismissedWithoutReward: onDismissedWithoutReward)
    }
}
