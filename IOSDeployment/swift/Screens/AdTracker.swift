import Foundation

class AdTracker {
    static let shared = AdTracker()
    
    func logImpression(postId: String, module: String, adType: String) {
        Task {
            do {
                let endpoint = try APIEndpoint.trackAdImpression(postId: postId, module: module, adType: adType)
                let _ = try await APIClient.shared.request(endpoint, responseType: MessageResponse.self)
            } catch {
                print("Failed to track ad impression: \(error)")
            }
        }
    }
}
