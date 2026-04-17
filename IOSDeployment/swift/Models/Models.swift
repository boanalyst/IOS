// Models.swift
// iOS port of Android's Models.kt — all data models as Swift Codable structs

import Foundation

// MARK: - Auth

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let name: String
}

struct AuthResponse: Decodable {
    let success: Bool
    let token: String?
    let user: User?
    let message: String?
}

struct ProfileResponse: Decodable {
    let success: Bool
    let user: User?
}

struct UserProfileResponse: Decodable {
    let success: Bool
    let user: User?
}

struct UpdateProfileRequest: Encodable {
    let name: String?
    let email: String?
    let username: String?
    let bio: String?
}

// MARK: - Message Response

struct MessageResponse: Decodable {
    let success: Bool
    let message: String?
}

// MARK: - User
// IMPORTANT: Mirrors Android's User.kt — isPro/isAdmin/isDistributor are COMPUTED
// from subscriptionPlan + role, NOT decoded directly. This matches the server schema.

struct User: Decodable, Identifiable {
    let id: String
    let name: String
    let email: String
    let role: String            // "member" | "admin" | "superadmin" | "moderator"
    let subscriptionPlan: String?  // "premium-monthly" | "premium-yearly" | "distributors-hub"
    let username: String?
    let bio: String?
    let profileBio: String?
    
    var resolvedBio: String? {
        if let b = bio, !b.isEmpty { return b }
        return profileBio
    }

    private let _isAdmin: Bool?
    let avatarUrl: String?
    let createdAt: String?

    // ── Computed permission getters — mirrors Android User.kt ──────────────
    var isAdmin: Bool {
        _isAdmin == true ||
        role == "admin" || role == "superadmin" || role == "moderator"
    }

    var isPro: Bool {
        isAdmin ||
        subscriptionPlan == "distributors-hub" ||
        subscriptionPlan == "premium-monthly" ||
        subscriptionPlan == "premium-yearly" ||
        subscriptionPlan?.contains("premium") == true ||
        subscriptionPlan?.contains("pro") == true
    }

    var isDistributor: Bool {
        isAdmin || subscriptionPlan == "distributors-hub"
    }

    // memberSinceDate: derived from createdAt ISO string
    var memberSinceDays: Int? {
        guard let raw = createdAt else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fmt.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let joined = date else { return nil }
        return Calendar.current.dateComponents([.day], from: joined, to: Date()).day
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case id2 = "id"           // some endpoints return "id" instead of "_id"
        case name, email, role, username, bio
        case subscriptionPlan = "subscriptionPlan"
        case _isAdmin = "isAdmin"
        case avatarUrl = "avatar_url"
        case createdAt = "createdAt"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Accept both "_id" and "id" (different endpoints use different keys)
        id = (try? c.decode(String.self, forKey: .id)) ?? (try? c.decode(String.self, forKey: .id2)) ?? UUID().uuidString
        name  = (try? c.decode(String.self, forKey: .name))  ?? ""
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        username = try? c.decode(String.self, forKey: .username)
        bio = try? c.decode(String.self, forKey: .bio)
        
        // For profile JSON string (simplified approach: skip profile bio unnesting here since 'bio' is usually top level too)
        profileBio = nil 
        
        role  = (try? c.decode(String.self, forKey: .role))  ?? "member"
        subscriptionPlan = try? c.decode(String.self, forKey: .subscriptionPlan)
        
        if let b = try? c.decode(Bool.self, forKey: ._isAdmin) {
            _isAdmin = b
        } else if let i = try? c.decode(Int.self, forKey: ._isAdmin) {
            _isAdmin = (i != 0)
        } else {
            _isAdmin = false
        }
        
        avatarUrl = try? c.decode(String.self, forKey: .avatarUrl)
        createdAt = try? c.decode(String.self, forKey: .createdAt)
    }
}

// MARK: - Generic API Result

struct ApiResult<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let message: String?
}

// MARK: - Flock

struct FlockFeedResponse: Decodable {
    let success: Bool
    let posts: [FlockPost]
    // Server returns offset/limit pagination (like Android) not total/hasMore
    let count: Int?
    let limit: Int?
    let offset: Int?
}

