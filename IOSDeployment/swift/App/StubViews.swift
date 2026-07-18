// StubViews.swift
// Full feature implementations for Flock Feed, Inside Talk and related views.
// Matches Android FlockFeedScreen.kt + InsideTalkScreen.kt feature parity.

import SwiftUI

// MARK: - Generic Comment Model (used by both Flock and Inside Talk)

struct AppComment: Identifiable {
    let id: String
    let authorName: String
    let content: String
    let createdAt: String
    let userId: String
}

// MARK: - Comment Bottom Sheet
// Bug #4 fix: CommentBottomSheet now gets comments via @Binding so the sheet
// updates live when the async loadComments() / loadReplies() response arrives.
// The caller must pass a Binding to a mutable array that the viewModel populates.

struct CommentBottomSheet: View {
    let postId: String
    let comments: [AppComment]   // read from live viewModel state in the wrapper view
    let isLoading: Bool          // read from live viewModel state in the wrapper view
    let currentUserId: String
    let isAdmin: Bool
    var onDismiss: () -> Void
    var onSubmit: (String) -> Void
    var onDelete: (String) -> Void  // commentId

    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            // Header
            HStack {
                Text("Comments (\(comments.count))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView().tint(AppTheme.goldPrimary).scaleEffect(0.8)
                }
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider().background(Color.white.opacity(0.08))

            if isLoading && comments.isEmpty {
                ProgressView().tint(AppTheme.goldPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
            } else if comments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.goldGradient)
                    Text("No comments yet")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Be the first to comment!")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(comments) { c in
                            commentRow(c)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            Spacer(minLength: 0)

            // Composer
            HStack(spacing: 10) {
                TextField("Write a comment…", text: $text)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textPrimary)
                    .accentColor(AppTheme.goldPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                Button {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSubmit(trimmed)
                    text = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? AnyShapeStyle(Color.gray.opacity(0.3))
                                         : AnyShapeStyle(AppTheme.goldGradient))
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.surface)
        }
        .background(AppTheme.card)
    }

    @ViewBuilder
    private func commentRow(_ c: AppComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            let authorStr = c.authorName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if authorStr.contains("boanalyst") || authorStr.contains("admin") {
                BoAnalystAvatarView(size: 32, padding: 4)
            } else {
                Circle()
                    .fill(AppTheme.goldPrimary.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(c.authorName.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.goldGradient)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(c.authorName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text(formatRelativeDate(c.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    if isAdmin || c.userId == currentUserId {
                        Button { onDelete(c.id) } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.error)
                        }
                    }
                }
                let cleanContent = stripEmbedUrls(from: c.content, embeds: [])
                let attrString = ParsedTextCache.shared.parseFlock(cleanContent, id: c.id)
                Text(attrString)
                    .tint(AppTheme.goldPrimary)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(nil)
                    .lineSpacing(6)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - TrendingStrip

struct TrendingStrip: View {
    let trends: [TrendingTrend]
    var onTap: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.goldGradient)
                Text("TRENDING")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(trends) { trend in
                        Button { onTap(trend.topic) } label: {
                            HStack(spacing: 4) {
                                Text("#\(trend.topic)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.goldGradient)
                                Text("(\(trend.count))")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.goldPrimary.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.goldPrimary.opacity(0.25), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 10)
        .background(AppTheme.surface)
    }
}

struct IdentifiableString: Identifiable {
    let id: String
}

struct SingleFlockPostResponse: Decodable {
    let success: Bool
    let post: FlockPost?
}

// MARK: - FlockViewModel (full implementation matching Android FlockViewModel)

@MainActor
final class FlockViewModel: ObservableObject {
    // Posts + pagination
    @Published var posts: [FlockPost] = []
    @Published var likedPostIds: Set<String> = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var nextOffset = 0
    @Published var error: String? = nil
    @Published var isPosting = false
    @Published var selectedCategory: String = "All"

    // Trending
    @Published var trendingTopics: [TrendingTrend] = []

    // Comments
    @Published var commentsState: [String: [AppComment]] = [:]
    @Published var commentsLoadingSet: Set<String> = []

    private let api = APIClient.shared

    init() { Task { await loadFeed() } }

    // MARK: Feed

    func loadFeed() async {
        isLoading = true
        error = nil
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchPosts(offset: 0, reset: true) }
            group.addTask { await self.fetchTrending() }
        }
        isLoading = false
    }

    private func fetchPosts(offset: Int, reset: Bool) async {
        let catParam = selectedCategory == "All" ? nil : (selectedCategory == "Technology" ? "tech" : selectedCategory.lowercased())
        if let result = try? await api.request(
            .getFlockPosts(offset: offset, limit: 20, category: catParam),
            responseType: FlockFeedResponse.self
        ) {
            let returned = result.posts
            if reset { posts = returned }
            else { posts.append(contentsOf: returned) }
            nextOffset = offset + returned.count
            hasMore = returned.count >= (result.limit ?? 20)
            // Seed likedPostIds from server-returned userLiked flags
            for p in returned where p.userLiked == true {
                likedPostIds.insert(p.id)
            }
        } else if reset {
            error = "Unable to load Flock posts."
        }
    }

    private func fetchTrending() async {
        if let result = try? await api.request(
            .getTrendingTopics,
            responseType: TrendingResponse.self
        ) {
            trendingTopics = result.trends
        }
    }

    func fetchSinglePost(id: String) async -> FlockPost? {
        do {
            let response = try await api.request(
                .getFlockPost(id: id),
                responseType: SingleFlockPostResponse.self
            )
            return response.post
        } catch {
            print("⚠️ Error fetching single post \(id): \(error.localizedDescription)")
            return nil
        }
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        Task {
            isLoadingMore = true
            await fetchPosts(offset: nextOffset, reset: false)
            isLoadingMore = false
        }
    }

    // MARK: Like (optimistic, mirrors Android FlockViewModel.toggleLike)

    func toggleLike(_ post: FlockPost) {
        let isLiked = likedPostIds.contains(post.id)
        // Optimistic update
        if isLiked { likedPostIds.remove(post.id) } else { likedPostIds.insert(post.id) }
        posts = posts.map { p in
            guard p.id == post.id else { return p }
            var updated = p
            updated = FlockPost(from: p, likeCount: isLiked ? max(0, p.likeCount - 1) : p.likeCount + 1)
            return updated
        }
        Task {
            let endpoint = isLiked ? APIEndpoint.unlikePost(id: post.id) : APIEndpoint.likePost(id: post.id)
            if (try? await api.request(endpoint, responseType: LikeResponse.self)) == nil {
                // Revert on failure
                if isLiked { likedPostIds.insert(post.id) } else { likedPostIds.remove(post.id) }
                posts = posts.map { p in
                    guard p.id == post.id else { return p }
                    return FlockPost(from: p, likeCount: p.likeCount + (isLiked ? 1 : -1))
                }
            }
        }
    }

    func createPost(content: String, category: String? = nil, mediaFiles: [(data: Data, mimeType: String, fileName: String)] = [], pollData: PollCreationData? = nil) async {
        let apiCat = category == "Technology" ? "tech" : category?.lowercased()
        guard let endpoint = try? APIEndpoint.createFlockPost(content: content, category: apiCat, mediaFiles: mediaFiles, pollQuestion: pollData?.question, pollOptions: pollData?.options, pollEndsAt: pollData?.endsAt) else { return }
        _ = try? await api.request(endpoint, responseType: MessageResponse.self)
        await loadFeed()
    }

    func voteOnPoll(postId: String, pollId: String, optionId: String) {
        Task {
            guard let endpoint = try? APIEndpoint.votePoll(id: pollId, optionId: optionId) else { return }
            if let result = try? await api.request(endpoint, responseType: PollVoteResponse.self), let updatedPoll = result.poll {
                posts = posts.map { p in
                    guard p.id == postId && p.poll?.id == pollId else { return p }
                    return FlockPost(from: p, poll: updatedPoll)
                }
            } else {
                error = "Could not vote on poll."
            }
        }
    }

    // MARK: Comments

    func loadComments(postId: String) {
        Task {
            commentsLoadingSet.insert(postId)
            if let result = try? await api.request(
                .getComments(postId: postId),
                responseType: CommentResponse.self
            ) {
                commentsState[postId] = result.resolvedComments.map {
                    AppComment(id: $0.id, authorName: $0.authorName,
                               content: $0.content, createdAt: $0.createdAt, userId: $0.userId ?? "")
                }
            }
            commentsLoadingSet.remove(postId)
        }
    }

    func addComment(postId: String, text: String) {
        Task {
            guard let endpoint = try? APIEndpoint.addComment(postId: postId, text: text) else { return }
            _ = try? await api.requestRaw(endpoint)
            self.loadComments(postId: postId)
            
            // Increment reply_count optimistically
            posts = posts.map { p in
                guard p.id == postId else { return p }
                return FlockPost(from: p, replyCount: p.replyCount + 1)
            }
        }
    }

    func deleteComment(postId: String, commentId: String) {
        // Optimistic remove
        let prior = commentsState[postId] ?? []
        commentsState[postId] = prior.filter { $0.id != commentId }
        Task {
            let endpoint = APIEndpoint.deleteComment(postId: postId, commentId: commentId)
            if (try? await api.request(endpoint, responseType: MessageResponse.self)) == nil {
                commentsState[postId] = prior  // revert
            } else {
                posts = posts.map { p in
                    guard p.id == postId else { return p }
                    return FlockPost(from: p, replyCount: max(0, p.replyCount - 1))
                }
            }
        }
    }

    // MARK: Admin: Delete Post (Bug #1 fix)

    func deletePost(_ post: FlockPost) {
        // Optimistic remove
        let prior = posts
        posts = posts.filter { $0.id != post.id }
        Task {
            let endpoint = APIEndpoint.deleteFlockPost(id: post.id)
            if (try? await api.request(endpoint, responseType: MessageResponse.self)) == nil {
                posts = prior // revert on failure
                error = "Could not delete post. You may not have permission."
            }
        }
    }

    // MARK: Admin: Edit Post
    func updatePost(_ post: FlockPost, content: String, existingMediaUrls: [String]? = nil, mediaFiles: [(data: Data, mimeType: String, fileName: String)] = []) {
        Task {
            if let endpoint = try? APIEndpoint.updateFlockPost(id: post.id, content: content, existingMediaUrls: existingMediaUrls, mediaFiles: mediaFiles) {
                if (try? await api.requestRaw(endpoint)) != nil {
                    // Success, reload posts
                    await fetchPosts(offset: 0, reset: true)
                } else {
                    error = "Could not update post."
                }
            }
        }
    }

    // MARK: Admin: Pin/Unpin Post (Bug #1 fix)

    func togglePin(_ post: FlockPost) {
        Task {
            if let endpoint = try? APIEndpoint.pinFlockPost(id: post.id, isPinned: !post.isPinned) {
                _ = try? await api.requestRaw(endpoint)
                // Reload feed to get server-authoritative pin state (sorted pins first)
                await fetchPosts(offset: 0, reset: true)
            }
        }
    }
}

// MARK: - Reactive Comment Sheet Container (Bug #4 fix)
// SwiftUI's .sheet(item:) closure captures state at creation time.
// By wrapping CommentBottomSheet in an @ObservedObject container, the sheet
// re-renders whenever commentsState/commentsLoadingSet changes after async load.

struct FlockCommentSheetContainer: View {
    @ObservedObject var flockVM: FlockViewModel
    let postId: String
    let currentUserId: String
    let isAdmin: Bool
    var onDismiss: () -> Void

    var body: some View {
        CommentBottomSheet(
            postId: postId,
            comments: flockVM.commentsState[postId] ?? [],
            isLoading: flockVM.commentsLoadingSet.contains(postId),
            currentUserId: currentUserId,
            isAdmin: isAdmin,
            onDismiss: onDismiss,
            onSubmit: { text in flockVM.addComment(postId: postId, text: text) },
            onDelete: { commentId in flockVM.deleteComment(postId: postId, commentId: commentId) }
        )
    }
}

struct InsideTalkCommentSheetContainer: View {
    @ObservedObject var viewModel: InsideTalkViewModel
    let tweetId: String
    let currentUserId: String
    let isAdmin: Bool
    var onDismiss: () -> Void

    var body: some View {
        CommentBottomSheet(
            postId: tweetId,
            comments: viewModel.repliesState[tweetId] ?? [],
            isLoading: viewModel.repliesLoadingSet.contains(tweetId),
            currentUserId: currentUserId,
            isAdmin: isAdmin,
            onDismiss: onDismiss,
            onSubmit: { text in viewModel.addReply(tweetId: tweetId, text: text) },
            onDelete: { replyId in viewModel.deleteReply(tweetId: tweetId, replyId: replyId) }
        )
    }
}

// MARK: - FlockFeedView (full feature implementation)

struct FlockFeedView: View {
    @EnvironmentObject private var flockVM: FlockViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var activeCommentPostId: String? = nil
    @State private var flockDetailPostId: String? = nil
    @State private var showCreatePost = false
    @State private var editingPost: FlockPost?
    @StateObject private var adManager = InterstitialAdManager()
    @EnvironmentObject private var rewardedAdManager: RewardedAdManager
    @State private var unlockedRewardedPosts: Set<String> = []
    @State private var adInterval: Int = 10

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
            if flockVM.isLoading && flockVM.posts.isEmpty {
                LoadingView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {   // Bug #2 fix: increased from 12 to 16 for better spacing
                        // ── Trending strip ──────────────────────────────
                        if !flockVM.trendingTopics.isEmpty {
                            TrendingStrip(trends: flockVM.trendingTopics)
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                        }

                        // ── Categories ──────────────────────────────
                        let categories = ["All", "Entertainment", "Politics", "Sports", "Business", "Technology"]
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    Button(action: {
                                        flockVM.selectedCategory = cat
                                        Task { await flockVM.loadFeed() }
                                    }) {
                                        Text(cat)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(flockVM.selectedCategory == cat ? AppTheme.goldPrimary : AppTheme.textSecondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(flockVM.selectedCategory == cat ? AppTheme.goldPrimary.opacity(0.2) : AppTheme.surfaceVariant)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)

                        // ── Posts ────────────────────────────────────────
                        if flockVM.posts.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(flockVM.posts.enumerated()), id: \.element.id) { index, post in
                                let isAdmin = authViewModel.currentUser?.isAdmin == true
                                FlockPostCard(
                                    post: post,
                                    isAdmin: isAdmin,
                                    isLiked: flockVM.likedPostIds.contains(post.id),
                                    isUnlocked: (authViewModel.currentUser?.isPro == true) || unlockedRewardedPosts.contains(post.id),
                                    onTap: {
                                        let contentLower = post.content.lowercased()
                                        let hasSuperTag = contentLower.contains("#boanalystsuper")
                                        let hasAdTag = post.showInterstitial || contentLower.contains("#boad") || contentLower.contains("#interstitial")
                                        let hasRewardedTag = post.showRewarded || contentLower.contains("#boanalystexclusive")
                                        
                                        if authViewModel.currentUser?.isPro == true {
                                            flockDetailPostId = post.id
                                        } else if hasSuperTag {
                                            flockDetailPostId = post.id
                                        } else if hasRewardedTag && !unlockedRewardedPosts.contains(post.id) {
                                            RewardedAdController.showAd(manager: rewardedAdManager) {
                                                unlockedRewardedPosts.insert(post.id)
                                                flockDetailPostId = post.id
                                            }
                                        } else if hasAdTag {
                                            InterstitialAdController.showAd(manager: adManager) {
                                                flockDetailPostId = post.id
                                            }
                                        } else {
                                            flockDetailPostId = post.id
                                        }
                                    },
                                    onLike: { flockVM.toggleLike(post) },
                                    onComment: {
                                        flockVM.loadComments(postId: post.id)
                                        activeCommentPostId = post.id
                                    },
                                    onDelete: isAdmin ? { flockVM.deletePost(post) } : {},
                                    onPin: isAdmin ? { flockVM.togglePin(post) } : {},
                                    onEdit: isAdmin ? { editingPost = post } : nil,
                                    onVote: { pollId, optionId in flockVM.voteOnPoll(postId: post.id, pollId: pollId, optionId: optionId) }
                                )
                                .padding(.horizontal, 16)

                                 if (index + 1) % adInterval == 0 && !(authViewModel.currentUser?.isAdFree == true) {
                                    BoNativeAdView(index: index, listName: "flock")
                                        .padding(.horizontal, 16)
                                }
                            }

                            // Load more footer
                            if flockVM.hasMore {
                                if flockVM.isLoadingMore {
                                    ProgressView()
                                        .tint(AppTheme.goldPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(20)
                                } else {
                                    Color.clear.frame(height: 1)
                                        .onAppear { flockVM.loadMore() }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .refreshable { await flockVM.loadFeed() }
            }

            // Anchored AdMob Banner — separated from scrollable content (Google recommended)
            if !(authViewModel.currentUser?.isAdFree == true) {
                SwiftUIBannerAd(adUnitId: "ca-app-pub-5734863079459748/8749854605")
                    .frame(height: 50)
                    .padding(.vertical, 4)
                    .background(AppTheme.surface)
            }
            } // end VStack
        }
        .task {
            if flockVM.posts.isEmpty { await flockVM.loadFeed() }
            do {
                let config = try await APIClient.shared.request(.getAdConfig, responseType: AdConfigResponse.self)
                self.adInterval = config.adInterval
            } catch {
                print("⚠️ [FlockFeedView] Failed to fetch dynamic ad-config: \(error.localizedDescription)")
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
            CreatePostSheet(title: "New Flock Post", showCategoryPicker: true, onSubmitWithPollAndCategory: { text, cat, mediaFiles, existingUrls, pollData in
                await flockVM.createPost(content: text, category: cat, mediaFiles: mediaFiles, pollData: pollData)
            })
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("FLOCK FEED")
                    .font(.custom("Cinzel-Regular", size: 14))
                    .foregroundStyle(AppTheme.goldGradient)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button { Task { await flockVM.loadFeed() } } label: { Image(systemName: "arrow.clockwise").font(.title3).foregroundColor(AppTheme.textMuted) }
                    Button { authViewModel.showProfileSheet = true } label: { Image(systemName: "person.crop.circle").font(.title3).foregroundColor(AppTheme.goldPrimary) }
                }
            }
        }
        .sheet(item: $editingPost) { post in
            CreatePostSheet(title: "Edit Flock Post", initialText: post.content, initialMediaUrls: post.media.map { $0.resolvedUrl() }.filter { !$0.isEmpty }, onSubmitWithMedia: { newContent, mediaFiles, existingUrls in
                flockVM.updatePost(post, content: newContent, existingMediaUrls: existingUrls, mediaFiles: mediaFiles)
            })
        }
        .sheet(item: Binding(
            get: { flockDetailPostId.map { IdentifiableString(id: $0) } },
            set: { flockDetailPostId = $0?.id }
        )) { wrapper in
            FlockPostDetailSheet(postId: wrapper.id)
                .environmentObject(flockVM)
                .environmentObject(authViewModel)
        }
        // ── Comment Bottom Sheet (Bug #4 fix: uses FlockCommentSheetContainer for live updates) ──
        .sheet(item: $activeCommentPostId) { postId in
            FlockCommentSheetContainer(
                flockVM: flockVM,
                postId: postId,
                currentUserId: authViewModel.currentUser?.id ?? "",
                isAdmin: authViewModel.currentUser?.isAdmin == true,
                onDismiss: { activeCommentPostId = nil }
            )
            .presentationDetents([.medium, .large])
            .modifier(SheetBackgroundModifier())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.goldGradient)
            Text("No posts yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text("Be the first to post in the Flock!")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// Conform String to Identifiable so it can be used as sheet(item:)
extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - InsideTalkViewModel (full implementation matching Android InsideTalkViewModel)

@MainActor
final class InsideTalkViewModel: ObservableObject {
    @Published var tweets: [InsideTalkContent] = []
    @Published var count: Int = 0
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var page = 1
    @Published var error: String? = nil

    // Replies (per tweetId)
    @Published var repliesState: [String: [AppComment]] = [:]
    @Published var repliesLoadingSet: Set<String> = []

    private let api = APIClient.shared

    init() { Task { await loadAll() } }

    func loadAll() async {
        isLoading = true
        error = nil
        async let tweetsTask = api.request(.getInsideTalk(page: 1, limit: 20), responseType: InsideTalkResponse.self)
        async let countTask  = api.request(.getInsideTalkCount, responseType: InsideTalkCountResponse.self)

        let tweetsResult = try? await tweetsTask
        let countResult  = try? await countTask

        tweets  = tweetsResult?.tweets ?? []
        count   = countResult?.count   ?? 0
        page    = 2
        hasMore = (tweetsResult?.tweets.count ?? 0) >= 20
        isLoading = false
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        Task {
            isLoadingMore = true
            if let result = try? await api.request(.getInsideTalk(page: page, limit: 20), responseType: InsideTalkResponse.self) {
                tweets.append(contentsOf: result.tweets)
                page += 1
                hasMore = result.tweets.count >= 20
            } else {
                hasMore = false
            }
            isLoadingMore = false
        }
    }

    func createPost(text: String, mediaFiles: [(data: Data, mimeType: String, fileName: String)] = []) async {
        guard let endpoint = try? APIEndpoint.createInsideTalkPost(text: text, mediaFiles: mediaFiles) else { return }
        _ = try? await api.request(endpoint, responseType: MessageResponse.self) // Optimistic, we just reload
        await loadAll() // Reload to fetch the new post
    }

    // MARK: Like (optimistic toggle, mirrors Android InsideTalkViewModel.toggleLike)

    func toggleLike(_ tweet: InsideTalkContent) {
        let wasLiked = tweet.userLiked
        tweets = tweets.map { t in
            guard t.id == tweet.id else { return t }
            return InsideTalkContent(from: t, userLiked: !wasLiked,
                                     likeCount: wasLiked ? max(0, t.likeCount - 1) : t.likeCount + 1)
        }
        Task {
            let endpoint = wasLiked
                ? (try? APIEndpoint.toggleInsideTalkLike(tweetId: tweet.id))  // dislike = toggle off
                : (try? APIEndpoint.toggleInsideTalkLike(tweetId: tweet.id))
            guard let ep = endpoint else { return }
            if (try? await api.request(ep, responseType: InsideTalkLikeResponse.self)) == nil {
                // Revert on error
                tweets = tweets.map { t in
                    guard t.id == tweet.id else { return t }
                    return InsideTalkContent(from: t, userLiked: wasLiked,
                                             likeCount: t.likeCount + (wasLiked ? 1 : -1))
                }
            }
        }
    }

    // MARK: Replies

    func loadReplies(tweetId: String) {
        Task {
            repliesLoadingSet.insert(tweetId)
            if let result = try? await api.request(.getInsideTalkReplies(tweetId: tweetId), responseType: InsideTalkRepliesResponse.self) {
                repliesState[tweetId] = result.resolvedReplies.map {
                    AppComment(id: $0.id, authorName: $0.authorName,
                               content: $0.content, createdAt: $0.createdAt, userId: $0.userId ?? "")
                }
            }
            repliesLoadingSet.remove(tweetId)
        }
    }

    func addReply(tweetId: String, text: String) {
        Task {
            guard let endpoint = try? APIEndpoint.addInsideTalkReply(tweetId: tweetId, text: text) else { return }
            _ = try? await api.requestRaw(endpoint)
            self.loadReplies(tweetId: tweetId)
            
            tweets = tweets.map { t in
                guard t.id == tweetId else { return t }
                return InsideTalkContent(from: t, replyCount: t.replyCount + 1)
            }
        }
    }

    func deletePost(tweetId: String) {
        tweets.removeAll { $0.id == tweetId }
        Task {
            let endpoint = APIEndpoint.deleteInsideTalkPost(id: tweetId)
            _ = try? await api.request(endpoint, responseType: MessageResponse.self)
        }
    }

    func updatePost(tweetId: String, text: String, existingMediaUrls: [String]? = nil) {
        Task {
            if let endpoint = try? APIEndpoint.updateInsideTalkPost(id: tweetId, text: text, existingMediaUrls: existingMediaUrls) {
                if (try? await api.requestRaw(endpoint)) != nil {
                    await loadAll()
                }
            }
        }
    }

    func deleteReply(tweetId: String, replyId: String) {
        let prior = repliesState[tweetId] ?? []
        repliesState[tweetId] = prior.filter { $0.id != replyId }
        Task {
            let endpoint = APIEndpoint.deleteInsideTalkReply(replyId: replyId, tweetId: tweetId)
            if (try? await api.request(endpoint, responseType: MessageResponse.self)) == nil {
                repliesState[tweetId] = prior  // revert
            } else {
                tweets = tweets.map { t in
                    guard t.id == tweetId else { return t }
                    return InsideTalkContent(from: t, replyCount: max(0, t.replyCount - 1))
                }
            }
        }
    }

    func togglePin(_ tweet: InsideTalkContent) {
        Task {
            if let endpoint = try? APIEndpoint.pinInsideTalkPost(id: tweet.id, isPinned: !tweet.isPinned) {
                _ = try? await api.requestRaw(endpoint)
                await loadAll()
            }
        }
    }
}

// MARK: - InsideTalkView (full feature implementation)

struct InsideTalkView: View {
    var onSubscribeRequired: () -> Void = {}
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = InsideTalkViewModel()

    @State private var activeCommentTweetId: String? = nil
    @State private var showCreatePost = false
    @State private var editingPost: InsideTalkContent?
    @EnvironmentObject private var rewardedAdManager: RewardedAdManager
    @State private var unlockedRewardedPosts: Set<String> = []
    @State private var adInterval: Int = 10
    @State private var navigateToBmsSales = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.tweets.isEmpty {
                LoadingView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) { // Bug #2 fix: increased from 12 to 16
                        let isUserProGlobal = (authViewModel.currentUser?.isPro ?? false) || (authViewModel.currentUser?.isAdmin == true)
                        let isUserAdFreeGlobal = authViewModel.currentUser?.isAdFree == true
                        
                        // ── Hourly BMS Sales Button ──────────────────────────────
                        Button(action: {
                            if !(authViewModel.currentUser?.isPro == true) {
                                if rewardedAdManager.isAdLoaded {
                                    RewardedAdController.showAd(manager: rewardedAdManager) {
                                        rewardedAdManager.loadAd()
                                        navigateToBmsSales = true
                                    }
                                } else {
                                    rewardedAdManager.loadAd()
                                    navigateToBmsSales = true
                                }
                            } else {
                                navigateToBmsSales = true
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                                
                                Text("VIEW HOURLY BMS SALES")
                                    .font(.system(size: 14, weight: .heavy))
                                    .tracking(1)
                                    .foregroundColor(.black)
                                
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "D4AF37"), Color(hex: "F3E5AB"), Color(hex: "D4AF37")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(hex: "D4AF37").opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                        .background(
                            NavigationLink(destination: BmsSalesView(), isActive: $navigateToBmsSales) {
                                EmptyView()
                            }
                            .hidden()
                        )

                        // Non-pro upgrade banner (scrollable, mirrors Android)
                        if !isUserProGlobal && viewModel.count > 0 {
                            proUpgradeBanner
                                .padding(.horizontal, 16)
                        }

                        let displayItems = isUserProGlobal 
                            ? viewModel.tweets 
                            : viewModel.tweets.filter { $0.showRewarded || $0.content.lowercased().contains("#boanalystexclusive") }

                        ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, tweet in
                            let isAdmin = authViewModel.currentUser?.isAdmin == true
                            let isRewardedUnlocked = unlockedRewardedPosts.contains(tweet.id)
                            let isRewardedContent = tweet.showRewarded || tweet.content.lowercased().contains("#boanalystexclusive")
                            let isActuallyUnlocked = isRewardedContent ? isRewardedUnlocked : isUserProGlobal
                            let isRewardedForUser = isRewardedContent && isUserProGlobal

                            InsideTalkCard(
                                content: tweet,
                                isUserPro: isActuallyUnlocked,
                                isRewarded: isRewardedForUser && !isRewardedUnlocked,
                                onSubscribeRequired: {
                                    if !isActuallyUnlocked {
                                        if isRewardedForUser {
                                            RewardedAdController.showAd(manager: rewardedAdManager) {
                                                unlockedRewardedPosts.insert(tweet.id)
                                            }
                                        } else {
                                            onSubscribeRequired()
                                        }
                                    }
                                },
                                onLike: { viewModel.toggleLike(tweet) },
                                onComment: {
                                    viewModel.loadReplies(tweetId: tweet.id)
                                    activeCommentTweetId = tweet.id
                                },
                                onDelete: isAdmin ? { viewModel.deletePost(tweetId: tweet.id) } : nil,
                                onPin: isAdmin ? { viewModel.togglePin(tweet) } : nil,
                                onEdit: isAdmin ? { editingPost = tweet } : nil
                            )
                            .padding(.horizontal, 16)

                            if (index + 1) % adInterval == 0 && !isUserAdFreeGlobal {
                                BoNativeAdView(index: index, listName: "insidetalk")
                                    .padding(.horizontal, 16)
                            }
                        }

                        // Load more
                        if viewModel.hasMore && (authViewModel.currentUser?.isPro ?? false) {
                            if viewModel.isLoadingMore {
                                ProgressView().tint(AppTheme.goldPrimary).frame(maxWidth: .infinity).padding(20)
                            } else {
                                Color.clear.frame(height: 1).onAppear { viewModel.loadMore() }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .refreshable { await viewModel.loadAll() }
            }

            // Anchored AdMob Banner — separated from scrollable content (Google recommended)
            if !(authViewModel.currentUser?.isAdFree == true) {
                SwiftUIBannerAd(adUnitId: "ca-app-pub-5734863079459748/8749854605")
                    .frame(height: 50)
                    .padding(.vertical, 4)
                    .background(AppTheme.surface)
            }
            } // end VStack
        }
        .task {
            if viewModel.tweets.isEmpty { await viewModel.loadAll() }
            do {
                let config = try await APIClient.shared.request(.getAdConfig, responseType: AdConfigResponse.self)
                self.adInterval = config.adInterval
            } catch {
                print("⚠️ [InsideTalkView] Failed to fetch dynamic ad-config: \(error.localizedDescription)")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("INSIDE TALK")
                    .font(.custom("Cinzel-Regular", size: 14))
                    .foregroundStyle(AppTheme.goldGradient)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button { Task { await viewModel.loadAll() } } label: { Image(systemName: "arrow.clockwise").font(.title3).foregroundColor(AppTheme.textMuted) }
                    Button { authViewModel.showProfileSheet = true } label: { Image(systemName: "person.crop.circle").font(.title3).foregroundColor(AppTheme.goldPrimary) }
                }
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
            CreatePostSheet(title: "New Inside Talk", onSubmitWithMedia: { text, mediaFiles, existingUrls in
                await viewModel.createPost(text: text, mediaFiles: mediaFiles)
            })
        }
        .sheet(item: $editingPost) { tweet in
            CreatePostSheet(title: "Edit Inside Talk", initialText: tweet.content, initialMediaUrls: tweet.media.map { $0.resolvedUrl() }.filter { !$0.isEmpty }, onSubmitWithMedia: { newContent, mediaFiles, existingUrls in
                viewModel.updatePost(tweetId: tweet.id, text: newContent, existingMediaUrls: existingUrls)
            })
        }
        // ── Reply Bottom Sheet ────────────────────────────────────────────
        // ── Reply Bottom Sheet (Bug #4 fix: uses InsideTalkCommentSheetContainer for live updates) ──
        .sheet(item: $activeCommentTweetId) { tweetId in
            InsideTalkCommentSheetContainer(
                viewModel: viewModel,
                tweetId: tweetId,
                currentUserId: authViewModel.currentUser?.id ?? "",
                isAdmin: authViewModel.currentUser?.isAdmin == true,
                onDismiss: { activeCommentTweetId = nil }
            )
            .presentationDetents([.medium, .large])
            .modifier(SheetBackgroundModifier())
        }
    }

    private var proUpgradeBanner: some View {
        VStack(spacing: 16) {
            Text("🔒")
                .font(.system(size: 48))
            Text("Unlock more with Subscriptions")
                .font(.custom("Cinzel-Regular", size: 20))
                .foregroundStyle(AppTheme.goldGradient)
                .multilineTextAlignment(.center)
            if viewModel.count > 0 {
                Text("@BoAnalyst has shared **\(viewModel.count)** subscriber-only posts.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Text("Subscribe to see their exclusive posts and bonus content.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            GoldButton(title: "SUBSCRIBE") { onSubscribeRequired() }
        }
        .padding(28)
        .cardStyle()
    }
}

// MARK: - InsideTalkCard (updated with live like/comment callbacks)

struct InsideTalkCard: View {
    let content: InsideTalkContent
    let isUserPro: Bool
    var isRewarded: Bool = false
    let onSubscribeRequired: () -> Void
    var onLike: () -> Void = {}
    var onComment: () -> Void = {}
    var onDelete: (() -> Void)? = nil
    var onPin: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil

    // FIXED: A post is "locked" only for non-pro, non-admin users.
    // The old check (content.count < 120) was wrong — it locked short posts for everyone.
    private var isLocked: Bool { !isUserPro }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author header
            HStack(spacing: 8) {
                // Inside Talk posts are always from the BoAnalyst Admin
                // BoAnalystAvatarView: perfectly circular avatar (fixes flat/broken look)
                BoAnalystAvatarView(size: 32, padding: 4)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(content.authorName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(formatRelativeDate(content.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                HStack(spacing: 8) {
                    if content.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.goldGradient)
                    }
                    if onDelete != nil || onPin != nil || onEdit != nil {
                        Menu {
                            if let edit = onEdit {
                                Button(action: edit) {
                                    Label("Edit Post", systemImage: "pencil")
                                }
                            }
                            if let del = onDelete {
                                Button(role: .destructive, action: del) {
                                    Label("Delete Post", systemImage: "trash")
                                }
                            }
                            if let pin = onPin {
                                Button(action: pin) {
                                    Label(content.isPinned ? "Unpin Post" : "Pin Post",
                                          systemImage: content.isPinned ? "pin.slash" : "pin")
                                }
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
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.goldPrimary.opacity(0.6))
                    }
                }
            }

            // Content — extract social embeds, strip raw URLs, render markdown
            let socialEmbeds = (isLocked || isRewarded) ? [] : extractSocialEmbeds(from: content.content)
            let baseCleanText = stripEmbedUrls(from: content.content, embeds: socialEmbeds)
            let cleanText = ((isLocked || isRewarded) && baseCleanText.count > 25) ? String(baseCleanText.prefix(25)) + "..." : baseCleanText
            
            let attrText = ParsedTextCache.shared.parseFlock(cleanText, id: content.id)
            Text(attrText)
                .tint(AppTheme.goldPrimary)
                .font(.system(size: 14))
                .foregroundColor((isLocked || isRewarded) ? AppTheme.goldPrimary : AppTheme.textSecondary)
                .lineLimit((isLocked || isRewarded) ? 2 : nil)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .blur(radius: (isLocked || isRewarded) ? 3.5 : 0)

            // ── Uploaded Media ───────────────────────────────────────
            // resolvedUrl() returns "" for invalid entries; filter those out.
            let mediaUrls = content.media.map { $0.resolvedUrl() }.filter { !$0.isEmpty }
            if !mediaUrls.isEmpty && !isLocked && !isRewarded {
                PostMediaView(urls: mediaUrls)
            }

            // ── Social Embeds (YouTube / X / Instagram) — Pro-only ────────
            if !socialEmbeds.isEmpty {
                SocialEmbedsSection(embeds: socialEmbeds)
            }

            if isLocked || isRewarded {
                Button { onSubscribeRequired() } label: {
                    HStack(spacing: 8) {
                        if isRewarded {
                            Image(systemName: "play.circle").font(.system(size: 12))
                            Text("Watch ad to unlock")
                                .font(.system(size: 12, weight: .semibold))
                        } else {
                            Image(systemName: "crown.fill").font(.system(size: 12))
                            Text("Unlock with Pro — visit boanalyst.com")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(AppTheme.goldGradient)
                    .clipShape(Capsule())
                }
            } else {
                // Engagement row
                HStack(spacing: 16) {
                    Button { onLike() } label: {
                        Label("\(content.likeCount)",
                              systemImage: content.userLiked ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundColor(content.userLiked ? AppTheme.goldPrimary : AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)

                    Button { onComment() } label: {
                        Label("\(content.replyCount)", systemImage: "bubble.left")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    
                    if let shareUrl = URL(string: "https://boanalyst.com/inside-talk/\(content.id)") {
                        ShareLink(item: shareUrl) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}


// MARK: - AnalyticsView (TODO: Full implementation)

struct AnalyticsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var entries: [BoxOfficeEntry] = []
    @State private var isLoading = false
    private let api = APIClient.shared

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
            if isLoading && entries.isEmpty {
                LoadingView()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeader(title: "Box Office Collection", icon: "indianrupeesign.circle.fill")
                        ForEach(entries) { entry in
                            BoxOfficeRow(entry: entry)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .refreshable { await load() }
            }

            // Anchored AdMob Banner — separated from scrollable content (Google recommended)
            if !(authViewModel.currentUser?.isAdFree == true) {
                SwiftUIBannerAd(adUnitId: "ca-app-pub-5734863079459748/8749854605")
                    .frame(height: 50)
                    .padding(.vertical, 4)
                    .background(AppTheme.surface)
            }
            } // end VStack
        }
        .task { await load() }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("ANALYTICS")
                    .font(.custom("Cinzel-Regular", size: 14))
                    .foregroundStyle(AppTheme.goldGradient)
            }
        }
    }

    private func load() async {
        isLoading = true
        // BoxOfficeResponse.data — matches server schema and Models.swift
        if let result = try? await api.request(.getBoxOfficeEntries(language: "all"), responseType: BoxOfficeResponse.self) {
            entries = result.data
        }
        isLoading = false
    }
}

struct BoxOfficeRow: View {
    let entry: BoxOfficeEntry

    private func cleanGross(_ value: String?) -> String {
        guard let value = value else { return "—" }
        return value.replacingOccurrences(of: "cr", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text("India: ₹\(cleanGross(entry.indiaGross)) Cr  •  OS: ₹\(cleanGross(entry.overseasGross)) Cr")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("₹\(cleanGross(entry.worldwideGross)) Cr")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.goldGradient)
                Text("#\(entry.rankNum) Rank")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.goldPrimary)
            }
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - ProfileView

struct ProfileView: View {
    var onSubscribeRequired: () -> Void = {}
    var isPro: Bool = false
    var isAdmin: Bool = false          // Bug #1 fix: was not passed, so admin badge never showed
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showLogoutConfirm = false
    @State private var showEditProfile = false
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showDeleteAccount = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {

                    // ── Avatar ─────────────────────────────────────────────
                    Circle()
                        .fill(AppTheme.goldPrimary.opacity(0.15))
                        .frame(width: 90, height: 90)
                        .overlay(
                            Text(String(authViewModel.currentUser?.name.prefix(1) ?? "?").uppercased())
                                .font(.custom("Cinzel-Regular", size: 36))
                                .foregroundStyle(AppTheme.goldGradient)
                        )
                        .overlay(
                            Circle().stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.top, 20)

                    // ── Name + email + bio + member since ───────────────────────
                    VStack(spacing: 6) {
                        Text(authViewModel.currentUser?.name ?? "")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        if let username = authViewModel.currentUser?.username, !username.isEmpty {
                            Text("@\(username)")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.goldGradient)
                        }

                        Text(authViewModel.currentUser?.email ?? "")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)

                        if let bio = authViewModel.currentUser?.resolvedBio, !bio.isEmpty {
                            Text(bio)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.top, 4)
                        }

                        // Bug #2 fix: show membership duration
                        if let days = authViewModel.currentUser?.memberSinceDays {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.goldGradient)
                                    .offset(y: -1)
                                Text("Member for \(days) day\(days == 1 ? "" : "s")")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // ── Subscription badge ────────────────────────────────
                    subscriptionBadge

                    // ── Settings list ─────────────────────────────────────
                    VStack(spacing: 0) {

                        // Edit Profile — Bug #2 fix: opens EditProfileView modal
                        ProfileRow(icon: "person.circle", title: "Edit Profile") {
                            showEditProfile = true
                        }
                        Divider().background(Color.white.opacity(0.05))




                        // Appearance Toggle
                        Toggle(isOn: $themeManager.isDarkMode) {
                            HStack(spacing: 14) {
                                Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.goldPrimary)
                                    .frame(width: 24)
                                Text("Dark Mode")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                        .tint(AppTheme.goldPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().background(Color.white.opacity(0.05))
                        
                        ProfileRow(icon: "questionmark.circle.fill", title: "Help & Support") {
                            // Opens the mail app gracefully
                            if let url = URL(string: "mailto:appsupport@boanalyst.com?subject=BoAnalyst%20App%20Support") {
                                UIApplication.shared.open(url)
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.05))
                        ProfileRow(icon: "shield", title: "Privacy Policy") {
                            showPrivacy = true
                        }
                        Divider().background(Color.white.opacity(0.05))
                        ProfileRow(icon: "doc.text", title: "Terms of Service") {
                            showTerms = true
                        }
                        Divider().background(Color.white.opacity(0.05))
                        ProfileRow(icon: "arrow.backward.circle", title: "Sign Out", isDestructive: true) {
                            showLogoutConfirm = true
                        }
                        Divider().background(Color.white.opacity(0.05))
                        // Guideline 5.1.1(v) — Account Deletion (required for apps with account creation)
                        ProfileRow(icon: "trash.fill", title: "Delete Account", isDestructive: true) {
                            showDeleteAccount = true
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal, 20)

                    // Version
                    Text("BoAnalyst v1.0.0")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("PROFILE")
                    .font(.custom("Cinzel-Regular", size: 14))
                    .foregroundStyle(AppTheme.goldGradient)
            }
        }
        .confirmationDialog("Sign out of BoAnalyst?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await authViewModel.logout() }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Edit Profile sheet — Bug #2 fix
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authViewModel)
        }
        // In-app browsers for legal pages
        .sheet(isPresented: $showPrivacy) {
            if let url = URL(string: "https://boanalyst.com/privacy") {
                NavigationView {
                    SafariView(url: url).ignoresSafeArea()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showPrivacy = false }
                                    .foregroundStyle(AppTheme.goldGradient)
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showTerms) {
            if let url = URL(string: "https://boanalyst.com/terms") {
                NavigationView {
                    SafariView(url: url).ignoresSafeArea()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showTerms = false }
                                    .foregroundStyle(AppTheme.goldGradient)
                            }
                        }
                }
            }
        }
        // Delete Account flow (Guideline 5.1.1(v))
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountSheet()
                .environmentObject(authViewModel)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Subscription Badge

    @ViewBuilder
    private var subscriptionBadge: some View {
        // Bug #1 fix: was reading prop `isAdmin` which was never passed.
        // Now uses the explicit `isAdmin` parameter passed from MainTabView.
        if isAdmin || authViewModel.currentUser?.isAdmin == true {
            badgePill(label: "⚡ ADMIN", color: AppTheme.error)
        } else if isPro {
            badgePill(label: "⭐ PRO MEMBER", color: AppTheme.goldPrimary)
        } else {
            // Non-pro: show upgrade button
            // Subscription is purchased on boanalyst.com — Netflix/Reader strategy
            GoldOutlineButton(title: "Upgrade to Pro", icon: "crown.fill") {
                onSubscribeRequired()
            }
            .padding(.horizontal, 40)
        }
    }

    private func badgePill(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .tracking(1)
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Delete Account Sheet (Guideline 5.1.1(v))
// Two-step confirmation: first explains consequences, then requires typing "DELETE"
// to prevent accidental account deletion.

struct DeleteAccountSheet: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0            // 0 = warning, 1 = confirm text
    @State private var confirmText = ""
    @State private var isDeleting = false
    @State private var errorMsg: String? = nil

    private var isConfirmValid: Bool {
        confirmText.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE"
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 28) {
                    if step == 0 {
                        warningStep
                    } else {
                        confirmStep
                    }
                    Spacer()
                }
                .padding(.top, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("DELETE ACCOUNT")
                        .font(.custom("Cinzel-Regular", size: 12))
                        .foregroundColor(AppTheme.error)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: Step 0 — Warning

    private var warningStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundColor(AppTheme.error)

            Text("Delete Your Account?")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                warningRow("All your posts and comments will be permanently deleted.")
                warningRow("Your subscription and Pro membership will be cancelled.")
                warningRow("This action cannot be undone.")
            }
            .padding(.horizontal, 24)

            Button {
                step = 1
            } label: {
                Text("I understand, continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.error)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.error.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.error.opacity(0.4), lineWidth: 1))
            }
            .padding(.horizontal, 24)
        }
    }

    private func warningRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.error)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Step 1 — Type DELETE to confirm

    private var confirmStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.fill")
                .font(.system(size: 44))
                .foregroundColor(AppTheme.error)

            VStack(spacing: 6) {
                Text("Confirm Deletion")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text("Type DELETE below to permanently delete your account.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            if let err = errorMsg {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.error)
                    .padding(10)
                    .background(AppTheme.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 24)
            }

            TextField("Type DELETE to confirm", text: $confirmText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .foregroundColor(AppTheme.textPrimary)
                .tint(AppTheme.error)
                .padding(16)
                .background(AppTheme.surfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isConfirmValid ? AppTheme.error : Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 24)

            Button {
                Task { await performDeletion() }
            } label: {
                ZStack {
                    if isDeleting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Permanently Delete Account")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isConfirmValid ? AppTheme.error : AppTheme.error.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isConfirmValid || isDeleting)
            .padding(.horizontal, 24)
        }
    }

    private func performDeletion() async {
        isDeleting = true
        errorMsg = nil
        do {
            try await authViewModel.deleteAccount()
            // authViewModel.deleteAccount() resets uiState — app navigates to login automatically
            dismiss()
        } catch {
            errorMsg = "Unable to delete account. Please check your connection and try again."
        }
        isDeleting = false
    }
}

// MARK: - Edit Profile View (Bug #2 fix: maps to /api/user/profile)

struct EditProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String? = nil
    @State private var successMsg: String? = nil

    private let api = APIClient.shared

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {

                        // Avatar
                        Circle()
                            .fill(AppTheme.goldPrimary.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(name.prefix(1)).uppercased())
                                    .font(.custom("Cinzel-Regular", size: 32))
                                    .foregroundStyle(AppTheme.goldGradient)
                            )
                            .overlay(Circle().stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1))
                            .padding(.top, 20)

                        // Member since
                        if let days = authViewModel.currentUser?.memberSinceDays {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.goldGradient)
                                Text("Member for \(days) day\(days == 1 ? "" : "s")")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                        }

                        // Plan badge
                        if let plan = authViewModel.currentUser?.subscriptionPlan, !plan.isEmpty {
                            Text(plan.uppercased().replacingOccurrences(of: "-", with: " "))
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(AppTheme.goldPrimary)
                                .clipShape(Capsule())
                        }

                        // Error / Success messages
                        if let err = errorMsg {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.error)
                                Text(err)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.error)
                            }
                            .padding(12)
                            .background(AppTheme.error.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 20)
                        }

                        if let ok = successMsg {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.success)
                                Text(ok)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.success)
                            }
                            .padding(12)
                            .background(AppTheme.success.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 20)
                        }

                        // Form fields
                        VStack(spacing: 16) {
                            GoldTextField(placeholder: "Display Name", text: $name, icon: "person")
                            GoldTextField(placeholder: "Username", text: $username, icon: "at")
                                .textInputAutocapitalization(.never)
                            GoldTextField(placeholder: "Bio", text: $bio, icon: "text.quote")
                            GoldTextField(placeholder: "Email (Account)", text: $email, icon: "envelope")
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.horizontal, 20)

                        // Save button
                        GoldButton(title: "Save Changes", isLoading: isSaving) {
                            Task { await saveProfile() }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EDIT PROFILE")
                        .font(.custom("Cinzel-Regular", size: 13))
                        .foregroundStyle(AppTheme.goldGradient)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .onAppear {
            name  = authViewModel.currentUser?.name  ?? ""
            email = authViewModel.currentUser?.email ?? ""
            username = authViewModel.currentUser?.username ?? ""
            bio = authViewModel.currentUser?.resolvedBio ?? ""
        }
    }

    private func saveProfile() async {
        isSaving = true
        errorMsg = nil
        successMsg = nil
        do {
            let endpoint = try APIEndpoint.updateProfile(
                name: name.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email.trimmingCharacters(in: .whitespaces),
                username: username.trimmingCharacters(in: .whitespaces).isEmpty ? nil : username.trimmingCharacters(in: .whitespaces),
                bio: bio.trimmingCharacters(in: .whitespaces).isEmpty ? nil : bio.trimmingCharacters(in: .whitespaces)
            )
            let response = try await api.requestRaw(endpoint)
            if let ok = response["success"] as? Bool, ok {
                // Refresh user data so the UI reflects the name change immediately
                await authViewModel.refreshUser()
                successMsg = "Profile updated successfully!"
                // Auto-dismiss after 1.5s
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            } else {
                errorMsg = (response["message"] as? String) ?? "Update failed. Please try again."
            }
        } catch {
            errorMsg = "Unable to save. Please check your connection."
        }
        isSaving = false
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isDestructive ? AppTheme.error : AppTheme.textSecondary)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(isDestructive ? AppTheme.error : AppTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Create Post Sheet (with media upload support)
// Supports text + image / video / audio attachments.
// Uses iOS PhotosPicker for image/video (no extra entitlements needed).
// Uses fileImporter for audio files.

struct PollCreationData {
    let question: String
    let options: [String]
    let endsAt: String?
}

import PhotosUI

struct CreatePostSheet: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let initialText: String
    let initialMediaUrls: [String]
    let showCategoryPicker: Bool
    let onSubmitText: ((String) async -> Void)?           // plain-text only (legacy)
    let onSubmitMedia: ((String, [(data: Data, mimeType: String, fileName: String)], [String]) async -> Void)?  // text + media + existingUrls
    let onSubmitPoll: ((String, [(data: Data, mimeType: String, fileName: String)], [String], PollCreationData?) async -> Void)?
    let onSubmitPollAndCategory: ((String, String?, [(data: Data, mimeType: String, fileName: String)], [String], PollCreationData?) async -> Void)?

    init(title: String, initialText: String = "", initialMediaUrls: [String] = [], onSubmit: @escaping (String) async -> Void) {
        self.title = title
        self.initialText = initialText
        self.initialMediaUrls = initialMediaUrls
        self.showCategoryPicker = false
        self.onSubmitText = onSubmit
        self.onSubmitMedia = nil
        self.onSubmitPoll = nil
        self.onSubmitPollAndCategory = nil
    }

    init(title: String, initialText: String = "", initialMediaUrls: [String] = [], onSubmitWithMedia: @escaping (String, [(data: Data, mimeType: String, fileName: String)], [String]) async -> Void) {
        self.title = title
        self.initialText = initialText
        self.initialMediaUrls = initialMediaUrls
        self.showCategoryPicker = false
        self.onSubmitText = nil
        self.onSubmitMedia = onSubmitWithMedia
        self.onSubmitPoll = nil
        self.onSubmitPollAndCategory = nil
    }

    init(title: String, initialText: String = "", initialMediaUrls: [String] = [], onSubmitWithPoll: @escaping (String, [(data: Data, mimeType: String, fileName: String)], [String], PollCreationData?) async -> Void) {
        self.title = title
        self.initialText = initialText
        self.initialMediaUrls = initialMediaUrls
        self.showCategoryPicker = false
        self.onSubmitText = nil
        self.onSubmitMedia = nil
        self.onSubmitPoll = onSubmitWithPoll
        self.onSubmitPollAndCategory = nil
    }

    init(title: String, initialText: String = "", initialMediaUrls: [String] = [], showCategoryPicker: Bool = false, onSubmitWithPollAndCategory: @escaping (String, String?, [(data: Data, mimeType: String, fileName: String)], [String], PollCreationData?) async -> Void) {
        self.title = title
        self.initialText = initialText
        self.initialMediaUrls = initialMediaUrls
        self.showCategoryPicker = showCategoryPicker
        self.onSubmitText = nil
        self.onSubmitMedia = nil
        self.onSubmitPoll = nil
        self.onSubmitPollAndCategory = onSubmitWithPollAndCategory
    }

    private let maxLength = 5000
    private let api = APIClient.shared

    @State private var text = ""
    @State private var isPosting = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    struct PostMediaFile: Identifiable {
        let id = UUID()
        let data: Data
        let mimeType: String
        let fileName: String
        let preview: SwiftUI.Image?
    }
    
    @State private var mediaFiles: [PostMediaFile] = []
    @State private var existingMediaUrls: [String] = []  // seeded from initialMediaUrls on appear; mutable so user can delete
    @State private var showAudioPicker = false
    @State private var selectedCategory: String = "Entertainment"

    @State private var isPollEnabled = false
    @State private var pollQuestion = ""
    @State private var pollOptions = ["", ""]
    @State private var pollEndsAt: Date? = nil
    @State private var showDatePicker = false

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isOverLimit: Bool { text.count > maxLength }
    private var canPost: Bool { (!trimmed.isEmpty || !mediaFiles.isEmpty || !existingMediaUrls.isEmpty) && !isOverLimit && !isPosting }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if showCategoryPicker {
                            let postCategories = ["Entertainment", "Politics", "Sports", "Business", "Technology"]
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(postCategories, id: \.self) { cat in
                                        Button(action: {
                                            selectedCategory = cat
                                        }) {
                                            Text(cat)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(selectedCategory == cat ? AppTheme.goldPrimary : AppTheme.textSecondary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(selectedCategory == cat ? AppTheme.goldPrimary.opacity(0.2) : AppTheme.surfaceVariant)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.top, 16)
                        }

                        // Text editor
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $text)
                                .font(.system(size: 15))
                                .scrollContentBackground(.hidden)
                                .background(AppTheme.surfaceVariant.opacity(0.3))
                                .foregroundColor(AppTheme.textPrimary)
                                .cornerRadius(12)
                                .frame(minHeight: 140)
                                .padding()
                                .onChange(of: text) { newValue in
                                    if newValue.count > maxLength {
                                        text = String(newValue.prefix(maxLength))
                                    }
                                }
                            if text.isEmpty {
                                Text("What's on your mind?")
                                    .foregroundColor(AppTheme.textMuted)
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 24)
                                    .allowsHitTesting(false)
                            }
                        }

                        // Formatting controls — ** bold (same as Android/web markdown)
                        HStack(spacing: 10) {
                            // Bold: inserts **bold text** markers — type between them
                            Button(action: {
                                let insertion = "**bold text**"
                                if text.isEmpty || text.last == "\n" {
                                    text += insertion
                                } else {
                                    text += " " + insertion
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("B").bold().font(.system(size: 14))
                                    Text("**").font(.system(size: 10)).opacity(0.6)
                                }
                                .frame(height: 32)
                                .padding(.horizontal, 10)
                                .background(AppTheme.surfaceVariant)
                                .cornerRadius(6)
                            }
                            // Italic: inserts _italic text_
                            Button(action: {
                                let insertion = "_italic text_"
                                text += text.isEmpty ? insertion : " " + insertion
                            }) {
                                HStack(spacing: 4) {
                                    Text("I").italic().font(.system(size: 14))
                                    Text("_").font(.system(size: 10)).opacity(0.6)
                                }
                                .frame(height: 32)
                                .padding(.horizontal, 10)
                                .background(AppTheme.surfaceVariant)
                                .cornerRadius(6)
                            }
                            // Underline marker (displayed as ~~ in text, stripped by parser)
                            Button(action: {
                                let insertion = "__underlined text__"
                                text += text.isEmpty ? insertion : " " + insertion
                            }) {
                                HStack(spacing: 4) {
                                    Text("U").underline().font(.system(size: 14))
                                    Text("__").font(.system(size: 10)).opacity(0.6)
                                }
                                .frame(height: 32)
                                .padding(.horizontal, 10)
                                .background(AppTheme.surfaceVariant)
                                .cornerRadius(6)
                            }
                            Spacer()
                        }
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, 16)

                        // Character counter
                        HStack {
                            Spacer()
                            Text("\(text.count)/\(maxLength)")
                                .font(.system(size: 11))
                                .foregroundColor(isOverLimit ? AppTheme.error : AppTheme.textMuted)
                                .padding(.horizontal, 20)
                        }

                        // Media attachment area
                        VStack(alignment: .leading, spacing: 10) {
                            // ── Existing media (from server) — deletable thumbnails ──
                            if !existingMediaUrls.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Existing Media (tap ✕ to remove)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.textMuted)
                                        .padding(.horizontal, 20)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(existingMediaUrls, id: \.self) { urlStr in
                                                ZStack(alignment: .topTrailing) {
                                                    if let url = URL(string: urlStr) {
                                                        CachedAsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .success(let image):
                                                                image.resizable().scaledToFill()
                                                            default:
                                                                Rectangle().fill(AppTheme.surfaceVariant)
                                                                    .overlay(Image(systemName: "photo").foregroundColor(AppTheme.textMuted))
                                                            }
                                                        }
                                                        .frame(width: 100, height: 100)
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    }
                                                    Button {
                                                        if let idx = existingMediaUrls.firstIndex(of: urlStr) {
                                                            existingMediaUrls.remove(at: idx)
                                                        }
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.system(size: 26))
                                                            .foregroundColor(.white)
                                                            .background(Color.red.opacity(0.8), in: Circle())
                                                            .padding(10)
                                                            .contentShape(Rectangle())
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }

                            Text("Attach New Media (\(mediaFiles.count)/4)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.textMuted)
                                .padding(.horizontal, 20)

                            HStack(spacing: 12) {
                                // Image / Video picker
                                if mediaFiles.count < 4 {
                                    PhotosPicker(
                                        selection: $selectedPhotoItems,
                                        maxSelectionCount: 4 - mediaFiles.count,
                                        matching: .any(of: [.images, .videos]),
                                        photoLibrary: .shared()
                                    ) {
                                        attachmentButton(icon: "photo.on.rectangle", label: "Photo/Video")
                                    }
                                    .onChange(of: selectedPhotoItems) { items in
                                        Task { await loadPhotos(items) }
                                    }

                                    // Audio / document picker
                                    Button { showAudioPicker = true } label: {
                                        attachmentButton(icon: "waveform", label: "Audio")
                                    }
                                }
                                
                                if onSubmitPoll != nil {
                                    Button {
                                        withAnimation { isPollEnabled.toggle() }
                                    } label: {
                                        attachmentButton(icon: "chart.bar.fill", label: "Poll")
                                            .foregroundColor(isPollEnabled ? AppTheme.goldPrimary : AppTheme.textMuted)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Poll UI
                            if isPollEnabled {
                                VStack(spacing: 12) {
                                    TextField("Ask a question...", text: $pollQuestion)
                                        .padding()
                                        .background(AppTheme.surfaceVariant)
                                        .cornerRadius(8)
                                        .foregroundColor(AppTheme.textPrimary)
                                    
                                    ForEach(0..<pollOptions.count, id: \.self) { idx in
                                        HStack {
                                            TextField("Option \(idx + 1)", text: $pollOptions[idx])
                                                .padding()
                                                .background(AppTheme.surfaceVariant)
                                                .cornerRadius(8)
                                                .foregroundColor(AppTheme.textPrimary)
                                            
                                            if pollOptions.count > 2 {
                                                Button(action: { pollOptions.remove(at: idx) }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(AppTheme.error)
                                                }
                                            }
                                        }
                                    }
                                    
                                    if pollOptions.count < 4 {
                                        Button(action: { pollOptions.append("") }) {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Add Option")
                                            }
                                            .foregroundColor(AppTheme.goldPrimary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    
                                    HStack {
                                        Text(pollEndsAt == nil ? "Set End Date & Time" : "Ends: \(ISO8601DateFormatter().string(from: pollEndsAt!))")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Button("Select") {
                                            showDatePicker = true
                                        }
                                        .foregroundColor(AppTheme.goldPrimary)
                                    }
                                    .padding()
                                    .background(AppTheme.surfaceVariant)
                                    .cornerRadius(8)
                                    
                                    if showDatePicker {
                                        DatePicker("Select Date", selection: Binding(
                                            get: { pollEndsAt ?? Date().addingTimeInterval(86400) },
                                            set: { pollEndsAt = $0 }
                                        ), in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                        .colorScheme(.dark)
                                        .accentColor(AppTheme.goldPrimary)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }

                            // Preview thumbnails
                            if !mediaFiles.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(mediaFiles) { file in
                                            ZStack(alignment: .topTrailing) {
                                                if let img = file.preview {
                                                    img
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 100, height: 100)
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                } else {
                                                    VStack(spacing: 8) {
                                                        Image(systemName: file.mimeType.contains("video") ? "video.fill" : "waveform")
                                                            .foregroundStyle(AppTheme.goldGradient)
                                                        Text(file.fileName)
                                                            .font(.system(size: 10))
                                                            .foregroundColor(AppTheme.textSecondary)
                                                            .lineLimit(1)
                                                    }
                                                    .frame(width: 100, height: 100)
                                                    .background(AppTheme.surfaceVariant.opacity(0.5))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                }
                                                
                                                Button {
                                                    if let idx = mediaFiles.firstIndex(where: { $0.id == file.id }) {
                                                        mediaFiles.remove(at: idx)
                                                    }
                                                } label: {
                                                    Image(systemName: "xmark.circle")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(AppTheme.error)
                                                        .background(Color.black.opacity(0.6), in: Circle())
                                                }
                                                .padding(4)
                                                .offset(x: 4, y: -4)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        Task { await submitPost() }
                    }
                    .bold()
                    .foregroundColor(canPost ? AppTheme.goldPrimary : AppTheme.textMuted)
                    .disabled(!canPost)
                }
            }
        }
        .onAppear {
            text = initialText
            if existingMediaUrls.isEmpty {
                existingMediaUrls = initialMediaUrls
            }
        }
        .fileImporter(
            isPresented: $showAudioPicker,
            allowedContentTypes: [.audio, .mp3, .mpeg4Audio],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first,
               url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    mediaFiles.append(PostMediaFile(data: data, mimeType: "audio/mpeg", fileName: url.lastPathComponent, preview: nil))
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentButton(icon: String, label: String, tint: Color = AppTheme.goldPrimary) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(tint)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(width: 70, height: 60)
        .background(AppTheme.surfaceVariant.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.3), lineWidth: 1))
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
                    mediaFiles.append(PostMediaFile(data: data, mimeType: "video/mp4", fileName: "video_\(UUID().uuidString.prefix(6)).mp4", preview: nil))
                } else {
                    let preview = UIImage(data: data).map { SwiftUI.Image(uiImage: $0) }
                    mediaFiles.append(PostMediaFile(data: data, mimeType: "image/jpeg", fileName: "photo_\(UUID().uuidString.prefix(6)).jpg", preview: preview))
                }
            }
        }
        // Reset selections to allow more
        selectedPhotoItems = []
    }

    private func submitPost() async {
        isPosting = true
        let files = mediaFiles.map { (data: $0.data, mimeType: $0.mimeType, fileName: $0.fileName) }
        
        if let pollAndCatHandler = onSubmitPollAndCategory {
            var pollData: PollCreationData? = nil
            if isPollEnabled {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let endsAtStr = pollEndsAt != nil ? formatter.string(from: pollEndsAt!) : nil
                pollData = PollCreationData(question: pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines), options: pollOptions.filter { !$0.isEmpty }, endsAt: endsAtStr)
            }
            await pollAndCatHandler(trimmed, selectedCategory, files, existingMediaUrls, pollData)
        } else if let pollHandler = onSubmitPoll {
            var pollData: PollCreationData? = nil
            if isPollEnabled {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let endsAtStr = pollEndsAt != nil ? formatter.string(from: pollEndsAt!) : nil
                pollData = PollCreationData(question: pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines), options: pollOptions.filter { !$0.isEmpty }, endsAt: endsAtStr)
            }
            await pollHandler(trimmed, files, existingMediaUrls, pollData)
        } else if let mediaHandler = onSubmitMedia {
            await mediaHandler(trimmed, files, existingMediaUrls)
        } else if let textHandler = onSubmitText {
            await textHandler(trimmed)
        }
        isPosting = false
        dismiss()
    }
}

