// BoAnalystApp.swift — UPDATED v3
// Entry point — mirrors Android's MainActivity + BoAnalystApp.kt
// Tabs: Home | BoxOffice | Flock | Inside Talk | Profile
// DistributorsHub is accessed via Profile tab (drawer-style, same as some Android nav patterns)

import SwiftUI

// MARK: - ThemeManager
class ThemeManager: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = true
}

@main
struct BoAnalystApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var iapManager = IAPManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let cache = URLCache(memoryCapacity: 50_000_000, diskCapacity: 200_000_000, diskPath: "BoAnalystImageCache")
        URLCache.shared = cache
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .environmentObject(iapManager)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
        }
        // Refresh user + IAP status when app returns to foreground
        .onChange(of: scenePhase) { phase in
            if phase == .active, authViewModel.isAuthenticated {
                Task {
                    await authViewModel.refreshUser()
                    await iapManager.refreshSubscriptionStatus()
                }
            }
        }
    }

    private func handleDeepLink(url: URL) {
        // SECURITY: Strictly validate scheme + host before processing any token.
        // This prevents other apps from injecting tokens via custom URL schemes.
        guard url.scheme == "boanalyst", url.host == "auth" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let rawToken = components?.queryItems?.first(where: { $0.name == "token" })?.value,
              !rawToken.isEmpty,
              rawToken.count <= APIConfig.maxTokenLength,
              // SECURITY: JWT must be exactly 3 non-empty base64url-encoded segments
              rawToken.components(separatedBy: ".").count == 3,
              rawToken.components(separatedBy: ".").allSatisfy({ !$0.isEmpty }) else {
            return  // Discard malformed or suspiciously large tokens silently
        }
        Task { await authViewModel.handleOAuthCallback(token: rawToken) }
    }
}

// MARK: - ContentView (Root Router)

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var iapManager: IAPManager

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                NavigationStack {
                    LoginView()
                }
            }
        }
        .task {
            await authViewModel.checkSavedToken()
            // Refresh IAP entitlements from Apple on launch
            await iapManager.refreshSubscriptionStatus()
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var iapManager: IAPManager
    @StateObject private var flockVM = FlockViewModel()

    @State private var selectedTab = 0

    // Backend is the sole source of truth for subscription status.
    // StoreKit currentEntitlements returns old transactions from previous
    // accounts, giving every new user distributor/pro access incorrectly.
    // StoreKit is still used for purchase/restore in IAPManager.
    private var isDistributor: Bool { authViewModel.currentUser?.isDistributor ?? false }
    private var isPro: Bool         { authViewModel.currentUser?.isPro ?? false || isDistributor }
    private var isAdmin: Bool       { authViewModel.currentUser?.isAdmin ?? false }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                NavigationStack {
                    HomeView(onSubscribeRequired: { selectedTab = 5 })
                }
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

                NavigationStack {
                    BuzzBoardView()
                }
                .opacity(selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(selectedTab == 1)

                NavigationStack {
                    FlockFeedView()
                }
                .opacity(selectedTab == 2 ? 1 : 0)
                .allowsHitTesting(selectedTab == 2)

                NavigationStack {
                    InsideTalkView(onSubscribeRequired: { selectedTab = 5 })
                }
                .opacity(selectedTab == 3 ? 1 : 0)
                .allowsHitTesting(selectedTab == 3)
                
                NavigationStack {
                    DistributorsHubView(
                        isUserDistributor: isDistributor,
                        onSubscribeRequired: { selectedTab = 5 }
                    )
                }
                .opacity(selectedTab == 4 ? 1 : 0)
                .allowsHitTesting(selectedTab == 4)

                NavigationStack {
                    SubscriptionView()
                }
                .opacity(selectedTab == 5 ? 1 : 0)
                .allowsHitTesting(selectedTab == 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Tab Bar (Responsive, No empty space)
            HStack(spacing: 0) {
                Spacer()
                TabBarItem(icon: "house.fill", title: "Home", isSelected: selectedTab == 0) { selectedTab = 0 }
                Spacer()
                TabBarItem(icon: "bubble.left.and.bubble.right.fill", title: "Flock", isSelected: selectedTab == 2) { selectedTab = 2 }
                Spacer()
                TabBarItem(icon: "flame.fill", title: "Buzz", isSelected: selectedTab == 1) { selectedTab = 1 }
                Spacer()
                TabBarItem(icon: "eye.fill", title: "Inside", isSelected: selectedTab == 3) { selectedTab = 3 }
                Spacer()
                TabBarItem(icon: "briefcase.fill", title: "Hub", isSelected: selectedTab == 4) { selectedTab = 4 }
                Spacer()
                TabBarItem(icon: "star.fill", title: "Pro", isSelected: selectedTab == 5) { selectedTab = 5 }
                Spacer()
            }
            .padding(.vertical, 12)
            .background(AppTheme.surface)
            .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.surfaceVariant), alignment: .top)
        }
        .environmentObject(flockVM)
        .sheet(isPresented: $authViewModel.showProfileSheet) {
            NavigationStack {
                ProfileView(
                    onSubscribeRequired: {
                        authViewModel.showProfileSheet = false
                        selectedTab = 5
                    },
                    isDistributor: isDistributor,
                    isPro: isPro,
                    isAdmin: isAdmin
                )
            }
        }
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? AppTheme.goldPrimary : AppTheme.textSecondary)
        }
    }
}

