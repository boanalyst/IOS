// SharedComponents.swift
// Shared utility views used across multiple screens
// This file fixes FlockPostCard to use the correct FlockPost model fields
// (authorName / likeCount / replyCount instead of post.author.name / post.likes etc.)

import SwiftUI

// MARK: - FlockPostCard (canonical — used by FlockFeedView and HomeView)
// isLiked drives heart.fill / heart state.
// onLike and onComment are separated from onTap so gesture areas don't clash.
// isAdmin enables admin context menu (delete / pin) — Bug #1 fix.

struct FlockPostCard: View {
    let post: FlockPost
    let isAdmin: Bool
    var isLiked: Bool = false
    var onTap: () -> Void = {}
    var onLike: () -> Void = {}
    var onComment: () -> Void = {}
    var onDelete: () -> Void = {}
    var onPin: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Author header
                HStack(spacing: 10) {
                    Circle()
                        .fill(AppTheme.goldPrimary.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(post.authorName.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.goldGradient)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(post.authorName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                            if let handle = post.authorHandle, !handle.isEmpty {
                                Text("@\(handle)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                        }
                        Text(post.createdAt.prefix(10).description)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()

                    // Right side: pin indicator + admin menu
                    HStack(spacing: 8) {
                        if post.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.goldGradient)
                        }
                        // Bug #1 fix: admin sees a context menu button
                        if isAdmin {
                            Menu {
                                Button(role: .destructive) { onDelete() } label: {
                                    Label("Delete Post", systemImage: "trash")
                                }
                                Button { onPin() } label: {
                                    Label(post.isPinned ? "Unpin Post" : "Pin Post",
                                          systemImage: post.isPinned ? "pin.slash" : "pin")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.textMuted)
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Content
                Text(post.content)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(5)
                    .lineSpacing(3)

                // Hashtags
                if !post.tags.isEmpty {
                    Text(post.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.goldGradient)
                        .lineLimit(1)
                }

                // Engagement row — separate buttons to prevent tap bleeding into parent
                HStack(spacing: 16) {
                    Button { onLike() } label: {
                        Label("\(post.likeCount)",
                              systemImage: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundColor(isLiked ? AppTheme.goldPrimary : AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)

                    Button { onComment() } label: {
                        Label("\(post.replyCount)", systemImage: "bubble.left")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// Backward-compatibility alias so HomeView's existing FlockPostCardFull calls compile
typealias FlockPostCardFull = FlockPostCard


// MARK: - InsideTalkCard with Correct Model Field
// InsideTalkContent uses `.content` not `.text`; this card is already correct
// in StubViews.swift but included here for reference.

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.goldGradient)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - Toast / Snackbar

struct ToastView: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? AppTheme.error : AppTheme.success)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Shimmer Loading Placeholder

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.surface, location: phase - 0.3),
                        .init(color: AppTheme.surfaceVariant, location: phase),
                        .init(color: AppTheme.surface, location: phase + 0.3),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

// MARK: - Skeleton Card

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .overlay(ShimmerView().clipShape(Circle()))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    ShimmerView()
                        .frame(width: 120, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    ShimmerView()
                        .frame(width: 80, height: 10)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            ShimmerView()
                .frame(maxWidth: .infinity)
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            ShimmerView()
                .frame(width: 200, height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(16)
        .cardStyle()
    }
}
