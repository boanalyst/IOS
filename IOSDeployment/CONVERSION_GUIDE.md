# Screen-by-Screen Conversion Guide: Android → iOS

## Mapping Summary

| Android Screen / Component | iOS Equivalent | Notes |
|---|---|---|
| `MainActivity.kt` | `BoAnalystApp.swift` + `ContentView.swift` | Entry point + root view |
| `BoAnalystNavGraph.kt` | `NavigationStack` + `TabView` | iOS 16+ nav system |
| `LoginScreen.kt` | `LoginView.swift` | Same fields, SwiftUI Form |
| `RegisterScreen.kt` | `RegisterView.swift` | |
| `HomeScreen.kt` | `HomeView.swift` | TabView root |
| `FlockFeedScreen.kt` | `FlockFeedView.swift` | LazyVStack / List |
| `InsideTalkScreen.kt` | `InsideTalkView.swift` | |
| `AnalyticsScreen.kt` | `AnalyticsView.swift` | Charts.framework or Swift Charts |
| `BoxOfficeScreen.kt` | `BoxOfficeView.swift` | |
| `DistributorsHubScreen.kt` | `DistributorsHubView.swift` | |
| `ProfileScreen.kt` | `ProfileView.swift` | |
| `SubscriptionScreen.kt` | `SubscriptionView.swift` | **Must use StoreKit 2 on iOS** |
| `PostDetailScreen.kt` | `PostDetailView.swift` | |
| `BottomNav.kt` | `TabView` with `.tabItem` | |
| `GoldButton.kt` | `GoldButton.swift` | Custom ViewModifier |
| `GlassCard.kt` | `GlassCardStyle.swift` | `.background(.ultraThinMaterial)` |
| `SocialEmbedView.kt` (WebView) | `WebView.swift` (WKWebView wrapper) | |
| `SecurePrefs.kt` | `KeychainManager.swift` | Use `Security` framework |
| `ApiClient.kt` | `APIClient.swift` | URLSession + async/await |
| `AuthViewModel.kt` | `AuthViewModel.swift` | `@Observable` / `ObservableObject` |
| Deep Links (App Links) | Universal Links | `apple-app-site-association` |
| OAuth callback scheme | URL Scheme `boanalyst://` | `onOpenURL` in SwiftUI |
| Razorpay Android SDK | Razorpay iOS SDK (CocoaPods) | |

---

## Key Conceptual Mappings

### Navigation
```
Android:                          iOS:
NavHost / NavController   →   NavigationStack
composable("route")       →   .navigationDestination(for: Route.self)
Bottom nav TabRow         →   TabView { ... .tabItem { } }
popBackStack()            →   dismiss() / path.removeLast()
navController.navigate()  →   path.append(Route.someScreen)
```

### State Management
```
Android:                          iOS:
ViewModel (LiveData/Flow) →   @Observable class / ObservableObject
collectAsState()          →   @StateObject / @EnvironmentObject
LaunchedEffect            →   .task { } / .onAppear { }
remember { mutableStateOf }  →  @State
```

### UI Components
```
Android:                          iOS:
LazyColumn                →   List / LazyVStack
LazyRow                   →   LazyHStack
Column / Row              →   VStack / HStack
Box                       →   ZStack
Spacer()                  →   Spacer()
Text("…")                 →   Text("…")
Button { } label: { }     →   Button("…") { }
Scaffold                  →   NavigationView / NavigationStack
TopAppBar                 →   .navigationTitle + .toolbar
Card                      →   .background(RoundedRectangle…)
CircularProgressIndicator →   ProgressView()
AsyncImage (Coil)         →   AsyncImage(url:) [built-in SwiftUI]
WebView (Accompanist)     →   WKWebView wrapped in UIViewRepresentable
```

### Secure Storage
```
Android:                          iOS:
EncryptedSharedPreferences →  Keychain Services (SecItem APIs)
DataStore Preferences      →  UserDefaults (non-sensitive data)
JWT stored in SecurePrefs  →  JWT stored in Keychain
```

