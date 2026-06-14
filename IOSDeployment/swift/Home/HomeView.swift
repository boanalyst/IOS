// HomeView.swift
// iOS port of Android's HomeScreen.kt — the main dashboard tab

import SwiftUI

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var nowPlayingMovies: [Movie] = []
    @Published var upcomingMovies: [Movie] = []
    @Published var ottReleases: [Movie] = []
    @Published var polls: [Poll] = []
    @Published var recentFlockPosts: [FlockPost] = []
    @Published var trendingTopics: [TrendingTrend] = []
    @Published var exclusiveContent: ExclusiveContent? = nil
    @Published var dailyBmsSalesTeaser: [BmsSalesItem] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var showExclusiveEditor = false
    @Published var isSavingExclusive = false
    @Published var exclusiveSaveError: String? = nil

    private let api = APIClient.shared

    func loadHomeData() async {
        isLoading = true
        error = nil
        async let moviesTask    = api.request(.getNowPlaying, responseType: MovieResponse.self)
        async let upcomingTask  = api.request(.getUpcoming, responseType: MovieResponse.self)
        async let ottTask       = api.request(.getOttReleases(), responseType: MovieResponse.self)
        async let pollsTask     = api.request(.getPolls, responseType: ApiResult<[Poll]>.self)
        async let flockTask     = api.request(.getFlockPosts(offset: 0, limit: 5), responseType: FlockFeedResponse.self)
        async let trendingTask  = api.request(.getTrendingTopics, responseType: TrendingResponse.self)
        async let exclusiveTask = api.request(.getExclusiveContent, responseType: ExclusiveContentResponse.self)
        async let bmsTeaserTask = api.request(.getDailyBmsSales, responseType: BmsSalesResponse.self)

        if let movies   = try? await moviesTask   { nowPlayingMovies = sortMoviesByDateDesc(movies.movies) }
        if let upcoming = try? await upcomingTask { upcomingMovies = sortMoviesByDateDesc(upcoming.movies) }
        if let ott      = try? await ottTask      { ottReleases = sortMoviesByDateDesc(ott.movies) }
        if let polls    = try? await pollsTask    { self.polls = polls.data ?? [] }
        if let flock    = try? await flockTask    { recentFlockPosts = flock.posts }
        if let trending = try? await trendingTask { trendingTopics = trending.trends }
        if let excl     = try? await exclusiveTask{ exclusiveContent = excl.content }
        if let bmsTeaser = try? await bmsTeaserTask {
            let allItems = bmsTeaser.data ?? []
            dailyBmsSalesTeaser = Array(allItems.sorted(by: { $0.tickets_sold > $1.tickets_sold }).prefix(3))
        }

        isLoading = false
    }
    
    private func sortMoviesByDateDesc(_ movies: [Movie]) -> [Movie] {
        let formatters: [DateFormatter] = [
            "MMMM d, yyyy", "MMMM dd, yyyy", "MMM d, yyyy", "MMM dd, yyyy", "yyyy-MM-dd"
        ].map {
            let df = DateFormatter()
            df.dateFormat = $0
            df.locale = Locale(identifier: "en_US_POSIX")
            return df
        }
        
        return movies.sorted { m1, m2 in
            let raw1 = m1.releaseDate ?? ""
            let raw2 = m2.releaseDate ?? ""
            
            let d1 = formatters.compactMap { $0.date(from: raw1) }.first ?? Date.distantPast
            let d2 = formatters.compactMap { $0.date(from: raw2) }.first ?? Date.distantPast
            return d1 > d2
        }
    }

    func votePoll(pollId: String, optionId: String) async {
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

    func voteFlockPoll(postId: String, pollId: String, optionId: String) async {
        do {
            let endpoint = try APIEndpoint.votePoll(id: pollId, optionId: optionId)
            let result = try await api.request(endpoint, responseType: PollVoteResponse.self)
            if let updatedPoll = result.poll {
                recentFlockPosts = recentFlockPosts.map { p in
                    guard p.id == postId && p.poll?.id == pollId else { return p }
                    return FlockPost(from: p, poll: updatedPoll)
                }
            }
        } catch {
            self.error = "Could not record vote."
        }
    }

    /// Admin: Save exclusive content. `newImages` are UIImage picked by the user.
    func saveExclusiveContent(
        title: String,
        description: String,
        price: Double,
        existingMediaUrls: [String],
        newImages: [UIImage]
    ) async {
        isSavingExclusive = true
        exclusiveSaveError = nil
        do {
            let newMediaData: [(data: Data, filename: String, mimeType: String)] = newImages.compactMap { img in
                guard let data = img.jpegData(compressionQuality: 0.8) else { return nil }
                return (data: data, filename: "exclusive_\(UUID().uuidString).jpg", mimeType: "image/jpeg")
            }
            let endpoint = try APIEndpoint.updateExclusiveContent(
                title: title, description: description, price: price,
                existingMedia: existingMediaUrls, newMediaData: newMediaData
            )
            _ = try await api.requestRaw(endpoint)
            await loadHomeData()
            showExclusiveEditor = false
        } catch {
            exclusiveSaveError = "Save failed: \(error.localizedDescription)"
        }
        isSavingExclusive = false
    }
}

