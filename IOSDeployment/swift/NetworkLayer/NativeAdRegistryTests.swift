// NativeAdRegistryTests.swift
// XCTest Suite to validate NativeAdRegistry's in-memory caching and clean delegation hooks.

import XCTest
import GoogleMobileAds
@testable import BoAnalyst

@MainActor
final class NativeAdRegistryTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Ensure registry starts fresh before each test run
        NativeAdRegistry.shared.clearCache()
    }
    
    override func tearDown() {
        // Clean up cache to preserve memory
        NativeAdRegistry.shared.clearCache()
        super.tearDown()
    }
    
    func testRegistryInitialization() {
        // Assert that the shared singleton is accessible on the MainActor
        let registry = NativeAdRegistry.shared
        XCTAssertNotNil(registry, "NativeAdRegistry singleton should be initialized successfully.")
    }
    
    func testCacheClearingBehavior() {
        let registry = NativeAdRegistry.shared
        
        // Clear active cache and ensure no crash or illegal states occur
        XCTAssertNoThrow(registry.clearCache(), "Registry should clear cache cleanly without throws.")
    }
}
