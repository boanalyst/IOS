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
                            Text("SEARCH RESULTS")
                                .font(.system(size: 14, weight: .heavy))
                                .kerning(2)
                                .foregroundColor(AppTheme.goldPrimary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                            SearchTimelineListView(
                                items: viewModel.data, 
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
    private let ticketCyanDark = Color(hex: "0083B0")
    private let movieGold = Color(hex: "DFBA7D") // Rich goldish shade, not just yellow
    private let subtitleColor = Color(hex: "AAAAAA")
    private let cardBg = Color(hex: "0D0D0D")
    private let borderColor = Color(hex: "2A2A2A")
    private let accentGold = Color(hex: "D4AF37")

    private var maxTickets: Int {
        let max = items.map { $0.tickets_sold }.max() ?? 1
        return max > 0 ? max : 1
    }

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let rank = index + 1
                let fraction = CGFloat(item.tickets_sold) / CGFloat(maxTickets)
                
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        // Rank
                        Text("\(rank)")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(accentGold)
                            .frame(width: 28, alignment: .leading)
                        
                        // Movie Info
                        VStack(alignment: .leading, spacing: 4) {
                            if showMovieColumn {
                                Text((item.movie_name ?? "—").uppercased())
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(movieGold)
                                    .lineLimit(2)
                            }
                            
                            let rawDate = String(item.date?.prefix(10) ?? "")
                            let formattedDate: String = {
                                let dfIn = DateFormatter()
                                dfIn.dateFormat = "yyyy-MM-dd"
                                if let d = dfIn.date(from: rawDate) {
                                    let dfOut = DateFormatter()
                                    dfOut.dateFormat = "dd MMM yyyy"
                                    return dfOut.string(from: d)
                                }
                                return rawDate
                            }()
                            
                            let timeStr = item.time ?? ""
                            let subtitle = (formattedDate.isEmpty || timeStr.isEmpty) ? formattedDate + timeStr : "\(formattedDate) • \(timeStr)"
                            
                            Text(subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(subtitleColor)
                        }
                        
                        Spacer()
                        
                        // Tickets
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatNumber(item.tickets_sold))
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(ticketCyan)
                            Text("TICKETS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(subtitleColor)
                                .kerning(1)
                        }
                    }
                    
                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "222222"))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(colors: [ticketCyanDark, ticketCyan], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(0, geo.size.width * fraction), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(16)
                .background(cardBg)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1))
                .padding(.horizontal, 16)
            }

            // Subscribe CTA
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
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - SearchTimelineListView
struct SearchTimelineListView: View {
    let items: [BmsSalesItem]
    var isLimited: Bool = false
    var hasMore: Bool = false

    private let timelineColors = [
        Color(hex: "D4AF37"), // Muted Gold
        Color(hex: "00B8D4"), // Muted Cyan
        Color(hex: "E67E22"), // Muted Orange
        Color(hex: "9B59B6"), // Muted Purple
        Color(hex: "2ECC71"), // Muted Green
    ]

    private let subtitleColor = Color(hex: "AAAAAA")
    private let cardBg = Color(hex: "0D0D0D")

    private var maxTickets: Int {
        let max = items.map { $0.tickets_sold }.max() ?? 1
        return max > 0 ? max : 1
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let neonColor = timelineColors[index % timelineColors.count]
                let fraction = CGFloat(item.tickets_sold) / CGFloat(maxTickets)
                let isLast = index == items.count - 1
                
                let rawDate = String(item.date?.prefix(10) ?? "")
                let formattedDate: String = {
                    let dfIn = DateFormatter()
                    dfIn.dateFormat = "yyyy-MM-dd"
                    if let d = dfIn.date(from: rawDate) {
                        let dfOut = DateFormatter()
                        dfOut.dateFormat = "dd MMM yyyy"
                        return dfOut.string(from: d)
                    }
                    return rawDate
                }()
                let timeStr = item.time ?? "—"

                HStack(alignment: .top, spacing: 12) {
                    // Left Timeline
                    VStack(spacing: 0) {
                        // Clock Icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: "0A0A0A"))
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(neonColor, lineWidth: 2))
                            
                            Image(systemName: "clock")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(neonColor)
                        }
                        
                        // Dashed line
                        if !isLast {
                            Line()
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                                .foregroundColor(neonColor.opacity(0.5))
                                .frame(width: 2)
                        } else {
                            Spacer()
                        }
                    }
                    .frame(width: 36)

                    // Right Card
                    VStack(spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(timeStr)
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(.white)
                                Text(formattedDate)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(subtitleColor)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatNumber(item.tickets_sold))
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(neonColor)
                                Text("TICKETS")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(subtitleColor)
                                    .kerning(1)
                            }
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "222222"))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: [neonColor.opacity(0.6), neonColor], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(0, geo.size.width * fraction), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(16)
                    .background(cardBg)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(neonColor, lineWidth: 1.5))
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
            
            // Subscribe CTA
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
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
