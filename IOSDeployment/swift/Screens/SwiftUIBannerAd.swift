import SwiftUI
import GoogleMobileAds

/**
 * A highly reusable, premium SwiftUI Banner Ad wrapper component.
 * Bridges GADBannerView (UIKit) into SwiftUI layouts seamlessly.
 */
struct SwiftUIBannerAd: UIViewControllerRepresentable {
    /// The AdMob Banner placement Unit ID. Defaults to the official iOS test banner ID.
    var adUnitId: String = "ca-app-pub-5734863079459748/8749854605" // Official iOS Production Banner ID
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // Standard GADAdSizeBanner is 320x50.
        let adView = GADBannerView(adSize: GADAdSizeBanner)
        adView.adUnitID = adUnitId
        adView.rootViewController = viewController
        adView.delegate = context.coordinator
        
        adView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(adView)
        
        NSLayoutConstraint.activate([
            adView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            adView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            adView.widthAnchor.constraint(equalToConstant: GADAdSizeBanner.size.width),
            adView.heightAnchor.constraint(equalToConstant: GADAdSizeBanner.size.height)
        ])
        
        adView.load(GADRequest())
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // MARK: - AdMob Delegate Coordinator
    class Coordinator: NSObject, GADBannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("🟢 iOS AdMob: Banner loaded successfully.")
        }
        
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("🔴 iOS AdMob: Banner failed to load: \(error.localizedDescription)")
        }
    }
}
