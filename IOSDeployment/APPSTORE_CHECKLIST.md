# App Store Submission Checklist

## Phase 1 — Apple Developer Setup

- [ ] Enroll in **Apple Developer Program** at developer.apple.com ($99/year USD)
- [ ] Register **App ID** `com.boanalyst.app` with required capabilities
- [ ] Create **Distribution Certificate** (Apple Distribution)
- [ ] Create **App Store Provisioning Profile** for `com.boanalyst.app`
- [ ] Set up **App Store Connect** account at appstoreconnect.apple.com

---

## Phase 2 — App Store Connect — Create App Record

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Click **My Apps → +** → **New App**
3. Fill in:

   | Field | Value |
   |---|---|
   | Platform | iOS |
   | Name | BoAnalyst |
   | Primary Language | English (U.S.) |
   | Bundle ID | com.boanalyst.app |
   | SKU | BOANALYST-IOS-001 |
   | User Access | Full Access |

---

## Phase 3 — App Information

### Basic Info
- [ ] **App Name**: BoAnalyst (max 30 characters)
- [ ] **Subtitle**: Box Office & Film Industry Insights (max 30 characters)
- [ ] **Privacy Policy URL**: `https://boanalyst.com/privacy` (REQUIRED)
- [ ] **Category**: Entertainment → News (Primary), Finance (Secondary)
- [ ] **Content Rights**: Original content

### Age Rating
- [ ] Complete the questionnaire in App Store Connect
- [ ] Suggested rating: **4+** (no objectionable content)

---

## Phase 4 — App Store Listing (Localisation)

### Description (up to 4,000 characters)
```
BoAnalyst is India's premier Box Office intelligence platform for
film enthusiasts, industry professionals, and distributors.

FEATURES:
• Live Box Office Tracking — Real-time ticket sales and collection data
• Flock Feed — Community posts, discussions, and polls
• Inside Talk — Exclusive industry insights and analysis
• Distributors Hub — Dedicated space for film distributors
• Analytics — Deep-dive charts and trends for any movie
• Pro Membership — Unlock premium content and exclusive reports

Built for the pulse of Bollywood and Indian cinema.
```

### Keywords (100 characters max, comma-separated)
```
box office,bollywood,film,movies,ticket sales,cinema,analytics,entertainment,india
```

### Promotional Text (up to 170 characters, can change without new review)
```
Track real-time box office collections, discover exclusive industry insights, and join India's film community.
```

### What's New (for version 1.0)
```
Welcome to BoAnalyst on iOS! Track live box office data, read exclusive industry insights, and connect with the film community.
```

---

## Phase 5 — Screenshots (MANDATORY)

Apple requires screenshots for every supported device class.

### Required Device Screenshots

| Device | Resolution | Required |
|---|---|---|
| iPhone 6.7" Display (iPhone 15 Pro Max) | 1290 × 2796 px | ✅ YES |
| iPhone 6.5" Display (iPhone 14 Plus) | 1284 × 2778 px | ✅ YES |
| iPhone 5.5" Display (iPhone 8 Plus) | 1242 × 2208 px | ✅ YES |
| iPad Pro 12.9" (6th gen) | 2048 × 2732 px | If supporting iPad |

### Screenshot Themes to Capture (5-10 per device)

1. **Home Screen** — Movie cards, polls, trending content
2. **Box Office** — Live data, collection charts
3. **Flock Feed** — Community posts
4. **Inside Talk** — Exclusive content
5. **Subscription/Pro** — Paywall screen
6. **Analytics** — Charts and movie breakdown
7. **Profile** — User profile page
8. **Login** — Onboarding / login screen

> 💡 Use Xcode Simulator to take screenshots: `Device → Take Screenshot` or `Cmd+S`

### App Preview Video (optional but recommended)
- Format: H.264 or HEVC
- Duration: 15–30 seconds
- No audio required (but recommended)

---

## Phase 6 — App Icon

Apple requires a single **1024 × 1024 px** PNG (no alpha/transparency, no rounded corners — Apple applies them automatically).

- [ ] Export the BoAnalyst logo at 1024×1024 px
- [ ] Ensure it has a solid black background (matches app theme)
- [ ] No transparency
- [ ] Upload to App Store Connect under **App Information → App Icon**