// MARK: - Compatibility Modifiers

struct SheetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(AppTheme.card)
        } else {
            content.background(AppTheme.card)
        }
    }
}

// MARK: - FlockPostDetailSheet (Parity with Android PostDetailScreen.kt)

struct FlockPostDetailSheet: View {
    let postId: String
    @EnvironmentObject private var flockVM: FlockViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var post: FlockPost? = nil
    @State private var isLoading = true
    @State private var adStep = "INITIAL"
    @StateObject private var adManager = InterstitialAdManager()
    @EnvironmentObject private var rewardedAdManager: RewardedAdManager
    @State private var showLoginAlert = false
    @State private var loginAlertMessage = ""
    
    private var isLoggedIn: Bool {
        authViewModel.currentUser != nil
    }
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView().tint(AppTheme.goldPrimary)
            } else if adStep != "CONTENT" {
                // Progressive elegant ad-wall loading overlay
                VStack(spacing: 24) {
                    Text("BoAnalyst")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(AppTheme.goldPrimary)
                        
                    Text("Sponsor Access Verification")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        
                    VStack(spacing: 16) {
                        ProgressView().tint(AppTheme.goldPrimary)
                        
                        let stepTitle = adStep == "INITIAL" ? "Verifying..." : (adStep.hasPrefix("INTERSTITIAL") ? "Step 1 of 2" : "Step 2 of 2")
                        let stepDesc = adStep == "INITIAL" ? "Validating content authentication..." : (adStep.hasPrefix("INTERSTITIAL") ? "Preparing Premium Sponsor Presentation..." : "Unlocking Exclusive Post Video...")
                        
                        Text(stepTitle)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.goldPrimary)
                            
                        Text(stepDesc)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(AppTheme.surfaceVariant.opacity(0.8))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 32)
                    
                    Text("Content will unlock automatically")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted.opacity(0.7))
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.top, 12)
                }
            } else if let post = post {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        Spacer()
                        Text("Post Details")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Color.clear.frame(width: 24, height: 24)
                    }
                    .padding()
                    .background(AppTheme.surface)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                let isAdmin = authViewModel.currentUser?.isAdmin == true
                                FlockPostCard(
                                    post: post,
                                    isAdmin: isAdmin,
                                    isLiked: flockVM.likedPostIds.contains(post.id),
                                    isUnlocked: true, // already unlocked via ad progression
                                    onTap: {},
                                    onLike: {
                                        if isLoggedIn {
                                            flockVM.toggleLike(post)
                                        } else {
                                            loginAlertMessage = "Sign up or log in to like posts"
                                            showLoginAlert = true
                                        }
                                    },
                                    onComment: {
                                        if isLoggedIn {
                                            withAnimation {
                                                proxy.scrollTo("commentsSection", anchor: .top)
                                            }
                                        } else {
                                            loginAlertMessage = "Sign up or log in to comment on posts"
                                            showLoginAlert = true
                                        }
                                    },
                                    onDelete: isAdmin ? { flockVM.deletePost(post); dismiss() } : {},
                                    onPin: isAdmin ? { flockVM.togglePin(post) } : {},
                                    onEdit: nil,
                                    onVote: { pollId, optionId in
                                        if isLoggedIn {
                                            flockVM.voteOnPoll(postId: post.id, pollId: pollId, optionId: optionId)
                                        } else {
                                            loginAlertMessage = "Sign up or log in to vote on polls"
                                            showLoginAlert = true
                                        }
                                    }
                                )
                                .padding(.horizontal, 16)
                                
                                // Live comments for this single post!
                                Divider().background(Color.white.opacity(0.08))
                                    .id("commentsSection")
                                
                                let comments = flockVM.commentsState[post.id] ?? []
                                let commentsLoading = flockVM.commentsLoadingSet.contains(post.id)
                                
                                if commentsLoading && comments.isEmpty {
                                    ProgressView().tint(AppTheme.goldPrimary).padding(20)
                                } else if comments.isEmpty {
                                    Text("No comments yet. Write a comment below!")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.textMuted)
                                        .padding(20)
                                } else {
                                    LazyVStack(alignment: .leading, spacing: 12) {
                                        ForEach(comments) { c in
                                            commentRow(c)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Composer
                    commentComposer
                }
            } else {
                VStack(spacing: 12) {
                    Text("Post not found")
                        .foregroundColor(AppTheme.textPrimary)
                    Button("Close") { dismiss() }
                        .foregroundColor(AppTheme.goldPrimary)
                }
            }
        }
        .task {
            await loadPost()
        }
        .onChange(of: adStep) { step in
            handleAdProgression(step: step)
        }
        .alert("Sign In Required", isPresented: $showLoginAlert) {
            Button("Sign In") {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(loginAlertMessage)
        }
    }
    
    @State private var commentText = ""
    
    private var commentComposer: some View {
        HStack(spacing: 10) {
            if isLoggedIn {
                TextField("Write a comment…", text: $commentText)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textPrimary)
                    .accentColor(AppTheme.goldPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                
                Button {
                    let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    flockVM.addComment(postId: postId, text: trimmed)
                    commentText = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? AnyShapeStyle(Color.gray.opacity(0.3))
                                         : AnyShapeStyle(AppTheme.goldGradient))
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Button {
                    loginAlertMessage = "Sign up or log in to comment on posts"
                    showLoginAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 16))
                        Text("Sign in to comment")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.goldPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.goldPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
    }
    
    private func commentRow(_ c: AppComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            let authorStr = c.authorName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if authorStr.contains("boanalyst") || authorStr.contains("admin") {
                BoAnalystAvatarView(size: 32, padding: 4)
            } else {
                Circle()
                    .fill(AppTheme.goldPrimary.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(c.authorName.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.goldGradient)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(c.authorName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text(formatRelativeDate(c.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }
                
                Text(c.content)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }
    
    private func loadPost() async {
        isLoading = true
        // 1. Check if post is already in VM feed
        if let existing = flockVM.posts.first(where: { $0.id == postId }) {
            self.post = existing
        } else {
            // 2. Fetch single post from backend
            if let fetched = await flockVM.fetchSinglePost(id: postId) {
                self.post = fetched
            }
        }
        
        isLoading = false
        
        if let post = post {
            flockVM.loadComments(postId: post.id)
            if adStep == "INITIAL" {
                let isSuper = post.content.lowercased().contains("#boanalystsuper")
                let isExclusive = post.content.lowercased().contains("#boanalystexclusive") || post.showRewarded
                if isSuper || isExclusive {
                    adStep = "INTERSTITIAL_PREPARE"
                } else {
                    adStep = "CONTENT"
                }
            }
        } else {
            if adStep == "INITIAL" {
                adStep = "CONTENT"
            }
        }
    }
    
    private func handleAdProgression(step: String) {
        Task {
            if step == "INTERSTITIAL_PREPARE" {
                var attempts = 0
                while !adManager.isAdLoaded && attempts < 45 {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    attempts += 1
                }
                if adManager.isAdLoaded {
                    adStep = "INTERSTITIAL_PLAYING"
                    InterstitialAdController.showAd(manager: adManager) {
                        adStep = "REWARDED_PREPARE"
                    }
                } else {
                    adStep = "REWARDED_PREPARE"
                }
            } else if step == "REWARDED_PREPARE" {
                var attempts = 0
                while !rewardedAdManager.isAdLoaded && attempts < 45 {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    attempts += 1
                }
                if rewardedAdManager.isAdLoaded {
                    // Small delay to allow the Interstitial dismissal animation to completely finish in UIKit
                    // Otherwise UIKit ignores the new present() request and we get stuck on "Loading Premium Content"
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    
                    adStep = "REWARDED_PLAYING"
                    RewardedAdController.showAd(
                        manager: rewardedAdManager,
                        onRewardEarned: {
                            adStep = "CONTENT"
                        },
                        onDismissedWithoutReward: {
                            // User dismissed early — retry (reload ad + re-enter REWARDED_PREPARE)
                            adStep = "REWARDED_PREPARE"
                        }
                    )
                } else {
                    adStep = "CONTENT"
                }
            }
        }
    }
}
