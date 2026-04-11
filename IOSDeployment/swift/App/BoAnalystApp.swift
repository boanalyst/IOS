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

    // Merges Apple IAP entitlements + backend user flags
    // so both Apple IAP subscribers and legacy web subscribers are recognised
    private var isDistributor: Bool { iapManager.isDistributorActive || (authViewModel.currentUser?.isDistributor ?? false) }
    private var isPro: Bool         { iapManager.isProActive || (authViewModel.currentUser?.isPro ?? false) || isDistributor }
    private var isAdmin: Bool       { authViewModel.currentUser?.isAdmin ?? false }

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── Tab 1: Home ────────────────────────────────────
            NavigationStack {
                HomeView(onSubscribeRequired: { selectedTab = 4 })
            }
            .navigationBarHidden(true)
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)

            // ── Tab 2: Flock Feed ──────────────────────────────────────────
            // Box Office tab DISABLED per product decision (bug #4).
            // Flock is now Tab 2.
            NavigationStack {
                FlockFeedView()
            }
            .tabItem { Label("Flock", systemImage: "bubble.left.and.bubble.right.fill") }
            .tag(1)

            // ── Tab 3: Inside Talk ─────────────────────────────────────────
            NavigationStack {
                InsideTalkView(onSubscribeRequired: { selectedTab = 4 })
            }
            .tabItem { Label("Inside Talk", systemImage: "eye.fill") }
            .tag(2)
            
            // ── Tab 4: Distributors Hub ────────────────────────────────────
            NavigationStack {
                DistributorsHubView(
                    isUserDistributor: isDistributor,
                    onSubscribeRequired: { selectedTab = 4 }
                )
            }
            .tabItem { Label("Hub", systemImage: "briefcase.fill") }
            .tag(3)

            // ── Tab 5: Subscription ────────────────────────────────────────
            NavigationStack {
                SubscriptionView()
            }
            .tabItem { Label("Subscribe", systemImage: "star.fill") }
            .tag(4)

            // ── Tab 6: Profile ────────────────────────────────────────────
            // Pass isAdmin so admin can see admin controls in Profile
            NavigationStack {
                ProfileView(
                    onSubscribeRequired: { selectedTab = 4 },
                    isDistributor: isDistributor,
                    isPro: isPro,
                    isAdmin: isAdmin
                )
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
            .tag(5)
        }
        .accentColor(AppTheme.goldPrimary)
        .environmentObject(flockVM)
    }
}

