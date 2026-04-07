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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
        }
        // CRITICAL: Refresh user when app returns to foreground.
        // This ensures isPro / isDistributor are up-to-date after a
        // user subscribes on boanalyst.com and returns to the app.
        .onChange(of: scenePhase) { phase in
            if phase == .active, authViewModel.isAuthenticated {
                Task { await authViewModel.refreshUser() }
            }
        }
    }

    private func handleDeepLink(url: URL) {
        guard url.scheme == "boanalyst", url.host == "auth" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value {
            Task { await authViewModel.handleOAuthCallback(token: token) }
        }
    }
}

// MARK: - ContentView (Root Router)

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

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
        }
    }
}

// MARK: - MainTabView
// Netflix/Reader strategy: NO StoreKit, NO Apple IAP.
// showSubscription opens SubscriptionView which redirects to boanalyst.com in Safari.

struct MainTabView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var flockVM = FlockViewModel()

    @State private var showSubscription = false
    @State private var selectedTab = 0

    // IMPORTANT: These are computed from the LIVE currentUser object so they
    // update automatically after refreshUser() is called on foreground return.
    // Bug #1 fix: was using stale closure-captured values from init time.
    private var isDistributor: Bool { authViewModel.currentUser?.isDistributor ?? false }
    private var isPro: Bool         { authViewModel.currentUser?.isPro ?? false }
    private var isAdmin: Bool       { authViewModel.currentUser?.isAdmin ?? false }

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── Tab 1: Home ────────────────────────────────────
            NavigationStack {
                HomeView(onSubscribeRequired: { showSubscription = true })
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
                InsideTalkView(onSubscribeRequired: { showSubscription = true })
            }
            .tabItem { Label("Inside Talk", systemImage: "eye.fill") }
            .tag(2)
            
            // ── Tab 4: Distributors Hub ────────────────────────────────────
            NavigationStack {
                DistributorsHubView(
                    isUserDistributor: isDistributor,
                    onSubscribeRequired: { showSubscription = true }
                )
            }
            .tabItem { Label("Hub", systemImage: "briefcase.fill") }
            .tag(3)

            // ── Tab 5: Profile ────────────────────────────────────────────
            // Pass isAdmin so admin can see admin controls in Profile
            NavigationStack {
                ProfileView(
                    onSubscribeRequired: { showSubscription = true },
                    isDistributor: isDistributor,
                    isPro: isPro,
                    isAdmin: isAdmin
                )
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
            .tag(4)
        }
        .accentColor(AppTheme.goldPrimary)
        .environmentObject(flockVM)
        // Subscription sheet — Netflix/Reader strategy: no IAP, links to boanalyst.com
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
}

