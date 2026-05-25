// NativeAdRegistry.swift
// A thread-safe, MainActor-bound centralized cache for loaded AdMob Native Ads.
// Prevents redundant ad loading, request spamming, and scrolling jank in SwiftUI.

import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class NativeAdRegistry: NSObject {
    static let shared = NativeAdRegistry()
    
    private var cache: [String: GADNativeAd] = [:]
    private var loaders: [String: GADAdLoader] = [:]
    private var delegates: [String: NativeAdDelegateWrapper] = [:]
    private var pendingCallbacks: [String: [(GADNativeAd) -> Void]] = [:]
    
    private override init() {
        super.init()
    }
    
    /// Clears the entire cached registry (useful on pull-to-refresh).
    func clearCache() {
        cache.removeAll()
        loaders.removeAll()
        delegates.removeAll()
        pendingCallbacks.removeAll()
        print("ℹ️ [NativeAdRegistry] Cache cleared successfully.")
    }
    
    /// Retrieves or loads a native ad for a specific unique cache key.
    func getAd(forIndex index: Int, listName: String, adUnitId: String, completion: @escaping (GADNativeAd) -> Void) {
        let cacheKey = "\(listName)-\(index)-\(adUnitId)"
        
        // 1. Return cached ad if present
        if let cachedAd = cache[cacheKey] {
            completion(cachedAd)
            return
        }
        
        // 2. Queue completion if already loading
        if loaders[cacheKey] != nil {
            pendingCallbacks[cacheKey, default: []].append(completion)
            return
        }
        
        // 3. Start a new load request
        guard let rootController = getTopMostViewController() else {
            print("⚠️ [NativeAdRegistry] Unable to resolve topmost view controller for loading.")
            return
        }
        
        let loader = GADAdLoader(
            adUnitID: adUnitId,
            rootViewController: rootController,
            adTypes: [.native],
            options: nil
        )
        
        let delegate = NativeAdDelegateWrapper(cacheKey: cacheKey)
        
        loaders[cacheKey] = loader
        delegates[cacheKey] = delegate
        pendingCallbacks[cacheKey] = [completion]
        
        loader.delegate = delegate
        loader.load(GADRequest())
        print("ℹ️ [NativeAdRegistry] Started loading ad for key: \(cacheKey)")
    }
    
    fileprivate func didReceiveAd(_ ad: GADNativeAd, for key: String) {
        cache[key] = ad
        loaders[key] = nil
        delegates[key] = nil
        if let callbacks = pendingCallbacks[key] {
            for callback in callbacks {
                callback(ad)
            }
        }
        pendingCallbacks[key] = nil
        print("✅ [NativeAdRegistry] Successfully loaded and cached ad for key: \(key)")
    }
    
    fileprivate func didFailToReceiveAd(for key: String) {
        loaders[key] = nil
        delegates[key] = nil
        pendingCallbacks[key] = nil
        print("⚠️ [NativeAdRegistry] Failed to load ad for key: \(key)")
    }
    
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

// MARK: - NativeAdDelegateWrapper

private class NativeAdDelegateWrapper: NSObject, GADNativeAdLoaderDelegate {
    let cacheKey: String
    
    init(cacheKey: String) {
        self.cacheKey = cacheKey
    }
    
    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        Task { @MainActor in
            NativeAdRegistry.shared.didReceiveAd(nativeAd, for: cacheKey)
        }
    }
    
    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            NativeAdRegistry.shared.didFailToReceiveAd(for: cacheKey)
        }
    }
}
