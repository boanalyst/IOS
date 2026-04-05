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
}

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
        subscriptionPlan == "premium-monthly" ||
        subscriptionPlan == "premium-yearly" ||
        subscriptionPlan?.contains("premium") == true ||
        subscriptionPlan?.contains("pro") == true
    }

    var isDistributor: Bool {
        isAdmin || subscriptionPlan == "distributors-hub"
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email, role
        case subscriptionPlan = "subscriptionPlan"
        case _isAdmin = "isAdmin"
        case avatarUrl = "avatar_url"
        case createdAt = "createdAt"
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
        case id = "_id"
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

    // Custom decoder to handle MySQL TINYINT(1) for isPinned + userLiked
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        content = try c.decode(String.self, forKey: .content)
        authorName = (try? c.decode(String.self, forKey: .authorName)) ?? ""
        authorHandle = try? c.decode(String.self, forKey: .authorHandle)
        authorId = try? c.decode(String.self, forKey: .authorId)
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        media = (try? c.decode([FlockMedia].self, forKey: .media)) ?? []
        likeCount = (try? c.decode(Int.self, forKey: .likeCount)) ?? 0
        replyCount = (try? c.decode(Int.self, forKey: .replyCount)) ?? 0
        createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        func decodeBool(_ key: CodingKeys) -> Bool {
            if let b = try? c.decode(Bool.self, forKey: key) { return b }
            if let i = try? c.decode(Int.self, forKey: key) { return i != 0 }
            return false
        }
        isPinned  = decodeBool(.isPinned)
        userLiked = decodeBool(.userLiked)
    }

    // Memberwise copy initializer for optimistic UI mutations
    init(from existing: FlockPost, likeCount: Int? = nil, replyCount: Int? = nil, userLiked: Bool? = nil) {
        self.id          = existing.id
        self.content     = existing.content
        self.authorName  = existing.authorName
        self.authorHandle = existing.authorHandle
        self.authorId    = existing.authorId
        self.tags        = existing.tags
        self.media       = existing.media
        self.likeCount   = likeCount  ?? existing.likeCount
        self.replyCount  = replyCount ?? existing.replyCount
        self.isPinned    = existing.isPinned
        self.userLiked   = userLiked  ?? existing.userLiked
        self.createdAt   = existing.createdAt
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
    let comments: [Comment]
    var resolvedComments: [Comment] { comments }
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
    var resolvedComment: Comment? { comment }
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

struct Movie: Decodable, Identifiable {
    let id: String
    let title: String
    let posterPath: String?
    let releaseDate: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case overview
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
        case id = "_id"
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
        id = try c.decode(String.self, forKey: .id)
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
         replyCount: Int? = nil) {
        self.id          = existing.id
        self.content     = existing.content
        self.authorName  = existing.authorName
        self.media       = existing.media
        self.likeCount   = likeCount   ?? existing.likeCount
        self.dislikeCount = existing.dislikeCount
        self.replyCount  = replyCount  ?? existing.replyCount
        self.isPinned    = existing.isPinned
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

struct ExclusiveContent: Decodable {
    let id: String
    let title: String
    let description: String
    let price: Double
    let currency: String?
    let mediaUrls: [String]?
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title, description, price, currency
        case mediaUrls = "media_urls"
        case createdAt = "created_at"
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
    let replies: [InsideTalkReply]
    var resolvedReplies: [InsideTalkReply] { replies }
}

struct InsideTalkReplyResponse: Decodable {
    let success: Bool
    let reply: InsideTalkReply?
    var resolvedReply: InsideTalkReply? { reply }
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