// MARK: - HomeView

struct HomeView: View {
    var onSubscribeRequired: () -> Void = {}
    var onNavigateToTechDeals: () -> Void = {}
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var adManager = InterstitialAdManager()
    @State private var selectedMovieForSynopsis: Movie? = nil
    @EnvironmentObject private var rewardedAdManager: RewardedAdManager
    @State private var navigateToBmsSales = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            NavigationLink(destination: BmsSalesView(), isActive: $navigateToBmsSales) { EmptyView() }.hidden()

            VStack(spacing: 0) {
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
                            
                        // ── Daily BMS Sales Teaser ──────────────────────────
                        if !viewModel.dailyBmsSalesTeaser.isEmpty || viewModel.isLoading {
                            DailyBmsSalesTeaserView(
                                items: viewModel.dailyBmsSalesTeaser,
                                isLoading: viewModel.isLoading,
                                onSeeAll: { navigateToBmsSales = true }
                            )
                            .padding(.top, 16)
                        }

                        VStack(alignment: .leading, spacing: 24) {

                            // ── Trending Now ────────────────────────────────
                            if !viewModel.trendingTopics.isEmpty {
                                SectionHeader(title: "Trending Now", icon: "flame.fill")
                                TrendingTopicsRibbon(topics: viewModel.trendingTopics)
                            }
                            
                            // ── Tech Deals ──────────────────────────────────
                            TechDealsHomeBanner(onClick: onNavigateToTechDeals)
                                .padding(.horizontal, 20)
                            
                            // ── Exclusive Content ───────────────────────────
                            if let exclusive = viewModel.exclusiveContent {
                                ExclusiveContentCard(
                                    exclusive: exclusive,
                                    isAdmin: authViewModel.currentUser?.isAdmin ?? false,
                                    onEdit: { viewModel.showExclusiveEditor = true },
                                    onUnlock: { 
                                        let isRewarded = exclusive.description.lowercased().contains("#boanalystexclusive") || 
                                                         exclusive.title.lowercased().contains("#boanalystexclusive")
                                        if isRewarded {
                                            RewardedAdController.showAd(manager: rewardedAdManager) {
                                                onSubscribeRequired()
                                                AdTracker.shared.logImpression(postId: exclusive.id, module: "inside_talk", adType: "rewarded")
                                            }
                                        } else {
                                            onSubscribeRequired()
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
                                        FlockPostCard(post: post, isAdmin: false, onVote: { pollId, optionId in
                                            Task {
                                                await viewModel.voteFlockPoll(postId: post.id, pollId: pollId, optionId: optionId)
                                            }
                                        })
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }

                            // ── Now Playing ────────────────────────────
                            if !viewModel.nowPlayingMovies.isEmpty {
                                SectionHeader(title: "Now Playing", icon: "film.fill")

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 14) {
                                        ForEach(viewModel.nowPlayingMovies) { movie in
                                            MovieCard(movie: movie) {
                                                handleMovieTap(movie)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            // ── Upcoming Movies ─────────────────────────
                            if !viewModel.upcomingMovies.isEmpty {
                                SectionHeader(title: "Upcoming", icon: "calendar")

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 14) {
                                        ForEach(viewModel.upcomingMovies) { movie in
                                            MovieCard(movie: movie) {
                                                handleMovieTap(movie)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            // ── OTT Releases ─────────────────────────
                            if !viewModel.ottReleases.isEmpty {
                                SectionHeader(title: "OTT Releases", icon: "play.tv.fill")

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 14) {
                                        ForEach(viewModel.ottReleases) { movie in
                                            MovieCard(movie: movie) {
                                                handleMovieTap(movie)
                                            }
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

            // Anchored AdMob Banner — separated from scrollable content (Google recommended)
            SwiftUIBannerAd(adUnitId: "ca-app-pub-5734863079459748/8749854605")
                .frame(height: 50)
                .padding(.vertical, 4)
                .background(AppTheme.surface)
            } // end VStack
        }
        .task {
            await viewModel.loadHomeData()
        }
        .onAppear {
            adManager.loadAd()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showExclusiveEditor) {
            ExclusiveContentEditSheet()
        }
        .sheet(item: $selectedMovieForSynopsis) { movie in
            MovieSynopsisSheet(movie: movie)
        }
    }

    private func handleMovieTap(_ movie: Movie) {
        InterstitialAdController.showAd(manager: adManager) {
            selectedMovieForSynopsis = movie
        }
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
            // posterPath is usually a TMDB relative path or a full URL.
            // Ensure we enforce HTTPS mapping and properly encode query spaces.
            if let posterURL = movie.resolvedPosterUrl {
                CachedAsyncImage(url: posterURL) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Rectangle().fill(AppTheme.surfaceVariant)
                                ProgressView()
                                    .tint(AppTheme.goldPrimary)
                            }
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
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
                    .lineLimit(1)
                    .frame(width: 130, alignment: .leading)
                if let date = movie.releaseDate {
                    Text(date)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 130, alignment: .leading)
                }

                // Synopsis / Overview
                if let overview = movie.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 130, alignment: .topLeading)
                }
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

// MARK: - Movie Synopsis Sheet

struct MovieSynopsisSheet: View {
    let movie: Movie
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let posterURL = movie.resolvedPosterUrl {
                        CachedAsyncImage(url: posterURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().aspectRatio(contentMode: .fit)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Text(movie.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    if let date = movie.releaseDate {
                        Text("Release: \(date)")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    
                    if let overview = movie.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.top, 8)
                    } else {
                        Text("No synopsis available.")
                            .font(.body)
                            .foregroundColor(AppTheme.textMuted)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
            .background(AppTheme.background.edgesIgnoringSafeArea(.all))
            .navigationTitle(movie.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textMuted)
                            .font(.title3)
                    }
                }
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
    let onVote: (String) -> Void  // String matches PollOption.id type

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
                    onVote(option.id)
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
    var isAdmin: Bool = false
    var onEdit: () -> Void = {}
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
                Spacer()
                if isAdmin {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.goldPrimary)
                    }
                }
            }

            // ── Title — rendered with full BIU parser (matches Flock Feed) ──
            let attrTitle = ParsedTextCache.shared.parseFlock(exclusive.title, id: exclusive.id + "-title")
            Text(attrTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            // ── Description — rendered with full BIU parser ──────────────────
            // ** bold, _italic_, __underline__, <b>, <i>, <u> all supported.
            let attrDesc = ParsedTextCache.shared.parseFlock(exclusive.description, id: exclusive.id + "-desc")
            Text(attrDesc)
                .tint(AppTheme.goldPrimary)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(nil)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let mediaUrlsString = exclusive.mediaUrl,
               let data = mediaUrlsString.data(using: .utf8),
               let urls = try? JSONDecoder().decode([String].self, from: data),
               let firstUrlStr = urls.first,
               let firstUrl = URL(string: "https://boanalyst.com\(firstUrlStr)") {
                CachedAsyncImage(url: firstUrl) { phase in
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
                Text("Unlock with Pro · ₹499/mo")
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

// MARK: - TechDealsHomeBanner
struct TechDealsHomeBanner: View {
    var onClick: () -> Void
    var body: some View {
        Button(action: onClick) {
            CustomNativeAdView(module: "all", isTechDealStyle: true)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exclusive Content Admin Edit Sheet
import PhotosUI

struct EditableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ExclusiveContentEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var price: String = ""
    @State private var existingMediaUrls: [String] = []
    @State private var newImages: [EditableImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoadingContent = false
    @State private var loadError: String? = nil

    private let api = APIClient.shared
    private var totalMediaCount: Int { existingMediaUrls.count + newImages.count }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if isLoadingContent {
                    ProgressView("Loading content...")
                        .tint(AppTheme.goldPrimary)
                        .foregroundColor(AppTheme.textMuted)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {

                            // Title
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Title").font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.textMuted)
                                TextField("Exclusive content title", text: $title, axis: .vertical)
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(12)
                                    .background(AppTheme.surfaceVariant)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            // Description
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description").font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.textMuted)
                                TextField("Description / body text", text: $description, axis: .vertical)
                                    .lineLimit(4...12)
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(12)
                                    .background(AppTheme.surfaceVariant)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            // Price
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Price (₹)").font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.textMuted)
                                TextField("Price in INR", text: $price)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(12)
                                    .background(AppTheme.surfaceVariant)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            // Media section
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Media (\(totalMediaCount)/4)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.textMuted)
                                    Spacer()
                                    if totalMediaCount < 4 {
                                        PhotosPicker(
                                            selection: $selectedItems,
                                            maxSelectionCount: 4 - existingMediaUrls.count,
                                            matching: .images
                                        ) {
                                            Label("Add photos", systemImage: "photo.badge.plus")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(AppTheme.goldPrimary)
                                        }
                                        .onChange(of: selectedItems) { items in
                                            Task {
                                                newImages = []
                                                for item in items {
                                                    if let data = try? await item.loadTransferable(type: Data.self),
                                                       let img = UIImage(data: data) {
                                                        newImages.append(EditableImage(image: img))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Existing images
                                if !existingMediaUrls.isEmpty {
                                    Text("Existing images").font(.system(size: 11)).foregroundColor(AppTheme.textMuted)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(existingMediaUrls, id: \.self) { urlStr in
                                                let fullUrl = URL(string: urlStr.hasPrefix("http") ? urlStr : "https://boanalyst.com" + urlStr)
                                                ZStack(alignment: .topTrailing) {
                                                    CachedAsyncImage(url: fullUrl) { phase in
                                                        switch phase {
                                                        case .success(let img):
                                                            img.resizable().scaledToFill()
                                                        default:
                                                            Rectangle().fill(AppTheme.surfaceVariant)
                                                        }
                                                    }
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                                    Button {
                                                        if let idx = existingMediaUrls.firstIndex(of: urlStr) {
                                                            existingMediaUrls.remove(at: idx)
                                                        }
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.white)
                                                            .background(Color.black.opacity(0.6), in: Circle())
                                                            .font(.system(size: 24))
                                                            .padding(10)
                                                            .contentShape(Rectangle())
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                        }
                                    }
                                }

                                // New images preview
                                if !newImages.isEmpty {
                                    Text("New images to upload").font(.system(size: 11)).foregroundColor(AppTheme.textMuted)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(newImages) { editableImg in
                                                ZStack(alignment: .topTrailing) {
                                                    Image(uiImage: editableImg.image)
                                                        .resizable().scaledToFill()
                                                        .frame(width: 80, height: 80)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    Button {
                                                        if let idx = newImages.firstIndex(where: { $0.id == editableImg.id }) {
                                                            newImages.remove(at: idx)
                                                        }
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.white)
                                                            .background(Color.black.opacity(0.6), in: Circle())
                                                            .font(.system(size: 18))
                                                    }
                                                    .padding(4)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if let err = viewModel.exclusiveSaveError {
                                Text(err)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 4)
                            }

                            // Save button
                            Button {
                                Task {
                                    await viewModel.saveExclusiveContent(
                                        title: title,
                                        description: description,
                                        price: Double(price) ?? 0,
                                        existingMediaUrls: existingMediaUrls,
                                        newImages: newImages.map { $0.image }
                                    )
                                }
                            } label: {
                                if viewModel.isSavingExclusive {
                                    ProgressView().tint(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                                } else {
                                    Text("Save Changes")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                            }
                            .background(AppTheme.goldGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .disabled(viewModel.isSavingExclusive || title.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(20)
                    }
                }

                if let err = loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(AppTheme.warning)
                        Text(err).font(.system(size: 14)).foregroundColor(AppTheme.textSecondary).multilineTextAlignment(.center)
                    }
                    .padding(32)
                }
            }
            .navigationTitle("Edit Exclusive Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.goldPrimary)
                }
            }
        }
        .task {
            // Load full (admin) content to pre-fill the editor
            isLoadingContent = true
            if let content = try? await api.request(.getFullExclusiveContent, responseType: ExclusiveContentResponse.self) {
                let c = content.content
                title = c?.title ?? ""
                description = c?.description ?? ""
                price = c.flatMap { String($0.price) } ?? ""
                // Parse existing mediaUrl JSON array
                if let mediaStr = c?.mediaUrl {
                    if let data = mediaStr.data(using: .utf8),
                       let urls = try? JSONDecoder().decode([String].self, from: data) {
                        existingMediaUrls = urls
                    } else {
                        existingMediaUrls = mediaStr.isEmpty ? [] : [mediaStr]
                    }
                }
            } else {
                loadError = "Could not load content. Check your connection."
            }
            isLoadingContent = false
        }
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
    @EnvironmentObject private var authViewModel: AuthViewModel
    
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

            Button {
                authViewModel.showProfileSheet = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 26))
                    .foregroundColor(AppTheme.goldPrimary)
            }
            .padding(.leading, 8)
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthViewModel())
    }
}

// MARK: - DailyBmsSalesTeaserView

struct DailyBmsSalesTeaserView: View {
    let items: [BmsSalesItem]
    let isLoading: Bool
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("📈 Highest Hourly Sales Today")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: onSeeAll) {
                    Text("See All")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.goldPrimary)
                }
            }
            .padding(.horizontal, 20)

            // Content
            if isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.card)
                                .frame(width: 160, height: 80)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            } else if items.isEmpty {
                Text("No sales data currently available.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text((item.movie_name ?? "").replacingOccurrences(of: "\"", with: ""))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(item.time ?? "")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.goldPrimary.opacity(0.8))
                                
                                HStack(alignment: .bottom, spacing: 4) {
                                    Text("\(item.tickets_sold)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppTheme.goldPrimary)
                                    Text("tix")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .padding(.bottom, 2)
                                }
                            }
                            .padding(12)
                            .frame(width: 160, alignment: .leading)
                            .background(AppTheme.card)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
