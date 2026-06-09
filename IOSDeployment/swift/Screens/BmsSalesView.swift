import SwiftUI

@MainActor
final class BmsSalesViewModel: ObservableObject {
    @Published var data: [BmsSalesItem] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var isIdle = true
    @Published var hasMore = false
    @Published var isLimited = false

    private let api = APIClient.shared

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
                        Task {
                            await viewModel.searchMovie(movieName: searchQuery)
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
                    Spacer()
                    emptyState(message: "Search for a movie to see hourly sales data.", icon: "magnifyingglass")
                    Spacer()
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
                        LazyVStack(spacing: 12) {
                            HStack {
                                Text("Date")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppTheme.goldPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Time")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppTheme.goldPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Tickets")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppTheme.goldPrimary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(AppTheme.surface)
                            
                            ForEach(viewModel.data) { item in
                                HStack {
                                    Text(String(item.date.prefix(10)))
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(item.time)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.textPrimary.opacity(0.8))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(item.tickets_sold)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppTheme.card)
                                )
                                .padding(.horizontal, 16)
                            }
                            
                            if viewModel.isLimited && viewModel.hasMore {
                                NavigationLink(destination: SubscriptionView()) {
                                    Text("Subscribe to see full content")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(AppTheme.goldGradient)
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                            }
                        }
                        .padding(.vertical, 16)
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
