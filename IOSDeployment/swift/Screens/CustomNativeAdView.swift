import SwiftUI

struct CustomAdPayload: Decodable {
    let success: Bool
    let ad: CustomAdData?
    let message: String?
}

struct CustomAdData: Decodable {
    let id: Int
    let title: String
    let description: String?
    let imageUrl: String
    let callToAction: String
    let affiliateLink: String
    let moduleTarget: String
}

@MainActor
class CustomAdViewModel: ObservableObject {
    @Published var adData: CustomAdData? = nil
    @Published var isLoading = true
    @Published var hasError = false
    
    let targetModule: String
    
    init(targetModule: String = "all") {
        self.targetModule = targetModule
        Task { await loadAd() }
    }
    
    func loadAd() async {
        self.isLoading = true
        do {
            guard let url = URL(string: "\(APIConfig.baseURL)/api/ads/custom/native?module=\(targetModule)") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                let payload = try JSONDecoder().decode(CustomAdPayload.self, from: data)
                if payload.success, let ad = payload.ad {
                    self.adData = ad
                } else {
                    self.hasError = true
                }
            } else {
                self.hasError = true
            }
        } catch {
            print("Error fetching Custom Ad: \(error)")
            self.hasError = true
        }
        self.isLoading = false
    }
    
    func trackClick() {
        guard let adId = adData?.id else { return }
        Task {
            do {
                guard let url = URL(string: "\(APIConfig.baseURL)/api/ads/custom/click") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = ["adId": adId]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let _ = try await URLSession.shared.data(for: request)
            } catch {
                print("Error tracking ad click: \(error)")
            }
        }
    }
}

struct CustomNativeAdView: View {
    let module: String
    @StateObject private var viewModel: CustomAdViewModel
    
    init(module: String = "all") {
        self.module = module
        _viewModel = StateObject(wrappedValue: CustomAdViewModel(targetModule: module))
    }
    
    var body: some View {
        if viewModel.isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .padding()
                Spacer()
            }
        } else if let ad = viewModel.adData {
            Button(action: {
                viewModel.trackClick()
                if let url = URL(string: ad.affiliateLink) {
                    UIApplication.shared.open(url)
                }
            }) {
                VStack(alignment: .leading, spacing: 0) {
                    // Ad Image with Banner style
                    if let url = URL(string: ad.imageUrl.hasPrefix("http") ? ad.imageUrl : "\(APIConfig.baseURL)\(ad.imageUrl)") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                     .aspectRatio(contentMode: .fill)
                                     .frame(height: 180)
                                     .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 180)
                                    .overlay(Image(systemName: "photo").foregroundColor(.gray))
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 180)
                                    .overlay(ProgressView())
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    // Ad Content
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("SPONSORED")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(AppTheme.goldPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.goldPrimary.opacity(0.15))
                                .cornerRadius(4)
                            
                            Spacer()
                        }
                        
                        Text(ad.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        if let desc = ad.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        
                        HStack {
                            Spacer()
                            Text(ad.callToAction)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppTheme.goldGradient)
                                .cornerRadius(20)
                        }
                        .padding(.top, 4)
                    }
                    .padding(12)
                }
                .background(AppTheme.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            // Silently fail if no active custom ads exist
            EmptyView()
        }
    }
}
