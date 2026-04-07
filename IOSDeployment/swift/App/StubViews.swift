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

struct CommentBottomSheet: View {
    let postId: String
    let comments: [AppComment]
    let isLoading: Bool
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
                Text("Comments")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider().background(Color.white.opacity(0.08))

            if isLoading {
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

            Spacer()

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
            Circle()
                .fill(AppTheme.goldPrimary.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(c.authorName.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.goldGradient)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(c.authorName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text(String(c.createdAt.prefix(10)))
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
                Text(c.content)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
        if let result = try? await api.request(
            .getFlockPosts(offset: offset, limit: 20),
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

    func createPost(content: String) async {
        guard let endpoint = try? APIEndpoint.createFlockPost(content: content) else { return }
        _ = try? await api.request(endpoint, responseType: MessageResponse.self)
        await loadFeed()
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
            guard let endpoint = try? APIEndpoint.addComment(postId: postId, text: text),
                  let result = try? await api.request(endpoint, responseType: AddCommentResponse.self),
                  let raw = result.resolvedComment else { return }
            let comment = AppComment(id: raw.id, authorName: raw.authorName,
                                     content: raw.content, createdAt: raw.createdAt, userId: raw.userId ?? "")
            var list = commentsState[postId] ?? []
            list.append(comment)
            commentsState[postId] = list
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

// MARK: - FlockFeedView (full feature implementation)

struct FlockFeedView: View {
    @EnvironmentObject private var flockVM: FlockViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var activeCommentPostId: String? = nil
    @State private var showCreatePost = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if flockVM.isLoading && flockVM.posts.isEmpty {
                LoadingView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // ── Trending strip ──────────────────────────────
                        if !flockVM.trendingTopics.isEmpty {
                            TrendingStrip(trends: flockVM.trendingTopics)
                                .padding(.bottom, 8)
                        }

                        // ── Posts ────────────────────────────────────────
                        if flockVM.posts.isEmpty {
                            emptyState
                        } else {
                            ForEach(flockVM.posts) { post in
                                let isAdmin = authViewModel.currentUser?.isAdmin == true
                                FlockPostCard(
                                    post: post,
                                    isAdmin: isAdmin,
                                    isLiked: flockVM.likedPostIds.contains(post.id),
                                    onTap: {},
                                    onLike: { flockVM.toggleLike(post) },
                                    onComment: {
                                        flockVM.loadComments(postId: post.id)
                                        activeCommentPostId = post.id
                                    },
                                    onDelete: { flockVM.deletePost(post) },
                                    onPin: { flockVM.togglePin(post) }
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
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
        }
        .task { if flockVM.posts.isEmpty { await flockVM.loadFeed() } }
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
            CreatePostSheet(title: "New Flock Post") { text in
                await flockVM.createPost(content: text)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("FLOCK FEED")
                    .font(.custom("Cinzel-Regular", size: 14))
                    .foregroundStyle(AppTheme.goldGradient)
            }
        }
        // ── Comment Bottom Sheet ──────────────────────────────────────────
        .sheet(item: $activeCommentPostId) { postId in
            CommentBottomSheet(
                postId: postId,
                comments: flockVM.commentsState[postId] ?? [],
                isLoading: flockVM.commentsLoadingSet.contains(postId),
                currentUserId: authViewModel.currentUser?.id ?? "",
                isAdmin: authViewModel.currentUser?.isAdmin == true,
                onDismiss: { activeCommentPostId = nil },
                onSubmit: { text in flockVM.addComment(postId: postId, text: text) },
                onDelete: { commentId in flockVM.deleteComment(postId: postId, commentId: commentId) }
            )
            .presentationDetents([.medium, .large])
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

    func createPost(text: String) async {
        guard let endpoint = try? APIEndpoint.createInsideTalkPost(text: text) else { return }
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
            guard let endpoint = try? APIEndpoint.addInsideTalkReply(tweetId: tweetId, text: text),
                  let result = try? await api.request(endpoint, responseType: InsideTalkReplyResponse.self),
                  let raw = result.resolvedReply else { return }
            let reply = AppComment(id: raw.id, authorName: raw.authorName,
                                   content: raw.content, createdAt: raw.createdAt, userId: raw.userId ?? "")
            var list = repliesState[tweetId] ?? []
            list.append(reply)
            repliesState[tweetId] = list
            tweets = tweets.map { t in
                guard t.id == tweetId else { return t }
                return InsideTalkContent(from: t, replyCount: t.replyCount + 1)
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
}

// MARK: - InsideTalkView (full feature implementation)

struct InsideTalkView: View {
    var onSubscribeRequired: () -> Void = {}
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = InsideTalkViewModel()

    @State private var activeCommentTweetId: String? = nil
    @State private var showCreatePost = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            if viewModel.isLoading && viewModel.tweets.isEmpty {
                LoadingView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Non-pro upgrade banner (scrollable, mirrors Android)
                        if !(authViewModel.currentUser?.isPro ?? false) {
                            proUpgradeBanner
                                .padding(.horizontal, 16)
                        }

                        let isPro = authViewModel.currentUser?.isPro ?? false
                        ForEach(viewModel.tweets) { tweet in
                            InsideTalkCard(
                                content: tweet,
                                isUserPro: isPro,
                                onSubscribeRequired: onSubscribeRequired,
                                onLike: { viewModel.toggleLike(tweet) },
                                onComment: {
                                    viewModel.loadReplies(tweetId: tweet.id)
                                    activeCommentTweetId = tweet.id
                                }
                            )
                            .padding(.horizontal, 16)
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
        }
        .task { if viewModel.tweets.isEmpty { await viewModel.loadAll() } }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("INSIDE TALK")
                    .font(.custom("Cinzel-Regular", size: 14))
                    .foregroundStyle(AppTheme.goldGradient)
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
            CreatePostSheet(title: "New Inside Talk") { text in
                await viewModel.createPost(text: text)
            }
        }
        // ── Reply Bottom Sheet ────────────────────────────────────────────
        .sheet(item: $activeCommentTweetId) { tweetId in
            CommentBottomSheet(
                postId: tweetId,
                comments: viewModel.repliesState[tweetId] ?? [],
                isLoading: viewModel.repliesLoadingSet.contains(tweetId),
                currentUserId: authViewModel.currentUser?.id ?? "",
                isAdmin: authViewModel.currentUser?.isAdmin == true,
                onDismiss: { activeCommentTweetId = nil },
                onSubmit: { text in viewModel.addReply(tweetId: tweetId, text: text) },
                onDelete: { replyId in viewModel.deleteReply(tweetId: tweetId, replyId: replyId) }
            )
            .presentationDetents([.medium, .large])
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
    let onSubscribeRequired: () -> Void
    var onLike: () -> Void = {}
    var onComment: () -> Void = {}

    // A post is considered "teaser only" when the server returns short content
    // (< 120 chars — server truncates for non-pro). Pro users see full content.
    private var isLocked: Bool {
        !isUserPro && content.content.count < 120
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author header
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.goldPrimary.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(content.authorName.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.goldGradient)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(content.authorName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(content.createdAt.prefix(10).description)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                if content.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.goldGradient)
                }
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.goldPrimary.opacity(0.6))
                }
            }

            // Content text (blurred when locked)
            Text(content.content)
                .font(.system(size: 13))
                .foregroundColor(isLocked ? AppTheme.textMuted : AppTheme.textPrimary)
                .lineLimit(isLocked ? 2 : nil)
                .lineSpacing(3)
                .blur(radius: isLocked ? 2.5 : 0)

            if isLocked {
                Button { onSubscribeRequired() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill").font(.system(size: 12))
                        Text("Unlock with Pro — visit boanalyst.com")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(AppTheme.goldGradient)
                    .clipShape(Capsule())
                }
            } else {
                // Engagement row — only for unlocked pro content
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
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}


// MARK: - AnalyticsView (TODO: Full implementation)

struct AnalyticsView: View {
    @State private var entries: [BoxOfficeEntry] = []
    @State private var isLoading = false
    private let api = APIClient.shared

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
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
        if let result = try? await api.request(.getBoxOfficeEntries, responseType: BoxOfficeResponse.self) {
            entries = result.data
        }
        isLoading = false
    }
}

struct BoxOfficeRow: View {
    let entry: BoxOfficeEntry

    private var verdictColor: Color {
        switch entry.verdictColor.lowercased() {
        case "green":  return AppTheme.success
        case "red":    return AppTheme.error
        case "yellow": return AppTheme.warning
        default:       return AppTheme.goldPrimary
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text("Budget: ₹\(entry.budget) Cr")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("₹\(entry.collection) Cr")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.goldGradient)
                Text(entry.verdict)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(verdictColor)
            }
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - ProfileView

struct ProfileView: View {
    var onSubscribeRequired: () -> Void = {}
    var isDistributor: Bool = false
    var isPro: Bool = false
    var isAdmin: Bool = false          // Bug #1 fix: was not passed, so admin badge never showed
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showLogoutConfirm = false
    @State private var showEditProfile = false
    @State private var showPrivacy = false
    @State private var showTerms = false

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

                    // ── Name + email + member since ───────────────────────
                    VStack(spacing: 4) {
                        Text(authViewModel.currentUser?.name ?? "")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(authViewModel.currentUser?.email ?? "")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)

                        // Bug #2 fix: show membership duration
                        if let days = authViewModel.currentUser?.memberSinceDays {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.goldGradient)
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

                        ProfileRow(icon: "bell", title: "Notifications") {}
                        Divider().background(Color.white.opacity(0.05))

                        // Distributors Hub — gated
                        if isDistributor || isAdmin {
                            NavigationLink {
                                DistributorsHubView(
                                    isUserDistributor: true,
                                    onSubscribeRequired: onSubscribeRequired
                                )
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "film.stack.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(AppTheme.goldGradient)
                                        .frame(width: 24)
                                    Text("Distributors Hub")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        } else {
                            ProfileRow(icon: "film.stack.fill", title: "Distributors Hub") {
                                onSubscribeRequired()
                            }
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
    }

    // MARK: - Subscription Badge

    @ViewBuilder
    private var subscriptionBadge: some View {
        // Bug #1 fix: was reading prop `isAdmin` which was never passed.
        // Now uses the explicit `isAdmin` parameter passed from MainTabView.
        if isAdmin || authViewModel.currentUser?.isAdmin == true {
            badgePill(label: "⚡ ADMIN", color: AppTheme.error)
        } else if isDistributor {
            badgePill(label: "🎬 DISTRIBUTOR", color: AppTheme.goldPrimary)
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

// MARK: - Edit Profile View (Bug #2 fix: maps to /api/user/profile)

struct EditProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var email: String = ""
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
                            GoldTextField(placeholder: "Full Name", text: $name, icon: "person")
                            GoldTextField(placeholder: "Email", text: $email, icon: "envelope")
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
        }
    }

    private func saveProfile() async {
        isSaving = true
        errorMsg = nil
        successMsg = nil
        do {
            let endpoint = try APIEndpoint.updateProfile(
                name: name.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email.trimmingCharacters(in: .whitespaces)
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
