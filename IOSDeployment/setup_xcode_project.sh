#!/usr/bin/env bash
# =============================================================================
# setup_xcode_project.sh
# Run this script on a Mac (macOS 13+, Xcode 15+) to scaffold the BoAnalyst
# Xcode project from the swift/ source files in this IOSDeployment folder.
#
# Usage:
#   chmod +x setup_xcode_project.sh
#   ./setup_xcode_project.sh
#
# After running:
#   cd BoAnalystXcode
#   open BoAnalyst.xcodeproj   ← Xcode resolves SPM packages automatically
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="BoAnalyst"
BUNDLE_ID="com.boanalyst.app"
DEPLOYMENT_TARGET="16.0"
PROJECT_DIR="$SCRIPT_DIR/BoAnalystXcode"
SWIFT_SRC="$SCRIPT_DIR/swift"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " BoAnalyst iOS — Xcode Project Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Check prerequisites ────────────────────────────────────────────────────
if ! command -v xcodebuild &> /dev/null; then
    echo "❌  Xcode not found. Install Xcode 15+ from the Mac App Store."
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1 | awk '{print $2}')
echo "✅  Xcode $XCODE_VERSION found"

# ── Create project directory structure ────────────────────────────────────
echo ""
echo "📁  Creating project directory: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME"

# ── Copy Swift source files ────────────────────────────────────────────────
echo "📋  Copying Swift source files..."

# Flatten all swift files into the project's source folder
find "$SWIFT_SRC" -name "*.swift" | while read -r file; do
    cp "$file" "$PROJECT_DIR/$PROJECT_NAME/"
    echo "    ✓ $(basename "$file")"
done

# ── Copy Info.plist ────────────────────────────────────────────────────────
echo "📋  Copying Info.plist..."
cp "$SCRIPT_DIR/Info.plist" "$PROJECT_DIR/$PROJECT_NAME/Info.plist"

# ── Copy ExportOptions plists ──────────────────────────────────────────────
cp "$SCRIPT_DIR/ExportOptions-AppStore.plist" "$PROJECT_DIR/"
cp "$SCRIPT_DIR/ExportOptions-AdHoc.plist"    "$PROJECT_DIR/"

# ── Create Assets.xcassets ────────────────────────────────────────────────
echo "📁  Creating Assets.xcassets..."
ASSETS_DIR="$PROJECT_DIR/$PROJECT_NAME/Assets.xcassets"
mkdir -p "$ASSETS_DIR"

# Contents.json for root
cat > "$ASSETS_DIR/Contents.json" <<'JSON'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

# AppIcon placeholder
mkdir -p "$ASSETS_DIR/AppIcon.appiconset"
cat > "$ASSETS_DIR/AppIcon.appiconset/Contents.json" <<'JSON'
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "    ⚠️  Add your 1024×1024 AppIcon.png to:"
echo "        $ASSETS_DIR/AppIcon.appiconset/"

# Logo
mkdir -p "$ASSETS_DIR/Logo.imageset"
cat > "$ASSETS_DIR/Logo.imageset/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "universal", "filename" : "Logo.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
if [ -f "$SCRIPT_DIR/assets/Logo.png" ]; then
    cp "$SCRIPT_DIR/assets/Logo.png" "$ASSETS_DIR/Logo.imageset/Logo.png"
fi

# AccentColor placeholder
mkdir -p "$ASSETS_DIR/AccentColor.colorset"
cat > "$ASSETS_DIR/AccentColor.colorset/Contents.json" <<'JSON'
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.000", "green" : "0.843", "red" : "1.000" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

# ── Generate project.yml with SPM packages (no CocoaPods) ────────────────
echo ""
echo "⚙️   Generating project.yml for XcodeGen (with SPM packages)..."

cat > "$PROJECT_DIR/project.yml" <<YAML
name: $PROJECT_NAME
options:
  bundleIdPrefix: com.boanalyst
  deploymentTarget:
    iOS: "$DEPLOYMENT_TARGET"
  createIntermediateGroups: true
packages:
  Lottie:
    url: https://github.com/airbnb/lottie-spm.git
    from: 4.5.0
  GoogleMobileAds:
    url: https://github.com/googleads/swift-package-manager-google-mobile-ads.git
    from: 11.0.0
  GoogleMobileAdsMediationFacebook:
    url: https://github.com/googleads/swift-package-manager-google-mobile-ads-mediation-facebook.git
    from: 6.17.0
settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_ID
    MARKETING_VERSION: "1.1.8"
    CURRENT_PROJECT_VERSION: "1"
    SWIFT_VERSION: "5.9"
    IPHONEOS_DEPLOYMENT_TARGET: "$DEPLOYMENT_TARGET"
    CODE_SIGN_STYLE: Automatic
    INFOPLIST_FILE: $PROJECT_NAME/Info.plist
    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    DEVELOPMENT_TEAM: ""
    DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
targets:
  $PROJECT_NAME:
    type: application
    platform: iOS
    sources:
      - path: $PROJECT_NAME
        excludes:
          - "**/*.md"
          - "**/*.plist"
    resources:
      - path: $PROJECT_NAME/Assets.xcassets
      - path: $PROJECT_NAME/Info.plist
    dependencies:
      - package: Lottie
      - package: GoogleMobileAds
      - package: GoogleMobileAdsMediationFacebook
    settings:
      base:
        PRODUCT_NAME: $PROJECT_NAME
        OTHER_LDFLAGS:
          - -ObjC
    entitlements:
      path: $PROJECT_NAME/$PROJECT_NAME.entitlements
YAML

# ── Generate Entitlements file ─────────────────────────────────────────────
cat > "$PROJECT_DIR/$PROJECT_NAME/$PROJECT_NAME.entitlements" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- Associated Domains — Universal Links: replace TEAMID with your Team ID -->
  <key>com.apple.developer.associated-domains</key>
  <array>
    <string>applinks:boanalyst.com</string>
  </array>

  <!-- Sign In with Apple (Guideline 4.8) -->
  <key>com.apple.developer.applesignin</key>
  <array>
    <string>Default</string>
  </array>

  <!-- Push Notifications -->
  <key>aps-environment</key>
  <string>production</string>
</dict>
</plist>
XML


# ── Run XcodeGen if available ──────────────────────────────────────────────
if command -v xcodegen &> /dev/null; then
    echo "⚙️   Running XcodeGen..."
    cd "$PROJECT_DIR"
    xcodegen generate
    echo "✅  $PROJECT_NAME.xcodeproj generated!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " ✅  Setup complete!"
    echo ""
    echo " Next steps:"
    echo " 1. open $PROJECT_DIR/$PROJECT_NAME.xcodeproj"
    echo "    (Xcode will resolve SPM packages automatically)"
    echo " 2. Add your 1024×1024 AppIcon to Assets.xcassets"
    echo " 3. Add Cinzel-Regular.ttf & Cinzel-Bold.ttf to the project"
    echo " 4. Set your Team ID in Signing & Capabilities"
    echo " 5. Build & Run on Simulator (Cmd+R)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo ""
    echo "⚠️   XcodeGen not found. Install it with:"
    echo "     brew install xcodegen"
    echo "     Then run: xcodegen generate"
fi
