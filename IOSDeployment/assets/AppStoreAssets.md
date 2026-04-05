# App Store Assets Specifications

## App Icon

| Size | Usage | File |
|---|---|---|
| 1024×1024 px | App Store listing | `AppIcon-1024.png` |
| 180×180 px | iPhone @3x | `AppIcon-60@3x.png` |
| 120×120 px | iPhone @2x | `AppIcon-60@2x.png` |
| 167×167 px | iPad Pro @2x | `AppIcon-83.5@2x.png` |
| 152×152 px | iPad @2x | `AppIcon-76@2x.png` |
| 87×87 px | iPhone Settings @3x | `AppIcon-29@3x.png` |
| 80×80 px | iPhone Spotlight @2x | `AppIcon-40@2x.png` |
| 60×60 px | iPhone Spotlight @1x | `AppIcon-40@1x.png` |
| 58×58 px | iPhone Settings @2x | `AppIcon-29@2x.png` |
| 40×40 px | iPad Settings @2x | `AppIcon-20@2x.png` |

**Design Requirements:**
- Solid black (#0A0A0A) background
- BoAnalyst "BO" gold lettering centered
- NO rounded corners (Apple applies them)
- NO transparency / alpha channel — PNG with solid background
- Export from the existing `logo.png` (resize + ensure solid background)

---

## Screenshots — iPhone 6.7" (1290 × 2796 px)

Capture these screens on iPhone 15 Pro Max simulator in Xcode:

### Screenshot 1 — Home Screen
- Show greeting header with user name
- Show "Now Playing" movie cards scrolling horizontally
- Show at least one community poll
- Include the live ticker banner

### Screenshot 2 — Box Office Live
- Show the box office table/list with movie names and collection data
- Include the live BMS ticket counter if available
- Gold accent colors prominent

### Screenshot 3 — Analytics / Charts
- Show a movie's box office charts
- Multiple weeks of data visible
- Collection trend line or bar chart

### Screenshot 4 — Flock Feed
- Show 3-4 community posts
- Include pinned post with gold pin icon
- Show like/comment counts

### Screenshot 5 — Inside Talk
- Show exclusive content cards
- Show "Pro" locked content with paywall overlay
- Gold premium aesthetic

### Screenshot 6 — Subscription / Paywall
- Show the three subscription tiers
- Pricing clearly visible
- "Subscribe" gold button prominent

### Screenshot 7 — Profile
- Show user avatar, name, email
- Show subscription status badge ("PRO" in gold)
- Clean profile layout

### Screenshot 8 — Login Screen
- Gold logo at top
- Email/password fields
- "Sign In" gold button
- Optional: overlay text "India's #1 Box Office Platform"

---

## Screenshot Guidelines

- Use **light** or **dark** device frames (optional, Apple allows frameless screenshots)
- Ensure status bar shows full signal, WiFi, and full battery
- If adding marketing text overlay, use this approach:
  - Font: Cinzel or similar serif for headlines
  - Color: Gold (#FFD700) on dark overlay
  - Keep text in upper 30% of screenshot

---

## App Preview Video (Optional)

- **Duration**: 15–30 seconds
- **Format**: H.264 or HEVC
- **Resolution**: Must match screenshot size (1290×2796 for 6.7" iPhone)
- **Suggested flow**:
  1. Open app → quick login (2s)
  2. Home screen pan (3s)
  3. Scroll through box office data (4s)
  4. Tap on analytics chart (3s)
  5. Open Flock Feed, scroll (4s)
  6. Show subscription screen (3s)
  7. Return to home with "BoAnalyst" branding (3s)

---

## Marketing Text (for Screenshot Overlays)

```
Headline (short): "India's Box Office, In Your Pocket"
Subheadline: "Live collections • Exclusive insights • Film community"

Screen 1 overlay: "Real-Time Box Office Data"
Screen 2 overlay: "Live Ticket Sales Tracking"  
Screen 3 overlay: "Deep Analytics & Trends"
Screen 4 overlay: "Join The Flock Community"
Screen 5 overlay: "Exclusive Industry Insights"
Screen 6 overlay: "Go Pro — Unlock Everything"
```

---

## App Store Connect Required Assets Checklist

- [ ] App Icon 1024×1024 px PNG
- [ ] 3 screenshots minimum for iPhone 6.7"
- [ ] 3 screenshots minimum for iPhone 6.5"
- [ ] 3 screenshots minimum for iPhone 5.5"
- [ ] Privacy Policy URL (must be live)
- [ ] Support URL (can be boanalyst.com/contact or boanalyst.com)
- [ ] Marketing URL (optional, use boanalyst.com)
