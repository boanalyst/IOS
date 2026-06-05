// BoxOfficeView.swift
// Displays a classy, simple, yet futuristic Box Office Leaderboard with Language Filtering and Search.

import SwiftUI

// MARK: - String Formatting Utility

// Helper utility to safely strip any pre-appended "Cr" from the database to prevent duplicate "Cr Cr"
func cleanGross(_ value: String?) -> String {
    guard let value = value else { return "—" }
    return value.replacingOccurrences(of: "cr", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - BoxOfficeViewModel

@MainActor
final class BoxOfficeViewModel: ObservableObject {
    @Published var boxOfficeEntries: [BoxOfficeEntry] = []
    @Published var selectedLanguage: String = "all"
    @Published var isLoading = false
    @Published var error: String? = nil

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        error = nil

        do {
            let r = try await api.request(
                .getBoxOfficeEntries(language: selectedLanguage),
                responseType: BoxOfficeResponse.self
            )
            // Backend returns movies already sorted and ranked by backend!
            self.boxOfficeEntries = r.data
            if self.boxOfficeEntries.isEmpty {
                self.error = "No box office collections found."
            }
        } catch {
            self.error = "Could not load box office data. Please check your connection."
            print("Error loading box office entries: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - BoxOfficeView

struct BoxOfficeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = BoxOfficeViewModel()
    @State private var isSearching = false
    @State private var searchQuery = ""
    @State private var adInterval: Int = 10
    @StateObject private var adManager = InterstitialAdManager()
    @State private var hasShownAd = false

    let languages = [
        ("all", "Global (All)"),
        ("hindi", "Hindi"),
        ("tamil", "Tamil"),
        ("telugu", "Telugu"),
        ("kannada", "Kannada"),
        ("malayalam", "Malayalam")
    ]

    var filteredEntries: [BoxOfficeEntry] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.boxOfficeEntries
        } else {
            return viewModel.boxOfficeEntries.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Search Field in View body (Classy and simple!) ──
                if isSearching {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.goldPrimary)
                        TextField("Search movie...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppTheme.textPrimary.opacity(0.6))
                            }
                        }
                        
                        Button {
                            withAnimation {
                                searchQuery = ""
                                isSearching = false
                            }
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.goldPrimary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.surface)
                    .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.surfaceVariant), alignment: .bottom)
                }

                // ── Horizontal Language Picker ─────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(languages, id: \.0) { item in
                            let isSelected = viewModel.selectedLanguage == item.0
                            Button {
                                viewModel.selectedLanguage = item.0
                                searchQuery = ""
                                isSearching = false
                                Task { await viewModel.load() }
                            } label: {
                                Text(item.1)
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        isSelected ? AnyView(AppTheme.goldGradient) : AnyView(AppTheme.surfaceVariant)
                                    )
                                    .foregroundColor(isSelected ? .black : AppTheme.textPrimary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.clear : AppTheme.goldPrimary.opacity(0.12), lineWidth: 1)
                                    )
                             }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(AppTheme.surface)
                .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.surfaceVariant), alignment: .bottom)

                // ── Main Content Area ─────────────────────────────────────
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.goldPrimary)
                        .scaleEffect(1.2)
                    Spacer()
                } else if let error = viewModel.error {
                    Spacer()
                    emptyState(message: error, icon: "exclamationmark.triangle.fill")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            
                            // ── Top 3 Podium Showcase (Only when not searching) ────
                            if filteredEntries.count >= 3 && searchQuery.isEmpty {
                                podiumShowcase
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)
                            } else if !filteredEntries.isEmpty {
                                Spacer().frame(height: 8)
                            }

                            // ── Detailed Table Section ─────────────────────────────
                            if !filteredEntries.isEmpty {
                                // Section Header
                                HStack {
                                    Text(filteredEntries.count >= 3 && searchQuery.isEmpty ? "ALL RANKINGS" : "LEADERBOARD")
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(AppTheme.goldPrimary)
                                    Spacer()
                                    Text("WW GROSS")
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(AppTheme.textPrimary.opacity(0.6))
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)

                                ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                                    if index == 0 && !(authViewModel.currentUser?.isDistributor == true) && !(authViewModel.currentUser?.isAdmin == true) {
                                        CustomNativeAdView(module: "boxoffice")
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                    }

                                    BoxOfficeListRow(entry: entry)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(entry.rankNum == 1 ? AppTheme.goldPrimary.opacity(0.04) : AppTheme.card)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(entry.rankNum == 1 ? AppTheme.goldPrimary.opacity(0.3) : AppTheme.goldPrimary.opacity(0.08), lineWidth: 1)
                                        )
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4)

                                    if (index + 1) % 10 == 0 && !(authViewModel.currentUser?.isDistributor == true) && !(authViewModel.currentUser?.isAdmin == true) {
                                        CustomNativeAdView(module: "boxoffice")
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                    }
                                }
                            } else {
                                emptyState(message: "No matching movies found.", icon: "film.stack")
                            }

                            Spacer(minLength: 40)
                        }
                    }
                    .refreshable { await viewModel.load() }
                }

                // Anchored AdMob Banner at the bottom (persistent across scroll, matches Android exactly)
                if !viewModel.isLoading && viewModel.error == nil && !viewModel.boxOfficeEntries.isEmpty && !(authViewModel.currentUser?.isDistributor == true) && !(authViewModel.currentUser?.isAdmin == true) {
                    SwiftUIBannerAd(adUnitId: "ca-app-pub-5734863079459748/8749854605")
                        .frame(height: 50)
                        .padding(.vertical, 4)
                        .background(AppTheme.surface)
                }
            }
        }
        .task {
            await viewModel.load()
            do {
                let config = try await APIClient.shared.request(.getAdConfig, responseType: AdConfigResponse.self)
                self.adInterval = config.adInterval
                
                // Show ad when entering box office
                if !hasShownAd && !(authViewModel.currentUser?.isDistributor == true) && !(authViewModel.currentUser?.isAdmin == true) {
                    hasShownAd = true
                    InterstitialAdController.showAd(manager: adManager) { }
                }
            } catch {
                print("⚠️ [BoxOfficeView] Failed to fetch dynamic ad-config: \(error.localizedDescription)")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !isSearching {
                    Text("BOX OFFICE LEADERBOARD")
                        .font(.custom("Cinzel-Regular", size: 14))
                        .foregroundStyle(AppTheme.goldGradient)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isSearching {
                    HStack(spacing: 8) {
                        Button {
                            withAnimation {
                                isSearching = true
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppTheme.textPrimary)
                        }

                        Button {
                            Task { await viewModel.load() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    // ── Top 3 Podium Visual Component ──
    private var podiumShowcase: some View {
        HStack(alignment: .bottom, spacing: 10) {
            let entries = viewModel.boxOfficeEntries
            
            // #2 Silver (Placed on Left)
            if entries.count > 1 {
                PodiumCol(entry: entries[1], rank: 2, height: 110, color: Color(hex: "A6A6A6"), iconName: "2.circle.fill")
            }
            
            // #1 Gold (Placed in Center, Tallest)
            if entries.count > 0 {
                PodiumCol(entry: entries[0], rank: 1, height: 140, color: Color(hex: "FFD700"), iconName: "crown.fill")
            }
            
            // #3 Bronze (Placed on Right)
            if entries.count > 2 {
                PodiumCol(entry: entries[2], rank: 3, height: 95, color: Color(hex: "CD7F32"), iconName: "3.circle.fill")
            }
        }
    }

    private func emptyState(message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.goldGradient)
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text("Try choosing a different language or refresh.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Podium Column Component

struct PodiumCol: View {
    let entry: BoxOfficeEntry
    let rank: Int
    let height: CGFloat
    let color: Color
    let iconName: String

    var body: some View {
        VStack(spacing: 8) {
            // Crown/Number Icon
            Image(systemName: iconName)
                .font(.system(size: rank == 1 ? 26 : 20, weight: .bold))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 4)

            VStack(spacing: 2) {
                // Set lineLimit = 2 to ensure movie names display fully and beautifully without truncation!
                Text(entry.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text("₹\(cleanGross(entry.worldwideGross)) Cr")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(rank == 1 ? AppTheme.goldPrimary : color)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)

            // Podium Pillar
            VStack {
                Text("#\(rank)")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.25), color.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1.5)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Box Office List Row

struct BoxOfficeListRow: View {
    let entry: BoxOfficeEntry

    private var rankColor: Color {
        switch entry.rankNum {
        case 1: return Color(hex: "FFD700")
        case 2: return Color(hex: "A6A6A6")
        case 3: return Color(hex: "CD7F32")
        default: return AppTheme.textMuted
        }
    }

    private var highlightColor: Color {
        return Color(hex: "4285F4") // Elegant Google Blue for both Light and Dark backdrops
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Rank Number Bubble
            ZStack {
                if entry.rankNum <= 3 {
                    Circle()
                        .fill(rankColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(rankColor.opacity(0.4), lineWidth: 1))
                }
                Text("\(entry.rankNum)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(entry.rankNum <= 3 ? rankColor : AppTheme.textPrimary)
            }
            .frame(width: 28)

            // Film Details
            VStack(alignment: .leading, spacing: 4) {
                // Join Title and Year using a single Text flow with the '+' operator to prevent any alignment breaks!
                (
                    Text(entry.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(entry.rankNum == 1 ? AppTheme.goldPrimary : AppTheme.textPrimary)
                    +
                    Text(entry.releaseYear != nil ? " (\(String(entry.releaseYear!)))" : "")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary.opacity(0.6))
                )
                .lineLimit(2) // Allows 2 lines wrapping for movie titles
                
                Spacer().frame(height: 1)

                // Aligned stacked layout with fixed-width headers to prevent awkward wrapping glitches!
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("India:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(highlightColor)
                            .frame(width: 62, alignment: .leading)
                        Text("₹\(cleanGross(entry.indiaGross)) Cr")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary.opacity(0.85))
                    }
                    HStack(spacing: 4) {
                        Text("Overseas:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(highlightColor)
                            .frame(width: 62, alignment: .leading)
                        Text("₹\(cleanGross(entry.overseasGross)) Cr")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary.opacity(0.85))
                    }
                }
            }
            
            Spacer()

            // Worldwide Gross
            Text("₹\(cleanGross(entry.worldwideGross)) Cr")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(entry.rankNum == 1 ? AppTheme.goldPrimary : AppTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
