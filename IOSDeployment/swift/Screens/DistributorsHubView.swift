// DistributorsHubView.swift
// iOS port of Android's DistributorsHubScreen.kt
// Gated behind isDistributor / isPro check — same logic as Android

import SwiftUI

// MARK: - DistributorsViewModel

@MainActor
final class DistributorsViewModel: ObservableObject {
    @Published var posts: [DistributorsPost] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    private let api = APIClient.shared
    private var offset = 0
    private let limit = 10

    func loadPosts(reset: Bool = false) async {
        if reset { offset = 0; posts = [] }
        isLoading = true
        error = nil
        if let result = try? await api.request(
            .getDistributorsHub(offset: offset, limit: limit),
            responseType: DistributorsResponse.self
        ) {
            if offset == 0 { posts = result.posts }
            else { posts.append(contentsOf: result.posts) }
            offset += result.posts.count
        } else if offset == 0 {
            error = "Unable to load Distributors Hub."
        }
        isLoading = false
    }
    func createPost(content: String, mediaData: Data? = nil, mimeType: String? = nil, fileName: String? = nil) async {
        guard let endpoint = try? APIEndpoint.createDistributorsPost(content: content, mediaData: mediaData, mimeType: mimeType, fileName: fileName) else { return }
        _ = try? await api.request(endpoint, responseType: MessageResponse.self)
        await loadPosts(reset: true)
    }

    func likePost(_ id: String) async {
        guard let idx = posts.firstIndex(where: { $0.id == id }) else { return }
        let p = posts[idx]
        
        // Optimistic UI toggle
        let newCount = p.likeCount + 1
        posts[idx] = DistributorsPost(from: p, likeCount: newCount)
        
        let endpoint = APIEndpoint.likeDistributorsPost(id: id)
        
        do {
            _ = try await api.requestRaw(endpoint)
        } catch {
            // Revert on failure
            DispatchQueue.main.async {
                if let reverseIdx = self.posts.firstIndex(where: { $0.id == id }) {
                    self.posts[reverseIdx] = DistributorsPost(from: p, likeCount: p.likeCount)
                }
            }
        }
    }
}

// MARK: - DistributorsHubView

struct DistributorsHubView: View {
    var isUserDistributor: Bool = false
    var onSubscribeRequired: () -> Void = {}
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = DistributorsViewModel()
    @State private var showCreatePost = false

    // Admins bypass the distributor paywall, like Android
    private var canView: Bool {
        isUserDistributor || (authViewModel.currentUser?.isAdmin == true)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if !canView {
                // Paywall for non-distributors
                distributorsPaywall
            } else if viewModel.isLoading && viewModel.posts.isEmpty {
                LoadingView()
            } else if viewModel.posts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.posts) { post in
                            DistributorsPostCard(post: post, onLike: {
                                Task { await viewModel.likePost(post.id) }
                            })
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .refreshable { await viewModel.loadPosts(reset: true) }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if authViewModel.currentUser?.isAdmin == true {
                Button {
                    showCreatePost = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.background)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.goldPrimary)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.goldPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding()
            }
        }
        .fullScreenCover(isPresented: $showCreatePost) {
            CreatePostSheet(title: "New Distributors Hub Post", onSubmitWithMedia: { text, mediaData, mediaType, fileName in
                await viewModel.createPost(content: text, mediaData: mediaData, mimeType: mediaType, fileName: fileName)
            })
        }
        .task {
            if canView { await viewModel.loadPosts() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("DISTRIBUTORS HUB")
                    .font(.custom("Cinzel-Regular", size: 13))
                    .foregroundStyle(AppTheme.goldGradient)
            }
        }
    }

    // MARK: - Paywall

    private var distributorsPaywall: some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.goldGradient)

            VStack(spacing: 8) {
                Text("Distributors Hub")
                    .font(.custom("Cinzel-Regular", size: 22))
                    .foregroundStyle(AppTheme.goldGradient)
                Text("Exclusive space for film\ndistributors & trade professionals")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Feature list
            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Trade-specific analytics")
                FeatureRow(icon: "network", text: "Direct industry network")
                FeatureRow(icon: "doc.richtext", text: "Exclusive distributor reports")
                FeatureRow(icon: "person.3.fill", text: "Industry-only discussions")
            }
            .padding(16)
            .cardStyle()
            .padding(.horizontal, 32)

            GoldButton(title: "Upgrade to Distributors") {
                onSubscribeRequired()
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.goldGradient)
            Text("No posts yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text("Be the first to post in the Distributors Hub!")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - Feature Row Helper

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.goldGradient)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}

// MARK: - Distributors Post Card

struct DistributorsPostCard: View {
    let post: DistributorsPost
    var onLike: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                let authorStr = post.authorName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if authorStr.contains("boanalyst") || authorStr.contains("admin") || post.isPinned {
                    Image("Logo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppTheme.goldPrimary.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(post.authorName.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.goldGradient)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(post.authorName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        if post.isFeatured {
                            Text("FEATURED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.goldPrimary)
                                .clipShape(Capsule())
                        }
                    }
                    Text(post.createdAt.prefix(10).description)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                if post.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.goldGradient)
                }
            }

            // Content — strip embed URLs, then render as markdown (fixes ** bold showing raw)
            let socialEmbeds = extractSocialEmbeds(from: post.content)
            let cleanContent = stripEmbedUrls(from: post.content, embeds: socialEmbeds)
            let attrContent = parseBoAnalystHTML(cleanContent)
            Text(attrContent)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(3)

            // ── Uploaded Media ───────────────────────────────────────
            if let urls = post.mediaUrls, !urls.isEmpty {
                PostMediaView(urls: urls)
            }

            // ── Social Embeds (YouTube / X / Instagram) ──────────────────
            if !socialEmbeds.isEmpty {
                SocialEmbedsSection(embeds: socialEmbeds)
            }

            // Tags
            if let tags = post.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.goldGradient)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.goldPrimary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Engagement
            HStack(spacing: 16) {
                Button { onLike() } label: {
                    Label("\(post.likeCount)", systemImage: "heart")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                Label("\(post.viewCount)", systemImage: "eye")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(16)
        .cardStyle()
    }
}
