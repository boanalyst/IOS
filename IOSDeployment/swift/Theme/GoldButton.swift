// GoldButton.swift
// iOS equivalent of Android's GoldButton.kt custom composable

import SwiftUI

// MARK: - Primary Gold Button

struct GoldButton: View {
    let title: String
    var isLoading: Bool = false
    var isFullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: 52)
            .padding(.horizontal, isFullWidth ? 0 : 24)
            .background(AppTheme.goldGradient)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: AppTheme.goldPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.97 : 1.0)
        .animation(.spring(response: 0.3), value: isLoading)
    }
}

// MARK: - Outlined Gold Button

struct GoldOutlineButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(AppTheme.goldGradient)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.goldGradient, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Icon Gold Button

struct GoldIconButton: View {
    let icon: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.goldGradient)
                .frame(width: size, height: size)
                .background(AppTheme.surface)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        GoldButton(title: "Subscribe Now") {}
        GoldButton(title: "Loading...", isLoading: true) {}
        GoldOutlineButton(title: "View Details", icon: "arrow.right") {}
        GoldIconButton(icon: "heart.fill") {}
    }
    .padding()
    .background(AppTheme.background)
}
