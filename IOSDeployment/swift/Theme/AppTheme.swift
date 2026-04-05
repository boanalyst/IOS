// AppTheme.swift
// iOS equivalent of Android's Color.kt + Theme.kt + Type.kt
// Gold & Black premium theme

import SwiftUI

// MARK: - Color Palette

enum AppTheme {
    // ── Gold Palette ──────────────────────────────────────────────────────────
    static let goldPrimary    = Color(hex: "FFD700")  // Signature Gold
    static let goldDim        = Color(hex: "B8860B")  // Dark Goldenrod
    static let goldSoft       = Color(hex: "DAA520")  // Goldenrod
    static let goldMuted      = Color(hex: "9A7D0A")  // Muted Gold

    // ── Background Palette ────────────────────────────────────────────────────
    static let background     = Color(hex: "0A0A0A")  // Void Black
    static let surface        = Color(hex: "111111")  // Surface
    static let surfaceVariant = Color(hex: "1A1A1A")  // Elevated Surface
    static let card           = Color(hex: "151515")  // Card Background

    // ── Text Colors ───────────────────────────────────────────────────────────
    static let textPrimary    = Color(hex: "F5F5F5")
    static let textSecondary  = Color(hex: "AAAAAA")
    static let textMuted      = Color(hex: "666666")

    // ── Status Colors ─────────────────────────────────────────────────────────
    static let success        = Color(hex: "4CAF50")
    static let error          = Color(hex: "F44336")
    static let warning        = Color(hex: "FF9800")

    // ── Gradients ─────────────────────────────────────────────────────────────
    static let goldGradient = LinearGradient(
        colors: [Color(hex: "FFD700"), Color(hex: "B8860B")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "0A0A0A"), Color(hex: "111111")],
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
    func body(content: Content) -> some View {
        content
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.goldPrimary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

struct GlassMorphism: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
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
