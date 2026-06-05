import SwiftUI

final class TechDealsViewModel: ObservableObject {
    @Published var categories: [TechDealCategory] = []
    @Published var deals: [TechDeal] = []
    @Published var selectedCategory: String = "all"
    
    @Published var isLoadingCategories = false
    @Published var isLoadingDeals = false
    @Published var error: String? = nil
    
    private var currentOffset = 0
    private let limit = 20
    @Published var hasMore = true
    @Published var isRefreshing = false

    @MainActor
    func fetchCategories() async {
        guard categories.isEmpty else { return }
        isLoadingCategories = true
        do {
            struct CategoriesResponse: Decodable {
                let success: Bool
                let categories: [TechDealCategory]
            }
            let response = try await APIClient.shared.request(.getTechDealCategories, responseType: CategoriesResponse.self)
            self.categories = response.categories
        } catch {
            print("Failed to fetch categories: \(error)")
        }
        isLoadingCategories = false
    }

    @MainActor
    func fetchDeals(refresh: Bool = false) async {
        if refresh {
            currentOffset = 0
            hasMore = true
            isRefreshing = true
        }
        
        guard hasMore && (!isLoadingDeals || refresh) else { return }
        
        if !refresh {
            isLoadingDeals = true
        }
        
        do {
            let response = try await APIClient.shared.request(
                .getTechDeals(offset: currentOffset, limit: limit, category: selectedCategory),
                responseType: TechDealsResponse.self
            )
            
            if response.success {
                let newDeals = response.deals ?? []
                if refresh {
                    self.deals = newDeals
                } else {
                    self.deals.append(contentsOf: newDeals)
                }
                
                self.hasMore = response.hasMore ?? (newDeals.count == limit)
                self.currentOffset += newDeals.count
            } else {
                self.error = response.error ?? "Failed to load deals"
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        self.isLoadingDeals = false
        self.isRefreshing = false
    }

    @MainActor
    func setCategory(_ categoryId: String) async {
        guard selectedCategory != categoryId else { return }
        selectedCategory = categoryId
        await fetchDeals(refresh: true)
    }

    func trackClick(dealId: String) {
        Task {
            do {
                _ = try await APIClient.shared.request(.trackTechDealClick(id: dealId), responseType: MessageResponse.self)
            } catch {
                print("Failed to track click: \(error)")
            }
        }
    }
}

struct TechDealsView: View {
    @StateObject private var viewModel = TechDealsViewModel()
    @Environment(\.openURL) var openURL
    @State private var showDisclosure = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tech Deals")
                    .font(.custom("ClashDisplay-Bold", size: 24, relativeTo: .title))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(AppTheme.surface)
            
            // Categories
            if !viewModel.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryPill(title: "All Deals", isSelected: viewModel.selectedCategory == "all") {
                            Task { await viewModel.setCategory("all") }
                        }
                        
                        ForEach(viewModel.categories.filter { $0.id.lowercased() != "all" }) { category in
                            CategoryPill(title: category.name, isSelected: viewModel.selectedCategory == category.id) {
                                Task { await viewModel.setCategory(category.id) }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(AppTheme.surface)
            }
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Disclosure Banner
                    if showDisclosure {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppTheme.textSecondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Affiliate Disclosure")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.textSecondary)
                                
                                Text("BoAnalyst is a participant in various affiliate programs (e.g. Amazon, Flipkart). We may earn a commission from qualifying purchases at no extra cost to you.")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    showDisclosure = false
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    if viewModel.deals.isEmpty && !viewModel.isLoadingDeals {
                        VStack(spacing: 16) {
                            Image(systemName: "bag.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("No deals available right now.")
                                .font(.headline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 64)
                    } else {
                        ForEach(Array(viewModel.deals.enumerated()), id: \.element.id) { index, deal in
                            if index == 0 {
                                CustomNativeAdView(module: "deals")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            
                            TechDealCard(deal: deal) {
                                viewModel.trackClick(dealId: deal.id)
                                if let url = URL(string: deal.affiliateUrl) {
                                    openURL(url)
                                }
                            }
                            .onAppear {
                                if deal.id == viewModel.deals.last?.id {
                                    Task { await viewModel.fetchDeals() }
                                }
                            }

                            if (index + 1) % 4 == 0 {
                                CustomNativeAdView(module: "deals")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    if viewModel.isLoadingDeals {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.bottom, 24)
            }
            .refreshable {
                await viewModel.fetchDeals(refresh: true)
                await viewModel.fetchCategories()
            }
        }
        .background(AppTheme.background.edgesIgnoringSafeArea(.all))
        .task {
            await viewModel.fetchCategories()
            await viewModel.fetchDeals(refresh: true)
        }
    }
}

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.goldPrimary : Color.gray.opacity(0.15))
                .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                .cornerRadius(20)
        }
    }
}

struct TechDealCard: View {
    let deal: TechDeal
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Image
                ZStack {
                    Color.white
                    
                    if let imgStr = deal.resolvedImageUrl(), let url = URL(string: imgStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(8)
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.gray)
                    }
                    
                    // Platform Badge
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(deal.platform.capitalized)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(platformColor(deal.platform))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(4)
                        }
                    }
                }
                .frame(width: 110, height: 110)
                .cornerRadius(12)
                
                // Details
                VStack(alignment: .leading, spacing: 6) {
                    Text(deal.title)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let orig = deal.originalPrice, orig > deal.dealPrice {
                                Text("₹\(Int(orig))")
                                    .font(.caption)
                                    .strikethrough()
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            Text("₹\(Int(deal.dealPrice))")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.goldPrimary)
                        }
                        
                        Spacer()
                        
                        if let pct = deal.discountPercentage, pct > 0 {
                            Text("\(pct)% OFF")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(12)
            .background(AppTheme.surface)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle()) // prevents blue highlight
    }
    
    private func platformColor(_ platform: String) -> Color {
        switch platform.lowercased() {
        case "amazon": return Color.orange
        case "flipkart": return Color.blue
        case "croma": return Color.teal
        default: return AppTheme.goldPrimary
        }
    }
}
