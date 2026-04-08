// HomeView.swift
// iOS port of Android's HomeScreen.kt — the main dashboard tab

import SwiftUI

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var nowPlayingMovies: [Movie] = []
    @Published var upcomingMovies: [Movie] = []
    @Published var polls: [Poll] = []
    @Published var recentFlockPosts: [FlockPost] = []
    @Published var trendingTopics: [TrendingTrend] = []
    @Published var exclusiveContent: ExclusiveContent? = nil
    @Published var isLoading = false
    @Published var error: String? = nil

    private let api = APIClient.shared

    func loadHomeData() async {
        isLoading = true
        error = nil
        // Fire all requests in parallel; handle each independently
        // so a failure in polls/flock doesn't discard the movie results.
        async let moviesTask    = api.request(.getNowPlaying, responseType: MovieResponse.self)
        async let upcomingTask  = api.request(.getUpcoming, responseType: MovieResponse.self)
        async let pollsTask     = api.request(.getPolls, responseType: ApiResult<[Poll]>.self)
        async let flockTask     = api.request(.getFlockPosts(offset: 0, limit: 5), responseType: FlockFeedResponse.self)
        async let trendingTask  = api.request(.getTrendingTopics, responseType: TrendingResponse.self)
        async let exclusiveTask = api.request(.getExclusiveContent, responseType: ExclusiveContentResponse.self)

        if let movies   = try? await moviesTask   { nowPlayingMovies = movies.movies }
        if let upcoming = try? await upcomingTask { upcomingMovies = upcoming.movies }
        if let polls    = try? await pollsTask    { self.polls = polls.data ?? [] }
        if let flock    = try? await flockTask    { recentFlockPosts = flock.posts }
        if let trending = try? await trendingTask { trendingTopics = trending.trends }
        if let excl     = try? await exclusiveTask{ exclusiveContent = excl.content }

        isLoading = false
    }

    func votePoll(pollId: String, optionId: Int) async {
        do {
            let endpoint = try APIEndpoint.votePoll(id: pollId, optionId: optionId)
            let result   = try await api.request(endpoint, responseType: ApiResult<Poll>.self)
            if let updated = result.data,
               let idx = polls.firstIndex(where: { $0.id == pollId }) {
                polls[idx] = updated
            }
        } catch {
            self.error = "Could not record vote. Please try again."
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    var onSubscribeRequired: () -> Void = {}
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.nowPlayingMovies.isEmpty {
                LoadingView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Brand Header (matches Android NavBar + Hero style) ───────────
                        HomeHeroBanner(
                            userName: authViewModel.currentUser?.name,
                            isPro: authViewModel.currentUser?.isPro ?? false
                        )

                        // ── Live Ticker ──────────────────────────────
                        LiveTickerBanner()
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 24) {

                            // ── Trending Now ────────────────────────────────
                            if !viewModel.trendingTopics.isEmpty {
                                SectionHeader(title: "Trending Now", icon: "flame.fill")
                                TrendingTopicsRibbon(topics: viewModel.trendingTopics)
                            }
                            
                            // ── Exclusive Content ───────────────────────────
                            if let exclusive = viewModel.exclusiveContent {
                                ExclusiveContentCard(
                                    exclusive: exclusive,
                                    onUnlock: {
                                        if let url = URL(string: "https://boanalyst.com/exclusive.html") {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                )
                                .padding(.horizontal, 20)
                            }
                            
                            // ── Top Topics in Trending ──────────────────────
                            if !viewModel.recentFlockPosts.isEmpty {
                                SectionHeader(title: "Top topics in trending sections", icon: "bubble.left.and.bubble.right")

                                VStack(spacing: 12) {
                                    ForEach(viewModel.recentFlockPosts.prefix(3)) { post in
                                        FlockPostCard(post: post, isAdmin: false)
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }

                            // ── Now Playing ────────────────────────────
                            if !viewModel.nowPlayingMovies.isEmpty {
                                SectionHeader(title: "Now Playing", icon: "film.fill")

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(viewModel.nowPlayingMovies) { movie in
                                            MovieCard(movie: movie)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            // ── Upcoming Movies ─────────────────────────
                            if !viewModel.upcomingMovies.isEmpty {
                                SectionHeader(title: "Upcoming", icon: "calendar")

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(viewModel.upcomingMovies) { movie in
                                            MovieCard(movie: movie)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            // ── Community Polls ────────────────────────
                            if !viewModel.polls.isEmpty {
                                SectionHeader(title: "Live Polls", icon: "chart.bar.fill")

                                VStack(spacing: 12) {
                                    ForEach(viewModel.polls.prefix(2)) { poll in
                                        PollCard(
                                            poll: poll,
                                            isUserPro: authViewModel.currentUser?.isPro ?? false,
                                            onSubscribeRequired: onSubscribeRequired
                                        ) { optionId in
                                            Task {
                                                await viewModel.votePoll(pollId: poll.id, optionId: optionId)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }

                            // Error state
                            if let error = viewModel.error {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(AppTheme.warning)
                                    Text(error)
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .padding(16)
                                .padding(.horizontal, 20)
                            }

                            Spacer(minLength: 32)
                        }
                        .padding(.top, 16)
                    }
                }
                .refreshable {
                    await viewModel.loadHomeData()
                }
            }
        }
        .task {
            await viewModel.loadHomeData()
        }
        .navigationBarHidden(true)
    }

    private var greetingTime: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Morning"
        case 12..<17: return "Afternoon"
        default: return "Evening"
        }
    }
}

// MARK: - Reusable Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.goldGradient)
                .font(.system(size: 14))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Movie Card
// NOTE: posterPath from server is already a full https:// URL. Use as-is.

struct MovieCard: View {
    let movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // posterPath is usually a TMDB relative path or a full URL.
            // Ensure it has a valid prefix if it's relative.
            if let path = movie.posterPath, !path.isEmpty {
                let urlStr = path.hasPrefix("http") ? path : "https://image.tmdb.org/t/p/w500\(path)"
                if let posterURL = URL(string: urlStr) {
                    AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .empty:
                        // Show a shimmer/spinner while loading (not a placeholder)
                        ZStack {
                            Rectangle().fill(AppTheme.surfaceVariant)
                            ProgressView()
                                .tint(AppTheme.goldPrimary)
                        }
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        moviePlaceholder
                    @unknown default:
                        moviePlaceholder
                    }
                }
                .frame(width: 140, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                moviePlaceholder
                    .frame(width: 140, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)
                    .frame(width: 130, alignment: .leading)
                if let date = movie.releaseDate {
                    Text(date)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 130, alignment: .leading)
                }
            }
        }
    }

    private var moviePlaceholder: some View {
        ZStack {
            Rectangle().fill(AppTheme.surfaceVariant)
            VStack(spacing: 6) {
                Image(systemName: "film")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.goldGradient)
                Text("No Image")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
    }
}

// MARK: - Live Ticker Banner

struct LiveTickerBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppTheme.success)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle().stroke(AppTheme.success.opacity(0.4), lineWidth: 4)
                )

            Text("LIVE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.success)

            Text("Analysis data updating in real-time")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.success.opacity(0.08))
        .overlay(
            Rectangle()
                .fill(AppTheme.success)
                .frame(width: 3)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Poll Card

struct PollCard: View {
    let poll: Poll
    var isUserPro: Bool = false
    var onSubscribeRequired: () -> Void = {}
    let onVote: (Int) -> Void  // Int matches PollOption.id type

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(poll.question)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            ForEach(poll.options) { option in
                let percentage = poll.totalVotes > 0
                    ? Double(option.votes) / Double(poll.totalVotes)
                    : 0
                let isSelected = poll.userVotedOptionId == option.id

                Button {
                    onVote(option.id)  // option.id is Int — matches VoteRequest
                } label: {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.surfaceVariant)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.goldPrimary.opacity(0.15))
                                .frame(width: geo.size.width * percentage)
                        }

                        HStack {
                            Text(option.text)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("\(Int(percentage * 100))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.goldGradient)
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? AppTheme.goldPrimary.opacity(0.5) : Color.white.opacity(0.05),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Text("\(poll.totalVotes) votes")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(16)
        .cardStyle()
    }
}




// MARK: - Exclusive Content Card
struct ExclusiveContentCard: View {
    let exclusive: ExclusiveContent
    var onUnlock: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(AppTheme.goldPrimary)
                Text("EXCLUSIVE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(AppTheme.goldPrimary)
            }

            // Simple HTML tag removal for description
            let cleanDesc = exclusive.description
                .replacingOccurrences(of: "<div>", with: "")
                .replacingOccurrences(of: "</div>", with: "")
                .replacingOccurrences(of: "<b>", with: "")
                .replacingOccurrences(of: "</b>", with: "")
                .replacingOccurrences(of: "&nbsp;", with: " ")

            // Simple HTML tag removal for title
            let cleanTitle = exclusive.title
                .replacingOccurrences(of: "<div>", with: "")
                .replacingOccurrences(of: "</div>", with: "")
                .replacingOccurrences(of: "<b>", with: "")
                .replacingOccurrences(of: "</b>", with: "")
                .replacingOccurrences(of: "&nbsp;", with: " ")

            Text(cleanTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Text(cleanDesc)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)

            if let mediaUrlsString = exclusive.mediaUrl,
               let data = mediaUrlsString.data(using: .utf8),
               let urls = try? JSONDecoder().decode([String].self, from: data),
               let firstUrlStr = urls.first,
               let firstUrl = URL(string: "https://boanalyst.com\(firstUrlStr)") {
                AsyncImage(url: firstUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                             .frame(height: 180)
                             .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        EmptyView()
                    }
                }
            }

            Button(action: onUnlock) {
                let currency = exclusive.currency ?? "₹"
                let price = Int(exclusive.price)
                Text("Unlock for \(currency) \(price)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.goldGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Trending Topics Ribbon
struct TrendingTopicsRibbon: View {
    let topics: [TrendingTrend]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(topics) { topic in
                    HStack {
                        Text("#\(topic.topic)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        if topic.count > 0 {
                            Text("\(topic.count)")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.surfaceVariant)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Home Hero Banner (matches Android BoAnalyst branding exactly)

struct HomeHeroBanner: View {
    let userName: String?
    let isPro: Bool
    
    // Instead of navigation link here, we just match Android's UI 
    // and rely on the profile tab for access, or we can use a callback.
    // For now we just display the header.
    
    var body: some View {
        HStack(alignment: .center) {
            Text("BoAnalyst")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(AppTheme.goldPrimary)
                .tracking(0.5)
            
            Spacer()
            
            if isPro {
                Text("PRO")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.goldGradient)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppTheme.background)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.goldPrimary))
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject(AuthViewModel())
}

