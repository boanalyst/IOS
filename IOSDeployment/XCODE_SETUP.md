# Xcode Project Setup & Signing Guide

## Prerequisites

| Requirement | Details |
|---|---|
| Mac | macOS 13 Ventura or later |
| Xcode | Version 15.0 or later (free from Mac App Store) |
| Apple Developer Account | Enrolled in Apple Developer Program ($99/year) |
| Apple ID | Registered at developer.apple.com |

---

## Step 1 — Create the Xcode Project

1. Open **Xcode → File → New → Project**.
2. Select **iOS → App** and click **Next**.
3. Fill in the project settings:

   | Field | Value |
   |---|---|
   | Product Name | BoAnalyst |
   | Team | *(select your Apple Developer team)* |
   | Organization Identifier | `com.boanalyst` |
   | Bundle Identifier | `com.boanalyst.app` |
   | Interface | **SwiftUI** |
   | Language | **Swift** |
   | Minimum Deployments | **iOS 16.0** |

4. Uncheck **Include Tests** for now (add later).
5. Save the project to a folder of your choice (e.g. `~/Developer/BoAnalystIOS`).

---

## Step 2 — Configure Supported Architectures

1. Select the project root in the **Project Navigator**.
2. Go to **Build Settings** tab.
3. Ensure **iOS Deployment Target** = `16.0`.
4. Set **Supported Destinations** to **iPhone** only (iPad can be added later).

---

## Step 3 — Add Dependencies (CocoaPods)

> **Note**: You can also use Swift Package Manager (SPM) for most dependencies.
> CocoaPods is required specifically for the Razorpay iOS SDK.

### Install CocoaPods (if not installed)
```bash
sudo gem install cocoapods
```

### Create a Podfile in the project directory
```bash
cd ~/Developer/BoAnalystIOS
pod init
```

### Edit the Podfile

```ruby
# Podfile
platform :ios, '16.0'
use_frameworks!

target 'BoAnalyst' do
  # ── Payment ──────────────────────────────────────────────────────────────
  pod 'Razorpay-Swift'

  # ── Networking (optional — can use URLSession natively) ───────────────────
  # pod 'Alamofire', '~> 5.8'

  # ── Lottie Animations ────────────────────────────────────────────────────
  pod 'lottie-ios', '~> 4.3'

  # ── Keychain ─────────────────────────────────────────────────────────────
  # pod 'KeychainSwift', '~> 20.0'  # Optional, or use native SecItem APIs
end
```

### Install pods
```bash
pod install
```

> ⚠️ After `pod install`, **always open the `.xcworkspace` file**, not `.xcodeproj`.

---

## Step 4 — Bundle Identifier & App ID

1. Go to [developer.apple.com → Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).
2. Click **+** → **App IDs** → **App**.
3. Set **Bundle ID** to `com.boanalyst.app` (Explicit).
4. Enable these **Capabilities**:
   - ✅ Push Notifications
   - ✅ Associated Domains (for Universal Links)
   - ✅ Sign In with Apple (if you add social login)
   - ❌ **DO NOT enable In-App Purchase** — BoAnalyst uses the Netflix/Reader strategy.
     Subscriptions are purchased on `boanalyst.com` via Safari. Enabling IAP without
     implementing StoreKit will trigger App Store rejection (Guideline 3.1.1).
5. Click **Register**.

---

## Step 5 — Signing Configuration

### Automatic Signing (Recommended for Development)
1. In Xcode, select the project → **Signing & Capabilities** tab.
2. Check ✅ **Automatically manage signing**.
3. Select your **Team** from the dropdown.
4. Xcode will create a provisioning profile automatically.

### Manual Signing (Required for App Store Distribution)
1. Go to **developer.apple.com → Certificates** and create a:
   - **Apple Distribution** certificate.
2. Go to **Profiles** and create a:
   - **App Store** provisioning profile for `com.boanalyst.app`.
3. Download both files and double-click to install in Keychain / Xcode.
4. In Xcode → **Signing & Capabilities**:
   - Uncheck **Automatically manage signing** for the **Release** scheme.
   - Select the **Distribution** certificate and **App Store** profile.

---

## Step 6 — Configure Associated Domains (Universal Links)

Universal Links replace Android's App Links. Add the domain so tapping
`https://boanalyst.com/...` URLs opens the app instead of Safari.

1. In Xcode → **Signing & Capabilities** → **+ Capability** → **Associated Domains**.
2. Add: `applinks:boanalyst.com`
3. On your server, create (or update) the file at:
   ```
   https://boanalyst.com/.well-known/apple-app-site-association
   ```
   Content:
   ```json
   {
     "applinks": {
       "apps": [],
       "details": [
         {
           "appID": "TEAMID.com.boanalyst.app",
           "paths": ["*"]
         }
       ]
     }
   }
   ```
   Replace `TEAMID` with your 10-character Apple Team ID (found in developer.apple.com).

---

## Step 7 — Configure URL Scheme (OAuth Callback)

This replaces the Android custom scheme `boanalyst://auth`.

1. In Xcode → Project → **Info** tab → **URL Types** → **+**.
2. Set:
   - **Identifier**: `com.boanalyst.app`
   - **URL Schemes**: `boanalyst`
3. In `Info.plist`, this adds:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>boanalyst</string>
       </array>
     </dict>
   </array>
   ```
4. In your `BoAnalystApp.swift`, handle the incoming URL in `.onOpenURL { url in ... }`.
   This fires when the OAuth server redirects back to `boanalyst://auth?token=...`.

---

## Step 8 — Privacy Usage Descriptions (Info.plist)

Apple requires purpose strings for every permission. Add these keys to `Info.plist`:

| Key | Value |
|---|---|
| `NSPhotoLibraryUsageDescription` | "BoAnalyst needs access to your photo library to attach images to posts." |
| `NSCameraUsageDescription` | "BoAnalyst needs camera access to take photos for your posts." |
| `NSFaceIDUsageDescription` | "BoAnalyst uses Face ID to securely authenticate your account." |
| `NSUserNotificationsUsageDescription` | "BoAnalyst sends notifications for new posts and updates." |

---

## Step 9 — Build & Run on Simulator

```bash
# Build via Xcode toolbar → Select simulator → Cmd+R
# Or via command line:
xcodebuild -workspace BoAnalyst.xcworkspace \
           -scheme BoAnalyst \
           -sdk iphonesimulator \
           -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
           build
```

---

## Step 10 — Archive for App Store

1. In Xcode, set the scheme to **Any iOS Device (arm64)**.
2. **Product → Archive**.
3. In the **Organizer** window, click **Distribute App**.
4. Select **App Store Connect**.
5. Choose **Upload** (or export for manual upload via Transporter).
6. Follow the wizard — it will validate and upload the build.

---

## Troubleshooting Common Issues

| Issue | Solution |
|---|---|
| "No matching provisioning profile" | Regenerate profile on developer.apple.com |
| "App ID not found" | Register the Bundle ID first (Step 4) |
| pod install fails on M1/M2 Mac | Run `arch -x86_64 pod install` or use `pod install --repo-update` |
| Universal Links not working | Ensure `apple-app-site-association` is served with `Content-Type: application/json` and no redirect |
| Build fails with Razorpay | Ensure you opened `.xcworkspace`, not `.xcodeproj` |
