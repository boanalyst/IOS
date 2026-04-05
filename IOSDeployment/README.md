# BoAnalyst iOS — Conversion & App Store Deployment

## Overview

This folder contains everything needed to rebuild **BoAnalyst** as a native
**Swift / SwiftUI** iOS application and submit it to the Apple App Store.

The Android app is built with **Kotlin + Jetpack Compose**, which has no
automatic transpiler to iOS. The conversion strategy is a **clean-room native
port**: re-implement the same features and UI in Swift/SwiftUI, reusing the
same REST API backend.

---

## Folder Structure

```
IOSDeployment/
├── README.md                     ← This file
├── APPSTORE_CHECKLIST.md         ← Full App Store submission checklist
├── CONVERSION_GUIDE.md           ← Screen-by-screen feature mapping
├── XCODE_SETUP.md                ← Xcode project creation + signing guide
├── swift/                        ← Ready-to-paste Swift source files
│   ├── NetworkLayer/
│   │   ├── APIClient.swift
│   │   └── APIEndpoints.swift
│   ├── Models/
│   │   └── Models.swift
│   ├── Auth/
│   │   ├── AuthViewModel.swift
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Home/
│   │   └── HomeView.swift
│   ├── Theme/
│   │   ├── AppTheme.swift
│   │   └── GoldButton.swift
│   └── App/
│       └── BoAnalystApp.swift
└── assets/
    └── AppStoreAssets.md         ← Screenshot & metadata specifications
```

---

## Quick Start for a Mac Developer

1. **Read** `XCODE_SETUP.md` — create the Xcode project and configure signing.
2. **Read** `CONVERSION_GUIDE.md` — understand every screen and its iOS equivalent.
3. **Copy** the `swift/` source files into your Xcode project.
4. **Follow** `APPSTORE_CHECKLIST.md` to prepare for App Store submission.

---

## Tech Stack (iOS)

| Concern | Android (existing) | iOS (target) |
|---|---|---|
| Language | Kotlin | Swift 5.9+ |
| UI Framework | Jetpack Compose | SwiftUI |
| Navigation | Navigation Compose | NavigationStack (iOS 16+) |
| Networking | Retrofit + OkHttp | URLSession / async-await |
| Image Loading | Coil | AsyncImage (built-in) |
| Secure Storage | EncryptedSharedPreferences | Keychain Services |
| Animations | Compose Animation | SwiftUI withAnimation |
| Payment | Razorpay Android SDK | Razorpay iOS SDK (CocoaPods) |
| Deep Links | App Links (assetlinks.json) | Universal Links (apple-app-site-association) |
| OAuth / Auth | Custom scheme `boanalyst://` | Custom scheme `boanalyst://` |
| Minimum OS | Android 5.0 (API 21) | iOS 16.0 |

---

## Important Notes

- **Razorpay iOS SDK** is available as a CocoaPods pod (`pod 'Razorpay-Swift'`).
  The integration flow is nearly identical to Android.
- **Apple In-App Purchase (IAP)** policy: Apple requires subscriptions sold
  inside an iOS app to use **StoreKit 2 / Apple IAP** rather than a third-party
  payment gateway. Razorpay can still be used for one-time purchases IF the
  transaction is for **physical goods or services delivered outside the app**.
  For digital subscription access (Pro/Distributor plans), you **must** use
  Apple IAP and pay Apple's 15-30% commission. Plan accordingly.
- You **must** have an **Apple Developer Program** membership ($99/year USD) to
  submit to the App Store.
- Building requires a **Mac** with Xcode 15+ installed.
