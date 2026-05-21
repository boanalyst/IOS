//
//  BuzzBoardView.swift
//  BoAnalyst
//
//  Created by BoAnalyst on 2026.
//

import SwiftUI

struct BuzzBoardView: View {
    @State private var posts: [BuzzPost] = []
    @State private var isLoading = true
    @State private var offset = 0
    @State private var hasMore = true
    @State private var selectedCategory: BuzzCategory = .all
    @State private var showCreatePost = false
    @State private var showError = false
    @State private var errorMessage = ""
    @StateObject private var adManager = InterstitialAdManager()
    @State private var selectedPost: BuzzPost?
    @State private var isNavigatingToPost = false
    private var userToken: String { KeychainManager.shared.getToken() ?? "" }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0D0D0D"), Color(hex: "1A1A1A")]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Buzz Board")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { showCreatePost = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "D4AF37"))
                    }
                }
                .padding()

                // Category Filter ScrollView
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BuzzCategory.allCases) { category in
                            CategoryPill(category: category, isSelected: selectedCategory == category) {
                                selectedCategory = category
                                refreshPosts()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }

                if isLoading && posts.isEmpty {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "D4AF37")))
                        .scaleEffect(1.5)
                    Spacer()
                } else if posts.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No discussions yet.")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Be the first to start a conversation!")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.8))
                        Button("Create Post") {
                            showCreatePost = true
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "D4AF37"))
                        .foregroundColor(.black)
                        .cornerRadius(20)
                        .padding(.top, 8)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(posts) { post in
                                Button(action: {
                                    // Check if this post is flagged for an ad via hashtag
                                    let contentLower = post.content.lowercased()
                                    if contentLower.contains("#boad") || contentLower.contains("#interstitial") {
                                        InterstitialAdController.showAd(manager: adManager) {
                                            self.selectedPost = post
                                            self.isNavigatingToPost = true
                                        }
                                    } else {
                                        // No ad required, navigate immediately
                                        self.selectedPost = post
                                        self.isNavigatingToPost = true
                                    }
                                }) {
                                    BuzzPostCard(post: post)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onAppear {
                                    if post.id == posts.last?.id && hasMore {
                                        loadMore()
                                    }
                                }
                            }

                            if isLoading && !posts.isEmpty {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        refreshPosts()
                    }
                    .navigationDestination(isPresented: $isNavigatingToPost) {
                        if let post = selectedPost {
                            BuzzPostDetailView(post: post) { updatedPost in
                                updatePostInList(updatedPost)
                            }
                        }
                    }
                }

                // Anchored AdMob Banner — separated from scrollable content (Google recommended)
                SwiftUIBannerAd(adUnitId: "ca-app-pub-5734863079459748/8749854605")
                    .frame(height: 50)
                    .padding(.vertical, 4)
                    .background(Color(hex: "1A1A1A"))
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreateBuzzPostView { newPost in
                posts.insert(newPost, at: 0)
            }
        }
        .onAppear {
            if posts.isEmpty {
                loadPosts()
            }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func loadPosts() {
        isLoading = true
        let endpoint = APIEndpoint.getBuzzPosts(category: selectedCategory.rawValue, offset: offset)
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        if !userToken.isEmpty {
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data, error == nil else {
                    self.errorMessage = error?.localizedDescription ?? "Network error"
                    self.showError = true
                    return
                }

                do {
                    let res = try JSONDecoder().decode(BuzzPostsResponse.self, from: data)
                    if res.success {
                        if self.offset == 0 {
                            self.posts = res.posts
                        } else {
                            self.posts.append(contentsOf: res.posts)
                        }
                        self.hasMore = res.hasMore ?? (res.posts.count >= 20)
                        self.offset += res.posts.count
                    }
                } catch {
                    print("Decode error: \(error)")
                }
            }
        }.resume()
    }

    private func refreshPosts() {
        offset = 0
        hasMore = true
        loadPosts()
    }

    private func loadMore() {
        guard !isLoading && hasMore else { return }
        loadPosts()
    }

    private func updatePostInList(_ updatedPost: BuzzPost) {
        if let idx = posts.firstIndex(where: { $0.id == updatedPost.id }) {
            posts[idx] = updatedPost
        }
    }
}

// MARK: - Subcomponents

struct CategoryPill: View {
    let category: BuzzCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                Text(category.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color(hex: "D4AF37") : Color.white.opacity(0.1))
            .foregroundColor(isSelected ? .black : .white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(hex: "D4AF37").opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
    }
}

struct BuzzPostCard: View {
    let post: BuzzPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author & Time
            HStack {
                Circle()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color(hex: "D4AF37"), Color(hex: "FFDF00")]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .overlay(Text(String(post.authorName.prefix(1).uppercased())).font(.system(size: 16, weight: .bold)).foregroundColor(.black))

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(post.authorName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        if post.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundColor(Color(hex: "D4AF37"))
                                .font(.system(size: 12))
                        }
                    }
                    HStack(spacing: 6) {
                        Text(post.buzzCategory.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "D4AF37").opacity(0.2))
                            .foregroundColor(Color(hex: "D4AF37"))
                            .cornerRadius(4)
                        Text(formatDate(post.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }

            // Title
            Text(post.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)

            // Content — extract embeds
            let socialEmbeds = extractSocialEmbeds(from: post.content)
            let cleanContent = stripEmbedUrls(from: post.content, embeds: socialEmbeds)
            
            BuzzFormattedText(text: cleanContent, color: .gray, fontSize: 15, lineLimit: 3)

            // Render uploaded images in feed card
            let mediaUrls = post.resolvedMediaUrls()
            if !mediaUrls.isEmpty {
                PostMediaView(urls: mediaUrls)
            }
            
            if !socialEmbeds.isEmpty {
                SocialEmbedsSection(embeds: socialEmbeds)
                    .padding(.top, 4)
            }

            // Tags
            if !post.tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(post.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "D4AF37"))
                    }
                }
            }

            // Stats
            HStack(spacing: 20) {
                StatView(icon: post.userLiked ? "heart.fill" : "heart", count: post.likeCount, color: post.userLiked ? .red : .gray)
                StatView(icon: "bubble.right", count: post.commentCount, color: .gray)
                Spacer()
                StatView(icon: "eye", count: post.viewCount, color: .gray.opacity(0.6))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(hex: "1A1A1A").opacity(0.8))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else { return "Just now" }
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        if diff < 7 * 86400 { return "\(diff / 86400)d ago" }
        let df = DateFormatter(); df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}

struct StatView: View {
    let icon: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text("\(count)")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(color)
    }
}

