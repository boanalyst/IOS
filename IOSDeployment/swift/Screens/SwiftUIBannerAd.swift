import SwiftUI
import GoogleMobileAds

/**
 * A highly reusable, premium SwiftUI Banner Ad wrapper component.
 * Bridges BannerView (UIKit) into SwiftUI layouts seamlessly.
 */
struct SwiftUIBannerAd: UIViewControllerRepresentable {
    /// The AdMob Banner placement Unit ID. Defaults to the official iOS test banner ID.
    var adUnitId: String = "ca-app-pub-5734863079459748/8749854605" // Official iOS Production Banner ID
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // Standard AdSizeBanner is 320x50.
        let adView = BannerView(adSize: AdSizeBanner)
        adView.adUnitID = adUnitId
        adView.rootViewController = viewController
        adView.delegate = context.coordinator
        
        adView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(adView)
        
        NSLayoutConstraint.activate([
            adView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            adView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            adView.widthAnchor.constraint(equalToConstant: AdSizeBanner.size.width),
            adView.heightAnchor.constraint(equalToConstant: AdSizeBanner.size.height)
        ])
        
        adView.load(Request())
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // MARK: - AdMob Delegate Coordinator
    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("🟢 iOS AdMob: Banner loaded successfully.")
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("🔴 iOS AdMob: Banner failed to load: \(error.localizedDescription)")
        }
    }
}
