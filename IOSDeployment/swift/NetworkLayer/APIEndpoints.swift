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

    // ── Tracking ────────────────────────────────────────────────────────────

    static func trackAdImpression(postId: String, module: String, adType: String) throws -> APIEndpoint {
        let payload = ["postId": postId, "module": module, "adType": adType]
        let body = try JSONEncoder().encode(payload)
        return APIEndpoint(path: "/api/tracking/ad-impression", method: .POST, body: body)
    }

    static let getAdConfig = APIEndpoint(path: "/api/tracking/ad-config", method: .GET)

    // ── Flock Feed ────────────────────────────────────────────────────────────

    static func getFlockPosts(offset: Int = 0, limit: Int = 20, topic: String? = nil) -> APIEndpoint {
        var items = [URLQueryItem(name: "offset", value: "\(offset)"),
                     URLQueryItem(name: "limit", value: "\(limit)")]
        if let topic = topic { items.append(URLQueryItem(name: "topic", value: topic)) }
        return APIEndpoint(path: "/api/flock/posts", method: .GET, queryItems: items)
    }

    static let getTrendingTopics = APIEndpoint(path: "/api/flock/trending", method: .GET)

    static func createFlockPost(content: String, mediaFiles: [(data: Data, mimeType: String, fileName: String)] = [], pollQuestion: String? = nil, pollOptions: [String]? = nil, pollEndsAt: String? = nil) throws -> APIEndpoint {
        let hasPoll = pollQuestion != nil && !(pollQuestion?.isEmpty ?? true)
        if !mediaFiles.isEmpty || hasPoll {
            var multipart = MultipartFormData()
            multipart.append(name: "content", string: content)
            if let pq = pollQuestion { multipart.append(name: "poll_question", string: pq) }
            if let opts = pollOptions, let optsData = try? JSONSerialization.data(withJSONObject: opts), let optsString = String(data: optsData, encoding: .utf8) {
                multipart.append(name: "poll_options", string: optsString)
            }
            if let pe = pollEndsAt { multipart.append(name: "poll_ends_at", string: pe) }
            for file in mediaFiles {
                multipart.append(name: "media", data: file.data, filename: file.fileName, mimeType: file.mimeType)
            }
            var endpoint = APIEndpoint(path: "/api/flock/posts", method: .POST)
            endpoint.multipartData = multipart
            return endpoint
        }
        var bodyDict: [String: Any] = ["content": content]
        if let pq = pollQuestion { bodyDict["poll_question"] = pq }
        if let opts = pollOptions { bodyDict["poll_options"] = opts }
        if let pe = pollEndsAt { bodyDict["poll_ends_at"] = pe }
        let body = try JSONSerialization.data(withJSONObject: bodyDict)
        return APIEndpoint(path: "/api/flock/posts", method: .POST, body: body)
    }

    static func updateFlockPost(id: String, content: String, existingMediaUrls: [String]? = nil, mediaFiles: [(data: Data, mimeType: String, fileName: String)] = []) throws -> APIEndpoint {
        if !mediaFiles.isEmpty || existingMediaUrls != nil {
            var multipart = MultipartFormData()
            multipart.append(name: "content", string: content)
            if let existing = existingMediaUrls, let jsonData = try? JSONSerialization.data(withJSONObject: existing), let jsonStr = String(data: jsonData, encoding: .utf8) {
                multipart.append(name: "existingMedia", string: jsonStr)
            }
            for file in mediaFiles {
                multipart.append(name: "media", data: file.data, filename: file.fileName, mimeType: file.mimeType)
            }
            var endpoint = APIEndpoint(path: "/api/flock/posts/\(id)", method: .PUT)
            endpoint.multipartData = multipart
            return endpoint
        }
        let body = try JSONSerialization.data(withJSONObject: ["content": content])
        return APIEndpoint(path: "/api/flock/posts/\(id)", method: .PUT, body: body)
    }

    static func getFlockPost(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(id)", method: .GET)
    }

    static func likePost(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(id)/like", method: .POST)
    }

    static func unlikePost(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(id)/like", method: .DELETE)
    }

    static func getComments(postId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(postId)/replies", method: .GET)
    }

    static func addComment(postId: String, text: String) throws -> APIEndpoint {
        // NOTE: server expects key "content", NOT "text" — matches Android addComment body
        let body = try JSONSerialization.data(withJSONObject: ["content": text])
        return APIEndpoint(path: "/api/flock/posts/\(postId)/reply", method: .POST, body: body)
    }

    static func deleteComment(postId: String, commentId: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(postId)/replies/\(commentId)", method: .DELETE)
    }

    static func deleteFlockPost(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/flock/posts/\(id)", method: .DELETE)
    }

    static func pinFlockPost(id: String, isPinned: Bool) throws -> APIEndpoint {
        let body = try JSONSerialization.data(withJSONObject: ["isPinned": isPinned, "is_pinned": isPinned])
        return APIEndpoint(path: "/api/flock/posts/\(id)/pin", method: .PUT, body: body)
    }

    // ── Movies / Box Office ───────────────────────────────────────────────

    static let getNowPlaying = APIEndpoint(path: "/api/movies/now-playing", method: .GET)
    static let getUpcoming = APIEndpoint(path: "/api/movies/upcoming", method: .GET)  // ADD: was missing
    static func getOttReleases(status: String = "released") -> APIEndpoint {
        let items = [URLQueryItem(name: "status", value: status)]
        return APIEndpoint(path: "/api/movies/ott-releases", method: .GET, queryItems: items)
    }
    static func getBoxOfficeEntries(language: String = "all") -> APIEndpoint {
        let items = [URLQueryItem(name: "language", value: language)]
        return APIEndpoint(path: "/api/box-office/top-grossers", method: .GET, queryItems: items)
    }
    static let getBmsLiveTickets = APIEndpoint(path: "/api/box-office/live", method: .GET)

    // ── Polls ─────────────────────────────────────────────────────────────────

    static let getPolls = APIEndpoint(path: "/api/polls", method: .GET)

    static func votePoll(id: String, optionId: String) throws -> APIEndpoint {
        let body = try JSONEncoder().encode(VoteRequest(optionId: optionId, pollId: id))
        return APIEndpoint(path: "/api/polls/vote", method: .POST, body: body)
    }

    // ── Inside Talk ───────────────────────────────────────────────────────────

    static func getInsideTalk(page: Int = 1, limit: Int = 20) -> APIEndpoint {
        let items = [URLQueryItem(name: "page", value: "\(page)"),
                     URLQueryItem(name: "limit", value: "\(limit)")]
        return APIEndpoint(path: "/api/twitter/inside-talk/tweets", method: .GET, queryItems: items)
    }

    static let getInsideTalkCount = APIEndpoint(path: "/api/twitter/inside-talk/count", method: .GET)
    static let getExclusiveContent = APIEndpoint(path: "/api/exclusive/content", method: .GET)
    static let getFullExclusiveContent = APIEndpoint(path: "/api/exclusive/full-content", method: .GET)

    /// Admin: Update exclusive content (title, description, price, optional new media files).
    /// Uses multipart/form-data so images can be attached alongside text fields.
    static func updateExclusiveContent(
        title: String,
        description: String,
        price: Double,
        existingMedia: [String],
        newMediaData: [(data: Data, filename: String, mimeType: String)] = []
    ) throws -> APIEndpoint {
        var multipart = MultipartFormData()
        multipart.append(name: "title", string: title)
        multipart.append(name: "description", string: description)
        multipart.append(name: "price", string: String(price))
        multipart.append(name: "currency", string: "INR")
        if !existingMedia.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: existingMedia),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                multipart.append(name: "existingMedia", string: jsonString)
            }
        }
        for item in newMediaData {
            multipart.append(name: "media", data: item.data, filename: item.filename, mimeType: item.mimeType)
        }
        var endpoint = APIEndpoint(path: "/api/exclusive/update", method: .POST)
        endpoint.multipartData = multipart
        return endpoint
    }


    static func createInsideTalkPost(text: String, mediaFiles: [(data: Data, mimeType: String, fileName: String)] = []) throws -> APIEndpoint {
        if !mediaFiles.isEmpty {
            var multipart = MultipartFormData()
            multipart.append(name: "text", string: text)
            for file in mediaFiles {
                multipart.append(name: "media", data: file.data, filename: file.fileName, mimeType: file.mimeType)
            }
            var endpoint = APIEndpoint(path: "/api/twitter/create-post-with-media", method: .POST)
            endpoint.multipartData = multipart
            return endpoint
        }
        let body = try JSONSerialization.data(withJSONObject: ["text": text])
        return APIEndpoint(path: "/api/twitter/create-post", method: .POST, body: body)
    }

    static func updateInsideTalkPost(id: String, text: String, existingMediaUrls: [String]? = nil) throws -> APIEndpoint {
        // Backend /edit-tweet/:id expects "content" key (NOT "text") — matches twitterRoutes.js line 1353
        var payload: [String: Any] = ["content": text]
        if let existing = existingMediaUrls {
            payload["existingMedia"] = existing
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
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
        let body = try JSONSerialization.data(withJSONObject: ["tweetId": id, "isPinned": isPinned, "is_pinned": isPinned])
        return APIEndpoint(path: "/api/twitter/pin-tweet", method: .PUT, body: body)
    }

    // ── Buzz Board ────────────────────────────────────────────────────────────

    static func getBuzzPosts(category: String = "all", offset: Int = 0, limit: Int = 20) -> APIEndpoint {
        let items = [URLQueryItem(name: "category", value: category),
                     URLQueryItem(name: "offset", value: "\(offset)"),
                     URLQueryItem(name: "limit", value: "\(limit)")]
        return APIEndpoint(path: "/api/buzz/posts", method: .GET, queryItems: items)
    }

    static func getBuzzPost(id: String) -> APIEndpoint {
        return APIEndpoint(path: "/api/buzz/posts/\(id)", method: .GET)
    }

    static func createBuzzPost(title: String, content: String, category: String, tags: [String] = []) throws -> APIEndpoint {
        let body = try JSONSerialization.data(withJSONObject: [
            "title": title, "content": content, "category": category, "tags": tags
        ])
        return APIEndpoint(path: "/api/buzz/posts", method: .POST, body: body)
    }

    static func toggleBuzzLike(postId: String) -> APIEndpoint {
        return APIEndpoint(path: "/api/buzz/posts/\(postId)/like", method: .POST)
    }

    static func getBuzzComments(postId: String, offset: Int = 0, limit: Int = 50) -> APIEndpoint {
        let items = [URLQueryItem(name: "offset", value: "\(offset)"),
                     URLQueryItem(name: "limit", value: "\(limit)")]
        return APIEndpoint(path: "/api/buzz/posts/\(postId)/comments", method: .GET, queryItems: items)
    }

    static func addBuzzComment(postId: String, content: String) throws -> APIEndpoint {
        let body = try JSONSerialization.data(withJSONObject: ["content": content])
        return APIEndpoint(path: "/api/buzz/posts/\(postId)/comments", method: .POST, body: body)
    }

    static func deleteBuzzPost(postId: String) -> APIEndpoint {
        return APIEndpoint(path: "/api/buzz/posts/\(postId)", method: .DELETE)
    }

    static func deleteBuzzComment(postId: String, commentId: String) -> APIEndpoint {
        return APIEndpoint(path: "/api/buzz/posts/\(postId)/comments/\(commentId)", method: .DELETE)
    }

    // ── Distributors Hub ──────────────────────────────────────────────────────

    static func getDistributorsHub(offset: Int = 0, limit: Int = 10) -> APIEndpoint {
        let items = [URLQueryItem(name: "offset", value: "\(offset)"),
                     URLQueryItem(name: "limit", value: "\(limit)")]
        return APIEndpoint(path: "/api/distributors/posts", method: .GET, queryItems: items)
    }

    static func createDistributorsPost(content: String, mediaFiles: [(data: Data, mimeType: String, fileName: String)] = []) throws -> APIEndpoint {
        if !mediaFiles.isEmpty {
            var multipart = MultipartFormData()
            multipart.append(name: "content", string: content)
            for file in mediaFiles {
                multipart.append(name: "media", data: file.data, filename: file.fileName, mimeType: file.mimeType)
            }
            var endpoint = APIEndpoint(path: "/api/distributors/posts", method: .POST)
            endpoint.multipartData = multipart
            return endpoint
        }
        let body = try JSONSerialization.data(withJSONObject: ["content": content])
        return APIEndpoint(path: "/api/distributors/posts", method: .POST, body: body)
    }

    static func updateDistributorsPost(id: String, content: String, existingMediaUrls: [String]? = nil, mediaFiles: [(data: Data, mimeType: String, fileName: String)] = []) throws -> APIEndpoint {
        if !mediaFiles.isEmpty || existingMediaUrls != nil {
            var multipart = MultipartFormData()
            multipart.append(name: "content", string: content)
            if let existing = existingMediaUrls, let jsonData = try? JSONSerialization.data(withJSONObject: existing), let jsonStr = String(data: jsonData, encoding: .utf8) {
                multipart.append(name: "existingMedia", string: jsonStr)
            }
            for file in mediaFiles {
                multipart.append(name: "media", data: file.data, filename: file.fileName, mimeType: file.mimeType)
            }
            var endpoint = APIEndpoint(path: "/api/distributors/posts/\(id)", method: .PUT)
            endpoint.multipartData = multipart
            return endpoint
        }
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
        let body = try JSONSerialization.data(withJSONObject: ["pinned": isPinned])
        return APIEndpoint(path: "/api/distributors/posts/\(id)/pin", method: .PATCH, body: body)
    }

    // ── Tech Deals ────────────────────────────────────────────────────────────

    static let getTechDealCategories = APIEndpoint(path: "/api/tech-deals/categories", method: .GET)
    
    static func getTechDeals(offset: Int = 0, limit: Int = 20, category: String = "all") -> APIEndpoint {
        let items = [URLQueryItem(name: "offset", value: "\(offset)"),
                     URLQueryItem(name: "limit", value: "\(limit)"),
                     URLQueryItem(name: "category", value: category)]
        return APIEndpoint(path: "/api/tech-deals", method: .GET, queryItems: items)
    }
    
    static func trackTechDealClick(id: String) -> APIEndpoint {
        return APIEndpoint(path: "/api/tech-deals/\(id)/click", method: .POST)
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
        return APIEndpoint(path: "/api/auth/subscription/verify-apple", method: .POST, body: body)
    }
}