Xcode also needs the icon in the **AppIcon** asset catalog:
- Add all required sizes (20pt, 29pt, 40pt, 60pt, 76pt, 83.5pt, 1024pt)
- Or use a tool like [MakeAppIcon](https://makeappicon.com) to generate all sizes from 1024px master.

---

## Phase 7 — Subscription Strategy: Netflix/Reader Route ✅

> **No App Store IAP required.** BoAnalyst uses the "Reader App" exemption.
> All subscriptions are purchased on `https://boanalyst.com/#subscription` via Razorpay.
> Apple's commission = **₹0**.

### What this means:
- The iOS app shows a beautiful `SubscriptionView.swift` with plan info.
- The **"Subscribe" button opens Safari** → `https://boanalyst.com/#subscription`.
- The user pays via Razorpay on the website (same as Android).
- After payment, the user logs back into the app — the server JWT reflects their `is_pro: true` status.
- **No StoreKit. No Apple IAP products. Zero Apple commission.**

### Apple Policy Reference
App Store Review Guideline **3.1.3(a) — "Reader" Apps**:
> *"If your app is a reader app that provides previously purchased content or content subscriptions… you are not required to use in-app purchase."*

BoAnalyst qualifies as a reader/media app because content (articles, posts, analytics) is
purchased/accessed via the website and consumed in the app.

### Action Required
- [ ] Apply for the **Reader App entitlement** at: https://developer.apple.com/contact/request/link-account-web
- [ ] Fill in the form — select **"Reader App"** and list `https://boanalyst.com/#subscription` as the purchase URL.
- [ ] Apple typically approves within 2-3 business days.
- [ ] Once approved, the external link in `SubscriptionView.swift` is fully compliant.

> ⚠️ Without the Reader entitlement approved, Apple may still flag the external payment link.
> Apply for it **before** submitting to review.

---

## Phase 8 — Privacy & Data Usage (App Privacy — "Nutrition Label")

Apple requires you to declare all data collected. Fill in the App Privacy section in App Store Connect:

| Data Type | Collected? | Used For | Linked to User? |
|---|---|---|---|
| Name | Yes | Account (required) | Yes |
| Email Address | Yes | Account (required) | Yes |
| Photos or Videos | Yes | User content uploads | Yes |
| Purchase History | Yes | Subscription status | Yes |
| Identifiers (User ID) | Yes | Analytics, app func | Yes |
| Crash Data | Yes (if using error tracking) | App Improvement | No |
| Browsing History | No | — | — |
| Location | No | — | — |

- [ ] Complete the App Privacy questionnaire in App Store Connect
- [ ] Ensure Privacy Policy URL is live at `https://boanalyst.com/privacy`

---

## Phase 9 — Review Notes

When submitting for review, add these notes for the App Review team:

```
Test Account:
Email: review@boanalyst.com
Password: AppleReview2025!

Notes:
- The app requires an account to access content (standard for media platforms)
- Subscription features can be tested using the provided test account (already has Pro access)
- The "Box Office" section shows real-time Indian film industry data
- Payment testing: Use Sandbox test accounts in the provided credentials
- The app handles OAuth via a custom URL scheme (boanalyst://) for social login
```

- [ ] Create a dedicated **App Review test account** on your backend
- [ ] Ensure the test account has **Pro access** pre-activated so reviewers can see all features
- [ ] Add the test credentials in the **App Review Information** section

---

## Phase 10 — Build Upload & Submit

1. In Xcode: **Product → Archive**
2. In Organizer: **Distribute App → App Store Connect → Upload**
3. Wait for build to process (~15 minutes) in App Store Connect
4. In App Store Connect → **TestFlight**:
   - [ ] Test internally with your team first
   - [ ] Fix any crashes from TestFlight logs
5. In App Store Connect → **App Store**:
   - [ ] Select the build
   - [ ] Fill in all metadata above
   - [ ] Click **Submit for Review**

---

## Phase 11 — After App Review

- **Approval Time**: Usually 1-3 business days (can be faster)
- **If Rejected**: Apple provides detailed rejection reasons; address them and resubmit
- **Release Options**:
  - Automatically release after approval
  - Manually release (gives you control of the launch date)
  - Phased release (roll out to 1% → 2% → 5% → 10% → 20% → 50% → 100% over 7 days)

---

## Common Rejection Reasons (Pre-empt These)

| Rejection Reason | Prevention |
|---|---|
| 2.1 — App completeness | Ensure all features work; no placeholder screens |
| 3.1.1 — Payment via IAP required | Covered by Reader App entitlement (apply first!) |
| 5.1.1 — Privacy policy missing | Ensure privacy URL is live |
| 4.3 — Spam/duplicates | Ensure app has unique value vs. website |
| 2.5.4 — Background location | Don't declare location if not used |
| 1.2 — User info required without justification | Only ask for email/name that you actually use |

---

## Timeline Estimate

| Phase | Estimated Time |
|---|---|
| Xcode project setup + CocoaPods | 1 day |
| Swift port of networking + models | 2-3 days |
| UI screens (SwiftUI) | 1-2 weeks |
| Reader App entitlement approval | 2-3 days |
| Testing + bug fixes | 1 week |
| App Store Connect setup + screenshots | 2-3 days |
| Apple Review | 1-3 days |
| **Total Estimate** | **3-5 weeks** |