// Matches the FLAT server schema — Android is authoritative.
// The server does NOT nest author fields; they are top-level strings.
// NOTE: Server returns "id" (not "_id") for flock posts — handle both.
struct FlockPost: Decodable, Identifiable {
    let id: String
    let content: String
    let authorName: String
    let authorHandle: String?
    let authorId: String?
    let tags: [String]          // server key: "hashtags"
    let media: [FlockMedia]
    let likeCount: Int
    let replyCount: Int
    let isPinned: Bool          // MySQL TINYINT 0/1 decoded as Int then to Bool
    let userLiked: Bool         // mirrors Android FlockPost.userLiked
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id                 // server returns "id" (NOT "_id") for flock posts
        case idMongo = "_id"   // fallback if server ever switches to MongoDB _id
        case content
        case authorName = "author_name"
        case authorHandle = "author_handle"
        case authorId = "author_id"
        case tags = "hashtags"
        case media
        case likeCount = "like_count"
        case replyCount = "reply_count"
        case isPinned = "is_pinned"
        case userLiked = "user_liked"
        case createdAt = "created_at"
    }

    // Custom decoder: handles both "id" and "_id", plus TINYINT booleans
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Accept both "id" (MySQL) and "_id" (MongoDB)
        id = (try? c.decode(String.self, forKey: .id))
          ?? (try? c.decode(String.self, forKey: .idMongo))
          ?? UUID().uuidString
        content    = (try? c.decode(String.self, forKey: .content)) ?? ""
        authorName = (try? c.decode(String.self, forKey: .authorName)) ?? ""
        authorHandle = try? c.decode(String.self, forKey: .authorHandle)
        authorId     = try? c.decode(String.self, forKey: .authorId)
        tags  = (try? c.decode([String].self, forKey: .tags)) ?? []
        media = (try? c.decode([FlockMedia].self, forKey: .media)) ?? []
        likeCount  = (try? c.decode(Int.self, forKey: .likeCount))  ?? 0
        replyCount = (try? c.decode(Int.self, forKey: .replyCount)) ?? 0
        createdAt  = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        func decodeBool(_ key: CodingKeys) -> Bool {
            if let b = try? c.decode(Bool.self, forKey: key) { return b }
            if let i = try? c.decode(Int.self,  forKey: key) { return i != 0 }
            return false
        }
        isPinned  = decodeBool(.isPinned)
        userLiked = decodeBool(.userLiked)
    }

    // Memberwise copy initializer for optimistic UI mutations
    init(from existing: FlockPost, likeCount: Int? = nil, replyCount: Int? = nil, userLiked: Bool? = nil, isPinned: Bool? = nil) {
        self.id           = existing.id
        self.content      = existing.content
        self.authorName   = existing.authorName
        self.authorHandle = existing.authorHandle
        self.authorId     = existing.authorId
        self.tags         = existing.tags
        self.media        = existing.media
        self.likeCount    = likeCount  ?? existing.likeCount
        self.replyCount   = replyCount ?? existing.replyCount
        self.isPinned     = isPinned   ?? existing.isPinned
        self.userLiked    = userLiked  ?? existing.userLiked
        self.createdAt    = existing.createdAt
    }
}

struct FlockMedia: Decodable {
    let url: String
    let type: String
    enum CodingKeys: String, CodingKey {
        case url = "media_url"
        case type = "media_type"
    }
}

struct LikeResponse: Decodable {
    let success: Bool
    let likeCount: Int
    enum CodingKeys: String, CodingKey {
        case success
        case likeCount = "like_count"
    }
}

struct CommentResponse: Decodable {
    let success: Bool
    let comments: [Comment]?
    let data: [Comment]?
    var resolvedComments: [Comment] { comments ?? data ?? [] }
}

struct Comment: Decodable, Identifiable {
    let id: String
    let content: String
    let authorName: String
    let userId: String?        // author's user id — used for delete permission check
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case content
        case authorName = "author_name"
        case userId = "author_id"
        case createdAt = "created_at"
    }
}

