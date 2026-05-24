import Foundation

class AdTracker {
    static let shared = AdTracker()
    
    func logImpression(postId: String, module: String, adType: String) {
        Task {
            do {
                let endpoint = try APIEndpoint.trackAdImpression(postId: postId, module: module, adType: adType)
                let _ : MessageResponse = try await APIClient.shared.request(endpoint)
            } catch {
                print("Failed to track ad impression: \(error)")
            }
        }
    }
}
