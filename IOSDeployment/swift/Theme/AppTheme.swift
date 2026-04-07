// AppTheme.swift
// iOS equivalent of Android's Color.kt + Theme.kt + Type.kt
// Supports both Dark and Light themes natively via dynamic colors

import SwiftUI

// MARK: - Color Palette

enum AppTheme {
    // ── Gold Palette ──────────────────────────────────────────────────────────
    static let goldPrimary    = Color(lightHex: "B8860B", darkHex: "FFD700")  // GoldDark in light, Signature Gold in dark
    static let goldDim        = Color(hex: "B8860B")  // Dark Goldenrod
    static let goldSoft       = Color(hex: "DAA520")  // Goldenrod
    static let goldMuted      = Color(hex: "9A7D0A")  // Muted Gold

    // ── Background Palette ────────────────────────────────────────────────────
    static let background     = Color(lightHex: "F5F6FA", darkHex: "000000")  // LightBackground / DeepNavy
    static let surface        = Color(lightHex: "FFFFFF", darkHex: "050505")  // LightSurface / NavyDark
    static let surfaceVariant = Color(lightHex: "E8E9F2", darkHex: "101010")  // LightElevated / NavyElevated
    static let card           = Color(lightHex: "EEEFF5", darkHex: "0D0D0D")  // LightSurfaceVar / NavyCard

    // ── Text Colors ───────────────────────────────────────────────────────────
    static let textPrimary    = Color(lightHex: "0D0D1A", darkHex: "FFFFFF")
    static let textSecondary  = Color(lightHex: "3A3A55", darkHex: "CCCCCC")
    static let textMuted      = Color(lightHex: "7070A0", darkHex: "888898")

    // ── Status Colors ─────────────────────────────────────────────────────────
    static let success        = Color(hex: "22C55E")
    static let error          = Color(hex: "EF4444")
    static let warning        = Color(hex: "F59E0B")

    // ── Gradients ─────────────────────────────────────────────────────────────
    static let goldGradient = LinearGradient(
        colors: [Color(hex: "FFD700"), Color(hex: "B8860B")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [background, surface],
        startPoint: .top,
        endPoint: .bottom
    )

    // ── Typography ────────────────────────────────────────────────────────────
    static func cinzelFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // "Cinzel" is the same display font used on Android/web
        // Add Cinzel.ttf to your Xcode project and Info.plist: UIAppFonts
        .custom("Cinzel-Regular", size: size)
    }

    static func bodyFont(size: CGFloat) -> Font {
        .system(size: size, design: .default)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    // Dynamic color initializer for light and dark modes
    init(lightHex: String, darkHex: String) {
        self.init(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(Color(hex: darkHex))
            } else {
                return UIColor(Color(hex: lightHex))
            }
        })
    }
}

// MARK: - View Modifiers

struct GoldTextStyle: ViewModifier {
    let size: CGFloat
    func body(content: Content) -> some View {
        content
            .font(.custom("Cinzel-Regular", size: size))
            .foregroundStyle(AppTheme.goldGradient)
    }
}

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.goldPrimary.opacity(0.15), lineWidth: 1)
            )
            // Use lighter shadow in light mode
            .shadow(color: colorScheme == .dark ? .black.opacity(0.4) : .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct GlassMorphism: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial) // Change ultraThinMaterial to regularMaterial to work better in light and dark
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.goldPrimary.opacity(0.2), lineWidth: 1)
            )
    }
}

extension View {
    func goldText(size: CGFloat) -> some View {
        modifier(GoldTextStyle(size: size))
    }

    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func glassMorphism() -> some View {
        modifier(GlassMorphism())
    }
}