struct AddCommentResponse: Decodable {
    let success: Bool
    let comment: Comment?
    let data: Comment?
    var resolvedComment: Comment? { comment ?? data }
}

// TrendingTrend — mirrors Android TrendingTrend model name
// Server returns: { topic, count } inside a "trends" array
struct TrendingTrend: Decodable, Identifiable {
    var id: String { topic }
    let topic: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case topic = "name"
        case count = "post_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        topic = (try? c.decode(String.self, forKey: .topic)) ?? ""
        // post_count may be a String ("42") or Int
        if let intVal = try? c.decode(Int.self, forKey: .count) {
            count = intVal
        } else if let strVal = try? c.decode(String.self, forKey: .count), let parsed = Int(strVal) {
            count = parsed
        } else {
            count = 0
        }
    }
}

struct TrendingResponse: Decodable {
    let success: Bool
    let trends: [TrendingTrend]
    let totalCount: Int?
    let source: String?
    enum CodingKeys: String, CodingKey {
        case success, trends, source
        case totalCount = "count"
    }
}

// MARK: - Movies / Analytics

struct MovieResponse: Decodable {
    let success: Bool
    let movies: [Movie]
}

// NOTE: Server returns movies with NO id field.
// posterPath is already a fully-qualified https:// URL — do NOT prepend base URL.
struct Movie: Decodable, Identifiable {
    let id: String          // synthesized from title+releaseDate — server sends no id
    let title: String
    let posterPath: String? // FULL URL e.g. https://media.themoviedb.org/...
    let releaseDate: String?
    let overview: String?
    let link: String?
    let rating: Double?

    enum CodingKeys: String, CodingKey {
        case title
        case posterPath  = "posterPath"   // server uses camelCase
        case releaseDate = "releaseDate"
        case overview, link, rating
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title       = (try? c.decode(String.self, forKey: .title)) ?? ""
        posterPath  = try? c.decode(String.self, forKey: .posterPath)
        releaseDate = try? c.decode(String.self, forKey: .releaseDate)
        overview    = try? c.decode(String.self, forKey: .overview)
        link        = try? c.decode(String.self, forKey: .link)
        rating      = try? c.decode(Double.self, forKey: .rating)
        // Synthesise a stable id from title + releaseDate
        id = "\(title)-\(releaseDate ?? "")"
    }
}

struct BoxOfficeResponse: Decodable {
    let success: Bool
    let data: [BoxOfficeEntry]  // server key is "data" — matches Android BoxOfficeResponse
}

struct BoxOfficeEntry: Decodable, Identifiable {
    var id: String { title }
    let title: String
    let collection: String
    let budget: String
    let verdict: String
    let verdictColor: String
}

struct BmsLiveResponse: Decodable {
    let success: Bool
    let data: BmsLiveData?
}

struct BmsLiveData: Decodable {
    let total: Int
    let shows: [BmsShow]
}

struct BmsShow: Decodable, Identifiable {
    // Use `movie` as the stable identity
    var id: String { movie }
    let movie: String
    let tickets: Int
}

// MARK: - Polls

struct Poll: Decodable, Identifiable {
    let id: String
    let question: String
    let options: [PollOption]
    let totalVotes: Int
    let endsAt: String?
    let userVotedOptionId: Int?  // matches Android Poll.userVotedOptionId: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case id2 = "id"          // some endpoints return numeric/string id
        case question, options
        case totalVotes = "total_votes"
        case endsAt = "ends_at"
        case userVotedOptionId = "user_voted_option_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Server may use _id (MongoDB) or id (MySQL)
        id = (try? c.decode(String.self, forKey: .id)) ?? (try? c.decode(String.self, forKey: .id2)) ?? UUID().uuidString
        question = try c.decode(String.self, forKey: .question)
        options = (try? c.decode([PollOption].self, forKey: .options)) ?? []
        totalVotes = (try? c.decode(Int.self, forKey: .totalVotes)) ?? 0
        endsAt = try? c.decode(String.self, forKey: .endsAt)
        userVotedOptionId = try? c.decode(Int.self, forKey: .userVotedOptionId)
    }
}

