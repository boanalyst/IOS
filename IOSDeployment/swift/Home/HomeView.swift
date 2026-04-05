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
    @Published var isLoading = false
    @Published var error: String? = nil

    private let api = APIClient.shared

    func loadHomeData() async {
        isLoading = true
        error = nil
        // Fire all three requests in parallel, but handle each independently
        // so a failure in polls/flock doesn't discard the movie results.
        async let moviesTask = api.request(.getNowPlaying, responseType: MovieResponse.self)
        async let pollsTask  = api.request(.getPolls, responseType: ApiResult<[Poll]>.self)
        async let flockTask  = api.request(.getFlockPosts(offset: 0, limit: 5), responseType: FlockFeedResponse.self)

        if let movies = try? await moviesTask { nowPlayingMovies = movies.movies }
        if let polls  = try? await pollsTask  { self.polls = polls.data ?? [] }
        if let flock  = try? await flockTask  { recentFlockPosts = flock.posts }

        if nowPlayingMovies.isEmpty {
            error = "Unable to load content. Please check your connection."
        }
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
                    VStack(alignment: .leading, spacing: 24) {

                        // ── Hero Header ────────────────────────────────────
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Good \(greetingTime)")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.textSecondary)
                                Text(authViewModel.currentUser?.name ?? "Film Buff")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            Spacer()
                            // Pro Badge
                            if authViewModel.currentUser?.isPro == true {
                                Text("PRO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.goldGradient)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // ── Live Ticker ────────────────────────────────────
                        LiveTickerBanner()

                        // ── Now Playing ───────────────────────────────────
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

                        // ── Community Polls ───────────────────────────────
                        if !viewModel.polls.isEmpty {
                            SectionHeader(title: "Community Polls", icon: "chart.bar.fill")

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

                        // ── Recent from Flock ──────────────────────────────
                        if !viewModel.recentFlockPosts.isEmpty {
                            SectionHeader(title: "From The Flock", icon: "bubble.left.and.bubble.right")

                            VStack(spacing: 12) {
                                ForEach(viewModel.recentFlockPosts.prefix(3)) { post in
                                    FlockPostCard(post: post, isAdmin: false) {}
                                        .padding(.horizontal, 20)
                                }
                            }
                        }

                        Spacer(minLength: 32)
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
        .navigationTitle("BoAnalyst")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("BOANALYST")
                    .font(.custom("Cinzel-Regular", size: 16))
                    .foregroundStyle(AppTheme.goldGradient)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                GoldIconButton(icon: "bell") {}
            }
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

struct MovieCard: View {
    let movie: Movie
    private let posterBase = "https://image.tmdb.org/t/p/w342"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: posterBase + (movie.posterPath ?? ""))) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(AppTheme.surfaceVariant)
            }
            .frame(width: 130, height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(movie.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)
                .frame(width: 130, alignment: .leading)
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

            Text("Box Office data updating in real-time")
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