### Permissions
```
Android Manifest           →   Info.plist keys
READ_MEDIA_IMAGES          →   NSPhotoLibraryUsageDescription
POST_NOTIFICATIONS         →   UNUserNotificationCenter.requestAuthorization()
USE_BIOMETRIC              →   LAContext.evaluatePolicy (FaceID/TouchID)
INTERNET                   →   (no declaration needed on iOS)
```

---

## Subscription / Payment — CRITICAL iOS Difference

> ⚠️ **This is the most important difference between Android and iOS.**

### Android (current)
- Uses **Razorpay** for all payments (subscriptions + one-time purchases).
- No Google Play Billing required because the subscription is managed server-side.

### iOS (required by Apple)
Apple's App Store Review Guidelines **Rule 3.1.1** states:

> *"If you want to unlock features or functionality within your app… you must use in-app purchase."*

This means:
- **Pro subscription** → Must go through **StoreKit 2 / Apple IAP**.
- **Distributors subscription** → Must go through **StoreKit 2 / Apple IAP**.
- Apple takes **15%** (small developers / first year) or **30%** commission.
- **Exception**: One-time "exclusive content" purchases may be allowable via Razorpay  
  if the content is also accessible via the website (it is served server-side).  
  Consult Apple's guidelines carefully before using Razorpay for any IAP.

### Action Required
1. Create **Products** in App Store Connect:
   - `com.boanalyst.pro.monthly` — Monthly Pro
   - `com.boanalyst.pro.yearly` — Yearly Pro
   - `com.boanalyst.distributors.yearly` — Distributors Yearly
2. Use **StoreKit 2** (`import StoreKit`) in `SubscriptionView.swift`.
3. Implement server-side **receipt validation** (or use RevenueCat for simplicity).
4. Update the backend to accept Apple IAP receipts as proof of subscription.

---

## Biometric Authentication
```swift
// iOS equivalent of Android USE_BIOMETRIC
import LocalAuthentication

let context = LAContext()
var error: NSError?
if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
    context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: "Authenticate to access BoAnalyst"
    ) { success, authError in
        DispatchQueue.main.async {
            if success { /* proceed */ }
        }
    }
}
```

---

## Social Embed Views (Instagram / X / Twitter)

Both platforms use WKWebView for rendering embeds on iOS, same as Android WebView:

```swift
import WebKit
import SwiftUI

struct SocialEmbedView: UIViewRepresentable {
    let htmlString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        return WKWebView(frame: .zero, configuration: config)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}
```

---

## Lottie Animations

Lottie works on iOS via the `lottie-ios` CocoaPods pod:

```swift
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)
        view.loopMode = .loop
        view.play()
        return view
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {}
}
```

The same `.json` Lottie files from Android (`res/raw/*.json`) work on iOS.

---

## Gold & Black Theme Mapping

The Android Gold/Black theme translates directly to SwiftUI:

| Android Color Token | iOS Value |
|---|---|
| `GoldPrimary` `#FFD700` | `Color(hex: "FFD700")` |
| `GoldDim` `#B8860B` | `Color(hex: "B8860B")` |
| `Background` `#0A0A0A` | `Color(hex: "0A0A0A")` |
| `Surface` `#111111` | `Color(hex: "111111")` |
| `TextPrimary` `#F5F5F5` | `Color(hex: "F5F5F5")` |

Fonts: `Cinzel` for headings, system San Francisco for body (same as Android `Serif`/system).

---

## Screens Not Requiring Change

These aren't platform-specific — logic stays the same, only syntax changes:
- All API calls (same endpoints, same JSON)
- JWT token storage logic (different API, same concept)
- All data models (1:1 mapping from Kotlin data classes to Swift structs)
- All business logic in ViewModels
- Navigation flow (same screen graph)