struct PollOption: Decodable, Identifiable {
    let id: Int            // matches Android PollOption.id: Int
    let text: String
    let votes: Int
    let percentage: Float
}

struct VoteRequest: Encodable {
    let optionId: Int      // matches Android VoteRequest(val optionId: Int)
    enum CodingKeys: String, CodingKey {
        case optionId = "option_id"
    }
}

// MARK: - Inside Talk

struct InsideTalkResponse: Decodable {
    let success: Bool
    let tweets: [InsideTalkContent]
    let pagination: InsideTalkPagination?

    enum CodingKeys: String, CodingKey {
        case success, tweets, data, pagination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = (try? container.decode(Bool.self, forKey: .success)) ?? false
        self.tweets = (try? container.decode([InsideTalkContent].self, forKey: .tweets)) 
                   ?? (try? container.decode([InsideTalkContent].self, forKey: .data)) 
                   ?? []
        self.pagination = try? container.decode(InsideTalkPagination.self, forKey: .pagination)
    }
}

struct InsideTalkPagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case page, limit, total
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        page = (try? c.decode(Int.self, forKey: .page)) ?? 1
        limit = (try? c.decode(Int.self, forKey: .limit)) ?? 20
        total = (try? c.decode(Int.self, forKey: .total)) ?? 0
        if let b = try? c.decode(Bool.self, forKey: .hasMore) {
            hasMore = b
        } else if let i = try? c.decode(Int.self, forKey: .hasMore) {
            hasMore = (i != 0)
        } else if let s = try? c.decode(String.self, forKey: .hasMore) {
            hasMore = (s == "true" || s == "1")
        } else {
            hasMore = false
        }
    }
}

struct InsideTalkCountResponse: Decodable {
    let success: Bool
    let count: Int
    let message: String?
}

// Matches Android InsideTalkContent — uses flat "content" + "author_name" fields
struct InsideTalkContent: Decodable, Identifiable {
    let id: String
    let content: String        // server field is "content", not "text"
    let authorName: String
    let media: [InsideTalkMedia]
    let likeCount: Int
    let dislikeCount: Int
    let replyCount: Int
    let isPinned: Bool
    let userLiked: Bool
    let userDisliked: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case mongoId = "_id"
        case content
        case authorName = "author_name"
        case media
        case likeCount = "like_count"
        case dislikeCount = "dislike_count"
        case replyCount = "reply_count"
        case isPinned = "is_pinned"
        case userLiked = "user_liked"
        case userDisliked = "user_disliked"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) 
               ?? (try? c.decode(String.self, forKey: .mongoId)) 
               ?? UUID().uuidString
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        authorName = (try? c.decode(String.self, forKey: .authorName)) ?? "BoAnalyst"
        media = (try? c.decode([InsideTalkMedia].self, forKey: .media)) ?? []
        likeCount = (try? c.decode(Int.self, forKey: .likeCount)) ?? 0
        dislikeCount = (try? c.decode(Int.self, forKey: .dislikeCount)) ?? 0
        replyCount = (try? c.decode(Int.self, forKey: .replyCount)) ?? 0
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        // TINYINT(1) booleans — may arrive as 0/1
        func decodeBool(_ key: CodingKeys) -> Bool {
            if let b = try? c.decode(Bool.self, forKey: key) { return b }
            if let i = try? c.decode(Int.self, forKey: key) { return i != 0 }
            return false
        }
        isPinned = decodeBool(.isPinned)
        userLiked = decodeBool(.userLiked)
        userDisliked = decodeBool(.userDisliked)
    }

    // Memberwise copy initializer for optimistic UI mutations
    init(from existing: InsideTalkContent,
         userLiked: Bool? = nil,
         likeCount: Int? = nil,
         replyCount: Int? = nil,
         isPinned: Bool? = nil) {
        self.id          = existing.id
        self.content     = existing.content
        self.authorName  = existing.authorName
        self.media       = existing.media
        self.likeCount   = likeCount   ?? existing.likeCount
        self.dislikeCount = existing.dislikeCount
        self.replyCount  = replyCount  ?? existing.replyCount
        self.isPinned    = isPinned    ?? existing.isPinned
        self.userLiked   = userLiked   ?? existing.userLiked
        self.userDisliked = existing.userDisliked
        self.createdAt   = existing.createdAt
    }
}

