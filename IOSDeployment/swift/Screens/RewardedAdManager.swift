import GoogleMobileAds
import SwiftUI
import UIKit

class RewardedAdManager: NSObject, GADFullScreenContentDelegate, ObservableObject {
    private var rewardedAd: GADRewardedAd?
    @Published var isAdLoaded = false
    
    // Production iOS Rewarded Ad Unit ID
    private let adUnitID = "ca-app-pub-5734863079459748/9414850424"
    
    private var onRewardEarned: (() -> Void)?

    override init() {
        super.init()
        loadAd()
    }

    func loadAd() {
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: adUnitID,
                           request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load rewarded ad with error: \(error.localizedDescription)")
                self?.isAdLoaded = false
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
            self?.isAdLoaded = true
            print("Rewarded ad loaded successfully.")
        }
    }

    func showAd(from viewController: UIViewController, onRewardEarned: @escaping () -> Void) {
        if let rewardedAd = rewardedAd, isAdLoaded {
            self.onRewardEarned = onRewardEarned
            rewardedAd.present(fromRootViewController: viewController) {
                // User earned reward
                print("User earned reward.")
                self.onRewardEarned?()
                self.onRewardEarned = nil
            }
        } else {
            print("Rewarded Ad wasn't ready.")
            // Allow if it fails to load
            onRewardEarned()
            loadAd()
        }
    }

    // MARK: - GADFullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Rewarded Ad dismissed.")
        isAdLoaded = false
        // We only trigger success on the reward block, not here, to enforce watching
        // But if we want to handle early dismissal without reward, we can do it.
        // For strict enforcement, we only call the callback in the present block.
        // Wait, if they dismiss early, they don't get the reward and the UI doesn't progress.
        loadAd() // Preload the next ad
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Rewarded Ad failed to present: \(error.localizedDescription)")
        isAdLoaded = false
        // Since it failed to present (not the user's fault), let them through
        onRewardEarned?()
        onRewardEarned = nil
        loadAd()
    }
}

struct RewardedAdController {
    static func showAd(manager: RewardedAdManager, onRewardEarned: @escaping () -> Void) {
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
        
        manager.showAd(from: currentVC, onRewardEarned: onRewardEarned)
    }
}
