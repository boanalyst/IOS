// APIEndpoints.swift
// iOS port of BoAnalystApi.kt — defines all API endpoints as typed values

import Foundation

// MARK: - API Endpoint Definition

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    var body: Data? = nil
    var queryItems: [URLQueryItem]? = nil
    var multipartData: MultipartFormData? = nil
}

// MARK: - Endpoint Builders (mirrors Retrofit interface annotations)

extension APIEndpoint {

    // ── Auth ─────────────────────────────────────────────────────────────────

    static func login(email: String, password: String) throws -> APIEndpoint {
        let body = try JSONEncoder().encode(LoginRequest(email: email, password: password))
        return APIEndpoint(path: "/api/auth/login", method: .POST, body: body)
    }

    static func register(email: String, password: String, name: String) throws -> APIEndpoint {
        let body = try JSONEncoder().encode(RegisterRequest(email: email, password: password, name: name))
        return APIEndpoint(path: "/api/auth/register", method: .POST, body: body)
    }

    static let getMe = APIEndpoint(path: "/api/auth/me", method: .GET)
    static let getUserProfile = APIEndpoint(path: "/api/user/profile", method: .GET)
    static let logout = APIEndpoint(path: "/api/auth/logout", method: .POST)

    static func updateProfile(name: String?, email: String?, username: String?, bio: String?) throws -> APIEndpoint {
        let body = try JSONEncoder().encode(UpdateProfileRequest(name: name, email: email, username: username, bio: bio))
        return APIEndpoint(path: "/api/user/profile", method: .PUT, body: body)
    }

    static let deleteAccount = APIEndpoint(path: "/api/auth/account", method: .DELETE)

    // ── Flock Feed ────────────────────────────────────────────────────────────

    static func getFlockPosts(offset: Int = 0, limit: Int = 20, topic: String? = nil) -> APIEndpoint {
        var items = [URLQueryItem(name: "offset", value: "\(offset)"),
                     URLQueryItem(name: "limit", value: "\(limit)")]
        if let topic = topic { items.append(URLQueryItem(name: "topic", value: topic)) }
        return APIEndpoint(path: "/api/flock/posts", method: .GET, queryItems: items)
    }

    static let getTrendingTopics = APIEndpoint(path: "/api/flock/trending", method: .GET)

    static func createFlockPost(content: String, mediaData: Data? = nil, mimeType: String? = nil, fileName: String? = nil) throws -> APIEndpoint {
        if let data = mediaData, let mime = mimeType, let name = fileName {
            var multipart = MultipartFormData()
            multipart.append(name: "content", string: content)
            multipart.append(name: "media", data: data, filename: name, mimeType: mime)
            var endpoint = APIEndpoint(path: "/api/flock/posts", method: .POST)
            endpoint.multipartData = multipart
            return endpoint
        }
        let body = try JSONSerialization.data(withJSONObject: ["content": content])
        return APIEndpoint(path: "/api/flock/posts", method: .POST, body: body)
    }

    static func likePost(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(id)/like", method: .POST)
    }

    static func unlikePost(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(id)/like", method: .DELETE)
    }

    static func getComments(postId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(postId)/comments", method: .GET)
    }

    static func addComment(postId: String, text: String) throws -> APIEndpoint {
        // NOTE: server expects key "content", NOT "text" — matches Android addComment body
        let body = try JSONSerialization.data(withJSONObject: ["content": text])
        return APIEndpoint(path: "/api/flock/posts/\(postId)/comments", method: .POST, body: body)
    }

    static func deleteComment(postId: String, commentId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(postId)/comments/\(commentId)", method: .DELETE)
    }

    static func deleteFlockPost(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(id)", method: .DELETE)
    }

    static func pinFlockPost(id: String, isPinned: Bool) throws -> APIEndpoint {
        let body = try JSONSerialization.data(withJSONObject: ["is_pinned": isPinned ? 1 : 0])
        return APIEndpoint(path: "/api/flock/posts/\(id)/pin", method: .PUT, body: body)
    }

    // ── Movies / Box Office ───────────────────────────────────────────────

    static let getNowPlaying = APIEndpoint(path: "/api/movies/now-playing", method: .GET)
    static let getUpcoming = APIEndpoint(path: "/api/movies/upcoming", method: .GET)  // ADD: was missing
    static let getBoxOfficeEntries = APIEndpoint(path: "/api/box-office/entries", method: .GET)
    static let getBmsLiveTickets = APIEndpoint(path: "/api/box-office/live", method: .GET)

    // ── Polls ─────────────────────────────────────────────────────────────────

    static let getPolls = APIEndpoint(path: "/api/polls", method: .GET)

    static func votePoll(id: String, optionId: Int) throws -> APIEndpoint {
        let body = try JSONEncoder().encode(VoteRequest(optionId: optionId))
        return APIEndpoint(path: "/api/polls/\(id)/vote", method: .POST, body: body)
    }

    // ── Inside Talk ───────────────────────────────────────────────────────────

    static func getInsideTalk(page: Int = 1, limit: Int = 20) -> APIEndpoint {
        let items = [URLQueryItem(name: "page", value: "\(page)"),
                     URLQueryItem(name: "limit", value: "\(limit)")]
        return APIEndpoint(path: "/api/twitter/inside-talk/tweets", method: .GET, queryItems: items)
    }

    static let getInsideTalkCount = APIEndpoint(path: "/api/twitter/inside-talk/count", method: .GET)
    static let getExclusiveContent = APIEndpoint(path: "/api/exclusive/content", method: .GET)