struct InsideTalkMedia: Decodable {
    let url: String?
    let type: String?
    let mediaUrl: String?
    let mediaType: String?

    func resolvedUrl() -> String {
        let raw = url ?? mediaUrl ?? ""
        guard !raw.isEmpty else { return "" }
        return raw.hasPrefix("http") ? raw : "https://boanalyst.com" + raw
    }
}

struct ExclusiveContentResponse: Decodable {
    let success: Bool
    let content: ExclusiveContent?
}

struct ExclusiveContent: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String
    let price: Double
    let currency: String?
    let mediaUrl: String?
    let isActive: Bool?
    let contentType: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, currency
        case mediaUrl, isActive, contentType
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Accept both "id" and "_id" to be safe
        self.id = (try? container.decode(String.self, forKey: .id)) 
               ?? (try? container.decode(String.self, forKey: CodingKeys(stringValue: "_id")!)) 
               ?? UUID().uuidString
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .description)
        self.price = try container.decodeIfPresent(Double.self, forKey: .price) ?? 0.0
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency)
        self.mediaUrl = try container.decodeIfPresent(String.self, forKey: .mediaUrl)
        self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

// MARK: - Inside Talk Social Responses

struct InsideTalkLikeResponse: Decodable {
    let success: Bool
    let likeCount: Int?
    let userLiked: Bool?
    enum CodingKeys: String, CodingKey {
        case success
        case likeCount  = "like_count"
        case userLiked  = "user_liked"
    }
}

struct InsideTalkReply: Decodable, Identifiable {
    let id: String
    let content: String
    let authorName: String
    let userId: String?
    let createdAt: String
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case content
        case authorName = "author_name"
        case userId = "author_id"
        case createdAt = "created_at"
    }
}

struct InsideTalkRepliesResponse: Decodable {
    let success: Bool
    let replies: [InsideTalkReply]?
    let data: [InsideTalkReply]?
    var resolvedReplies: [InsideTalkReply] { replies ?? data ?? [] }
}

struct InsideTalkReplyResponse: Decodable {
    let success: Bool
    let reply: InsideTalkReply?
    let data: InsideTalkReply?
    var resolvedReply: InsideTalkReply? { reply ?? data }
}

// MARK: - Distributors

struct DistributorsResponse: Decodable {
    let success: Bool
    let posts: [DistributorsPost]
    let pagination: DistributorsPagination?
}

struct DistributorsPagination: Decodable {
    let offset: Int
    let limit: Int
    let total: Int
}

