import SwiftUI

@MainActor
final class BmsSalesViewModel: ObservableObject {
    @Published var data: [BmsSalesItem] = []
    @Published var topList: [BmsSalesItem]? = nil
    @Published var dailyList: [BmsSalesItem]? = nil
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var isIdle = true
    @Published var hasMore = false
    @Published var isLimited = false

    private let api = APIClient.shared

    init() {
        Task {
            await fetchTopMovies()
        }
    }

    func fetchTopMovies() async {
        do {
            let r = try await api.request(.getTopBmsSales, responseType: BmsSalesResponse.self)
            self.topList = r.data ?? []
        } catch {
            self.topList = []
            print("Failed to fetch top bms sales: \(error)")
        }
        
        do {
            let r = try await api.request(.getDailyBmsSales, responseType: BmsSalesResponse.self)
            self.dailyList = r.data ?? []
        } catch {
            self.dailyList = []
            print("Failed to fetch daily bms sales: \(error)")
        }
    }

    func searchMovie(movieName: String) async {
        if movieName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        
        isLoading = true
        error = nil
        isIdle = false
        data = []

        do {
            let r = try await api.request(
                .searchBmsSales(movie: movieName),
                responseType: BmsSalesResponse.self
            )
            if let items = r.data {
                if items.isEmpty {
                    self.error = "Movie not found."
                } else {
                    self.data = items
                    self.hasMore = r.hasMore
                    self.isLimited = r.isLimited
                }
            } else {
                self.error = r.message ?? "Movie not found."
            }
        } catch {
            self.error = "Failed to fetch data."
            print("Error loading bms sales: \(error)")
        }
        
        isLoading = false
    }
}

struct BmsSalesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BmsSalesViewModel()
    @State private var searchQuery = ""
    @State private var selectedTabIndex = 0
    @EnvironmentObject private var rewardedAdManager: RewardedAdManager

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.goldPrimary)
                    TextField("Enter movie name...", text: $searchQuery)
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
                        if rewardedAdManager.isAdLoaded {
                            RewardedAdController.showAd(manager: rewardedAdManager) {
                                rewardedAdManager.loadAd()
                                Task {
                                    await viewModel.searchMovie(movieName: searchQuery)
                                }
                            }
                        } else {
                            rewardedAdManager.loadAd()
                            Task {
                                await viewModel.searchMovie(movieName: searchQuery)
                            }
                        }
                    } label: {
                        Text("Search")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.goldPrimary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.surface)
                .overlay(Rectangle().frame(height: 1).foregroundColor(AppTheme.surfaceVariant), alignment: .bottom)

                // State Content
                if viewModel.isIdle {
                    if viewModel.topList == nil && viewModel.dailyList == nil {
                        Spacer()
                        ProgressView()
                            .tint(AppTheme.goldPrimary)
                            .scaleEffect(1.2)
                        Spacer()
                    } else {
                        VStack(spacing: 0) {
                            Picker("Select Data", selection: $selectedTabIndex) {
                                Text("Latest Data").tag(0)
                                Text("Top 12").tag(1)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    if selectedTabIndex == 0 {
                                        if let daily = viewModel.dailyList, !daily.isEmpty {
                                            SalesListView(items: daily, showMovieColumn: true)
                                        } else {
                                            emptyState(message: "No daily data available.", icon: "doc.text.magnifyingglass")
                                                .padding(.top, 40)
                                        }
                                    } else {
                                        if let top = viewModel.topList, !top.isEmpty {
                                            SalesListView(items: top, showMovieColumn: true)
                                        } else {
                                            emptyState(message: "No top data available.", icon: "doc.text.magnifyingglass")
                                                .padding(.top, 40)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else if viewModel.isLoading {
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Search Results")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.goldPrimary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                            SalesListView(
                                items: viewModel.data, 
                                showMovieColumn: false, 
                                isLimited: viewModel.isLimited, 
                                hasMore: viewModel.hasMore
                            )
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Hourly BMS Sales")
                    .font(.custom("Cinzel-Regular", size: 14))
                    .foregroundStyle(AppTheme.goldGradient)
            }
        }
        .navigationBarBackButtonHidden(false)
    }

    private func emptyState(message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.goldGradient)
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

struct SalesListView: View {
    let items: [BmsSalesItem]
    let showMovieColumn: Bool
    var isLimited: Bool = false
    var hasMore: Bool = false

    private let ticketCyan = Color(hex: "00E5FF")
    private let dateColor = Color(hex: "AAAAAA")
    private let timeColor = Color(hex: "888888")
    private let headerColor = Color(hex: "555555")
    private let borderColor = Color(hex: "2A2A2A")
    private let cardBg = Color(hex: "0D0D0D")
    private let headerBg = Color(hex: "111111")

    var body: some View {
        LazyVStack(spacing: 0) {
            // ── Header Row ──
            HStack(spacing: 0) {
                if showMovieColumn {
                    Text("MOVIE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(headerColor)
                        .kerning(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .overlay(Rectangle().frame(width: 0.5).foregroundColor(borderColor), alignment: .trailing)
                }
                Text("DATE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(headerColor)
                    .kerning(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().frame(width: 0.5).foregroundColor(borderColor), alignment: .trailing)
                Text("TIME")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(headerColor)
                    .kerning(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().frame(width: 0.5).foregroundColor(borderColor), alignment: .trailing)
                Text("TICKETS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.goldPrimary)
                    .kerning(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            }
            .background(headerBg)
            .overlay(Rectangle().stroke(borderColor, lineWidth: 1))

            // ── Data Rows ──
            ForEach(items) { item in
                HStack(spacing: 0) {
                    if showMovieColumn {
                        Text(item.movie_name ?? "—")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 14)
                            .overlay(Rectangle().frame(width: 0.5).foregroundColor(borderColor), alignment: .trailing)
                    }
                    Text(String(item.date?.prefix(10) ?? ""))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(dateColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 14)
                        .overlay(Rectangle().frame(width: 0.5).foregroundColor(borderColor), alignment: .trailing)
                    Text(item.time ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(timeColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 14)
                        .overlay(Rectangle().frame(width: 0.5).foregroundColor(borderColor), alignment: .trailing)
                    Text("\(item.tickets_sold)")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(ticketCyan)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 14)
                }
                .background(cardBg)
                .overlay(Rectangle().stroke(borderColor, lineWidth: 0.5))
            }

            // ── Subscribe CTA ──
            if isLimited && hasMore {
                NavigationLink(destination: SubscriptionView()) {
                    Text("Unlock Full Data")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.goldPrimary)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
        }
        .padding(.bottom, 24)
    }
}