    static func createInsideTalkPost(text: String, mediaData: Data? = nil, mimeType: String? = nil, fileName: String? = nil) throws -> APIEndpoint {
        if let data = mediaData, let mime = mimeType, let name = fileName {
            var multipart = MultipartFormData()
            multipart.append(name: "text", string: text)
            // Ensure media is received perfectly by sending as array syntax if node expects it just in case, but keep standard 'media' first. 
            multipart.append(name: "media", data: data, filename: name, mimeType: mime)
            var endpoint = APIEndpoint(path: "/api/twitter/create-post-with-media", method: .POST)
            endpoint.multipartData = multipart
            return endpoint
        }
        let body = try JSONSerialization.data(withJSONObject: ["text": text])
        return APIEndpoint(path: "/api/twitter/create-post", method: .POST, body: body)
    }

    static func updateInsideTalkPost(id: String, text: String) throws -> APIEndpoint {
        let body = try JSONSerialization.data(withJSONObject: ["text": text])
        return APIEndpoint(path: "/api/twitter/edit-tweet/\(id)", method: .PUT, body: body)
    }

    static func deleteInsideTalkPost(id: String) -> APIEndpoint {
        let items = [URLQueryItem(name: "tweetId", value: id)]
        return APIEndpoint(path: "/api/twitter/delete-tweet", method: .DELETE, queryItems: items)
    }

    static func toggleInsideTalkLike(tweetId: String) throws -> APIEndpoint {
        let body = try JSONSerialization.data(withJSONObject: ["tweetId": tweetId])
        return APIEndpoint(path: "/api/twitter/toggle-like", method: .POST, body: body)
    }

    static func addInsideTalkReply(tweetId: String, text: String) throws -> APIEndpoint {
        let body = try JSONSerialization.data(withJSONObject: ["tweetId": tweetId, "text": text])
        return APIEndpoint(path: "/api/twitter/add-reply", method: .POST, body: body)
    }

    static func getInsideTalkReplies(tweetId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/twitter/inside-talk/tweets/\(tweetId)/replies", method: .GET)
    }

    static func deleteInsideTalkReply(replyId: String, tweetId: String) -> APIEndpoint {
        let items = [URLQueryItem(name: "replyId", value: replyId),
                     URLQueryItem(name: "tweetId", value: tweetId)]
        return APIEndpoint(path: "/api/twitter/delete-reply", method: .DELETE, queryItems: items)
    }

    static func pinInsideTalkPost(id: String, isPinned: Bool) throws -> APIEndpoint {
        let body = try JSONSerialization.data(withJSONObject: ["tweetId": id, "isPinned": isPinned])
        return APIEndpoint(path: "/api/twitter/pin-tweet", method: .PUT, body: body)
    }

    // ── Distributors Hub ──────────────────────────────────────────────────────

    static func getDistributorsHub(offset: Int = 0, limit: Int = 10) -> APIEndpoint {
        let items = [URLQueryItem(name: "offset", value: "\(offset)"),
                     URLQueryItem(name: "limit", value: "\(limit)")]
        return APIEndpoint(path: "/api/distributors/posts", method: .GET, queryItems: items)
    }

    static func createDistributorsPost(content: String, mediaData: Data? = nil, mimeType: String? = nil, fileName: String? = nil) throws -> APIEndpoint {
        if let data = mediaData, let mime = mimeType, let name = fileName {
            var multipart = MultipartFormData()
            multipart.append(name: "content", string: content)
            multipart.append(name: "media", data: data, filename: name, mimeType: mime)
            var endpoint = APIEndpoint(path: "/api/distributors/posts", method: .POST)
            endpoint.multipartData = multipart
            return endpoint
        }
        let body = try JSONSerialization.data(withJSONObject: ["content": content])
        return APIEndpoint(path: "/api/distributors/posts", method: .POST, body: body)
    }

    static func updateDistributorsPost(id: String, content: String) throws -> APIEndpoint {
        let body = try JSONSerialization.data(withJSONObject: ["content": content])
        return APIEndpoint(path: "/api/distributors/posts/\(id)", method: .PUT, body: body)
    }

    static func deleteDistributorsPost(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/distributors/posts/\(id)", method: .DELETE)
    }

    static func likeDistributorsPost(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/distributors/posts/\(id)/like", method: .POST)
    }

    static func pinDistributorsPost(id: String, isPinned: Bool) throws -> APIEndpoint {
        let body = try JSONSerialization.data(withJSONObject: ["is_pinned": isPinned ? 1 : 0])
        return APIEndpoint(path: "/api/distributors/posts/\(id)/pin", method: .PUT, body: body)
    }

    // ── Apple In-App Purchase — Receipt Verification ──────────────────────────
    // After a successful StoreKit 2 transaction, send the transaction details
    // to our backend so it can mark the user as Pro in the database.
    // The backend should verify the transaction ID with Apple's /verifyReceipt
    // or App Store Server API, then update the user's subscription_plan.

    static func verifyAppleReceipt(
        transactionId: String,
        originalTransactionId: String,
        productId: String,
        expiresDate: Date?
    ) throws -> APIEndpoint {
        var payload: [String: Any] = [
            "transactionId": transactionId,
            "originalTransactionId": originalTransactionId,
            "productId": productId,
            "platform": "ios"
        ]
        if let expires = expiresDate {
            payload["expiresDate"] = ISO8601DateFormatter().string(from: expires)
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        return APIEndpoint(path: "/api/subscription/verify-apple", method: .POST, body: body)
    }
}