// Matches Android DistributorsPost flat schema
struct DistributorsPost: Decodable, Identifiable {
    let id: String
    let content: String
    let authorName: String
    let authorHandle: String?
    let mediaUrls: [String]?
    let tags: [String]?
    let postType: String
    let priority: Int
    let isPinned: Bool
    let isFeatured: Bool
    let likeCount: Int
    let viewCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case content
        case authorName = "author_name"
        case authorHandle = "author_handle"
        case mediaUrls = "media_urls"
        case tags
        case postType = "post_type"
        case priority
        case isPinned = "is_pinned"
        case isFeatured = "is_featured"
        case likeCount = "like_count"
        case viewCount = "view_count"
        case createdAt = "created_at"
    }

    // Memberwise copy initializer for optimistic UI mutations
    init(from existing: DistributorsPost, likeCount: Int? = nil, isPinned: Bool? = nil) {
        self.id = existing.id
        self.content = existing.content
        self.authorName = existing.authorName
        self.authorHandle = existing.authorHandle
        self.mediaUrls = existing.mediaUrls
        self.tags = existing.tags
        self.postType = existing.postType
        self.priority = existing.priority
        self.isPinned = isPinned ?? existing.isPinned
        self.isFeatured = existing.isFeatured
        self.likeCount = likeCount ?? existing.likeCount
        self.viewCount = existing.viewCount
        self.createdAt = existing.createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        authorName = (try? c.decode(String.self, forKey: .authorName)) ?? "BoAnalyst"
        authorHandle = try? c.decode(String.self, forKey: .authorHandle)
        mediaUrls = try? c.decode([String].self, forKey: .mediaUrls)
        tags = try? c.decode([String].self, forKey: .tags)
        postType = (try? c.decode(String.self, forKey: .postType)) ?? "premium"
        priority = (try? c.decode(Int.self, forKey: .priority)) ?? 0
        likeCount = (try? c.decode(Int.self, forKey: .likeCount)) ?? 0
        viewCount = (try? c.decode(Int.self, forKey: .viewCount)) ?? 0
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        func decodeBool(_ key: CodingKeys) -> Bool {
            if let b = try? c.decode(Bool.self, forKey: key) { return b }
            if let i = try? c.decode(Int.self, forKey: key) { return i != 0 }
            return false
        }
        isPinned = decodeBool(.isPinned)
        isFeatured = decodeBool(.isFeatured)
    }
}

// MARK: - Subscription / Razorpay

struct AppConfig: Decodable {
    let razorpayKeyId: String?
    let razorpayPlanIdMonthly: String?
    let razorpayPlanIdYearly: String?
    let razorpayPlanIdDistributors: String?

    enum CodingKeys: String, CodingKey {
        case razorpayKeyId = "RAZORPAY_KEY_ID"
        case razorpayPlanIdMonthly = "RAZORPAY_PLAN_ID_MONTHLY"
        case razorpayPlanIdYearly = "RAZORPAY_PLAN_ID_YEARLY"
        case razorpayPlanIdDistributors = "RAZORPAY_PLAN_ID_DISTRIBUTORS"
    }
}

struct PricingResponse: Decodable {
    let success: Bool
    let pricing: PricingData?
}

struct PricingData: Decodable {
    let plans: PricingPlans?
}

struct PricingPlans: Decodable {
    let premium: PricingPlan?
    let distributors: PricingPlan?
}

struct PricingPlan: Decodable {
    let monthly: PricePoint?
    let yearly: PricePoint?
}

struct PricePoint: Decodable {
    let price: Int
    let currency: String?
}

// Matches Android CreateSubscriptionRequest — server expects planId + total_count
struct CreateSubscriptionRequest: Encodable {
    let planId: String
    let totalCount: Int
    let email: String?
    enum CodingKeys: String, CodingKey {
        case planId = "planId"
        case totalCount = "total_count"
        case email
    }
}

struct CreateSubscriptionResponse: Decodable {
    let success: Bool
    let subscriptionId: String?
    let orderId: String?
    let amount: Int?
    let currency: String?
    let resolvedKey: String

    enum CodingKeys: String, CodingKey {
        case success
        case subscriptionId = "subscription_id"
        case orderId = "order_id"
        case amount, currency
        case resolvedKey = "resolved_key"
    }
}

struct ExclusiveOrderRequest: Encodable {
    let amount: Int
    let currency: String
}

struct ExclusiveOrderResponse: Decodable {
    let success: Bool
    let orderId: String?
    let amount: Int?
    let currency: String?
    let resolvedKey: String

    enum CodingKeys: String, CodingKey {
        case success
        case orderId = "order_id"
        case amount, currency
        case resolvedKey = "resolved_key"
    }
}

struct VerifyPaymentRequest: Encodable {
    let razorpayOrderId: String
    let razorpayPaymentId: String
    let razorpaySignature: String
    let plan: String
    let amount: Int
    let currency: String

    enum CodingKeys: String, CodingKey {
        case razorpayOrderId = "razorpay_order_id"
        case razorpayPaymentId = "razorpay_payment_id"
        case razorpaySignature = "razorpay_signature"
        case plan, amount, currency
    }
}

struct VerifyPaymentResponse: Decodable {
    let success: Bool
    let message: String?
}
