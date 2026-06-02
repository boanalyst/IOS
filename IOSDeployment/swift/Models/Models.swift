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
    
    enum CodingKeys: String, CodingKey {
        case success, message
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let b = try? c.decode(Bool.self, forKey: .success) { success = b }
        else if let i = try? c.decode(Int.self, forKey: .success) { success = (i != 0) }
        else { success = false }
        message = try? c.decode(String.self, forKey: .message)
    }
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
    let showInterstitial: Bool
    let showRewarded: Bool
    let createdAt: String
    let poll: Poll?

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
        case showInterstitial = "show_interstitial"
        case showRewarded = "show_rewarded"
        case createdAt = "created_at"
        case poll
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
        if let arr = try? c.decode([FlockMedia].self, forKey: .media) {
            media = arr
        } else if let raw = try? c.decode(String.self, forKey: .media),
                  let data = raw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([FlockMedia].self, from: data) {
            media = arr
        } else {
            media = []
        }
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
        showInterstitial = decodeBool(.showInterstitial)
        showRewarded = decodeBool(.showRewarded)
        poll = try? c.decode(Poll.self, forKey: .poll)
    }

    // Memberwise copy initializer for optimistic UI mutations
    init(from existing: FlockPost, likeCount: Int? = nil, replyCount: Int? = nil, userLiked: Bool? = nil, isPinned: Bool? = nil, poll: Poll? = nil) {
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
        self.showInterstitial = existing.showInterstitial
        self.showRewarded = existing.showRewarded
        self.createdAt    = existing.createdAt
        self.poll         = poll ?? existing.poll
    }
}

struct FlockMedia: Decodable {
    let url: String
    let type: String
    enum CodingKeys: String, CodingKey {
        case url = "media_url"
        case type = "media_type"
    }

    func resolvedUrl() -> String {
        guard !url.isEmpty else { return "" }
        if url.hasPrefix("http") {
            if URL(string: url) == nil {
                return url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
            }
            return url
        } else {
            let safePath = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
            return "https://boanalyst.com" + (safePath.hasPrefix("/") ? safePath : "/" + safePath)
        }
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
    let replies: [Comment]?
    var resolvedComments: [Comment] { comments ?? data ?? replies ?? [] }
    
    enum CodingKeys: String, CodingKey {
        case success, comments, data, replies
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let b = try? c.decode(Bool.self, forKey: .success) { success = b }
        else if let i = try? c.decode(Int.self, forKey: .success) { success = (i != 0) }
        else { success = false }
        comments = try? c.decode([Comment].self, forKey: .comments)
        data = try? c.decode([Comment].self, forKey: .data)
        replies = try? c.decode([Comment].self, forKey: .replies)
    }
}

struct Comment: Decodable, Identifiable {
    let id: String
    let content: String
    let authorName: String
    let userId: String?        // author's user id — used for delete permission check
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case id2 = "id"
        case content
        case authorName = "author_name"
        case userId = "author_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? (try? c.decode(String.self, forKey: .id2)) ?? UUID().uuidString
        self.content = (try? c.decode(String.self, forKey: .content)) ?? ""
        self.authorName = (try? c.decode(String.self, forKey: .authorName)) ?? "User"
        self.userId = try? c.decode(String.self, forKey: .userId)
        self.createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
    }
}

struct AddCommentResponse: Decodable {
    let success: Bool
    let comment: Comment?
    let data: Comment?
    var resolvedComment: Comment? { comment ?? data }
    
    enum CodingKeys: String, CodingKey {
        case success, comment, data
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let b = try? c.decode(Bool.self, forKey: .success) { success = b }
        else if let i = try? c.decode(Int.self, forKey: .success) { success = (i != 0) }
        else { success = false }
        comment = try? c.decode(Comment.self, forKey: .comment)
        data = try? c.decode(Comment.self, forKey: .data)
    }
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
        case posterPath  = "posterPath"
        case posterPathSnake = "poster_path"
        case releaseDate = "releaseDate"
        case releaseDateSnake = "release_date"
        case overview, synopsis, link, rating
        case platform, genre, language
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title       = (try? c.decode(String.self, forKey: .title)) ?? ""
        posterPath  = (try? c.decode(String.self, forKey: .posterPath)) 
                   ?? (try? c.decode(String.self, forKey: .posterPathSnake))
        releaseDate = (try? c.decode(String.self, forKey: .releaseDate)) 
                   ?? (try? c.decode(String.self, forKey: .releaseDateSnake))
        overview    = (try? c.decode(String.self, forKey: .overview))
                   ?? (try? c.decode(String.self, forKey: .synopsis))
        link        = try? c.decode(String.self, forKey: .link)
        rating      = try? c.decode(Double.self, forKey: .rating)
        // Synthesise a stable id from title + releaseDate
        id = "\(title)-\(releaseDate ?? "")"
    }
}

extension Movie {
    var resolvedPosterUrl: URL? {
        guard let path = posterPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return nil
        }
        let urlStr: String
        if path.hasPrefix("http") || path.hasPrefix("https") {
            urlStr = path.replacingOccurrences(of: "http://", with: "https://")
        } else if path.hasPrefix("/") {
            urlStr = "https://boanalyst.com\(path)"
        } else {
            urlStr = "https://boanalyst.com/uploads/movies/\(path)"
        }
        return URL(string: urlStr)
    }
}

struct BoxOfficeResponse: Decodable {
    let success: Bool
    let language: String?
    let movies: [BoxOfficeEntry]?
    var data: [BoxOfficeEntry] { movies ?? [] }
}

struct BoxOfficeEntry: Decodable, Identifiable {
    let id: Int
    let title: String
    let language: String
    let worldwideGross: String
    let indiaGross: String
    let overseasGross: String
    let rankNum: Int
    let releaseYear: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, language
        case worldwideGross = "worldwide_gross"
        case indiaGross = "india_gross"
        case overseasGross = "overseas_gross"
        case rankNum = "rank_num"
        case releaseYear = "release_year"
    }
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
    let userVotedOptionId: String?
    let hasEnded: Bool?
    let allowMultiple: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case id2 = "id"
        case question, options
        case totalVotes = "total_votes"
        case totalVotes2 = "totalVotes"
        case endsAt = "ends_at"
        case endsAt2 = "endsAt"
        case userVotedOptionId = "user_voted_option_id"
        case userVotedOptionId2 = "userVotedOptionId"
        case hasEnded = "has_ended"
        case hasEnded2 = "hasEnded"
        case allowMultiple = "allow_multiple"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? (try? c.decode(String.self, forKey: .id2)) ?? UUID().uuidString
        question = (try? c.decode(String.self, forKey: .question)) ?? ""
        options = (try? c.decode([PollOption].self, forKey: .options)) ?? []
        totalVotes = (try? c.decode(Int.self, forKey: .totalVotes)) ?? (try? c.decode(Int.self, forKey: .totalVotes2)) ?? 0
        endsAt = (try? c.decode(String.self, forKey: .endsAt)) ?? (try? c.decode(String.self, forKey: .endsAt2))
        
        // userVotedOptionId might be String or Int
        if let s = try? c.decode(String.self, forKey: .userVotedOptionId) { userVotedOptionId = s }
        else if let s = try? c.decode(String.self, forKey: .userVotedOptionId2) { userVotedOptionId = s }
        else if let i = try? c.decode(Int.self, forKey: .userVotedOptionId) { userVotedOptionId = String(i) }
        else if let i = try? c.decode(Int.self, forKey: .userVotedOptionId2) { userVotedOptionId = String(i) }
        else { userVotedOptionId = nil }
        
        hasEnded = (try? c.decode(Bool.self, forKey: .hasEnded)) ?? (try? c.decode(Bool.self, forKey: .hasEnded2)) ?? false
        allowMultiple = try? c.decode(Int.self, forKey: .allowMultiple)
    }
}

struct PollOption: Decodable, Identifiable {
    let id: String
    let text: String
    let votes: Int
    let percentage: Float?
    
    enum CodingKeys: String, CodingKey {
        case id
        case id2 = "_id"
        case text
        case optionText = "option_text"
        case votes
        case voteCount = "vote_count"
        case percentage
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) { id = s }
        else if let s = try? c.decode(String.self, forKey: .id2) { id = s }
        else if let i = try? c.decode(Int.self, forKey: .id) { id = String(i) }
        else { id = UUID().uuidString }
        
        text = (try? c.decode(String.self, forKey: .text)) ?? (try? c.decode(String.self, forKey: .optionText)) ?? ""
        votes = (try? c.decode(Int.self, forKey: .votes)) ?? (try? c.decode(Int.self, forKey: .voteCount)) ?? 0
        percentage = try? c.decode(Float.self, forKey: .percentage)
    }
}

struct VoteRequest: Encodable {
    let optionId: String
    let pollId: String
    
    enum CodingKeys: String, CodingKey {
        case optionId = "option_id"
        case pollId = "poll_id"
    }
}

struct PollVoteResponse: Decodable {
    let success: Bool
    let poll: Poll?
    let error: String?
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
    let showRewarded: Bool
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
        case showRewarded = "show_rewarded"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) 
               ?? (try? c.decode(String.self, forKey: .mongoId)) 
               ?? UUID().uuidString
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        authorName = (try? c.decode(String.self, forKey: .authorName)) ?? "BoAnalyst"
        // media may arrive as a native JSON array (correct) OR as a JSON-string
        // (MySQL stored it via JSON.stringify — backend fix applied but keep
        // this fallback for cached / old records in the wild).
        if let arr = try? c.decode([InsideTalkMedia].self, forKey: .media) {
            media = arr
        } else if let raw = try? c.decode(String.self, forKey: .media),
                  let data = raw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([InsideTalkMedia].self, from: data) {
            media = arr
        } else {
            media = []
        }
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
        showRewarded = decodeBool(.showRewarded)
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
        self.showRewarded = existing.showRewarded
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
        if raw.hasPrefix("http") {
            // Already full URL. Add encoding if Swift URL parser fails
            if URL(string: raw) == nil {
                return raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
            }
            return raw
        } else {
            // Encode the path segment properly (avoid encoding / characters but encode spaces)
            let safePath = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
            return "https://boanalyst.com" + safePath
        }
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
        case mongoId = "_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Accept both "id" and "_id" to be safe
        self.id = (try? container.decode(String.self, forKey: .id)) 
               ?? (try? container.decode(String.self, forKey: .mongoId)) 
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
        case id2 = "id"
        case content
        case authorName = "author_name"
        case userId = "author_id"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? (try? c.decode(String.self, forKey: .id2)) ?? UUID().uuidString
        self.content = (try? c.decode(String.self, forKey: .content)) ?? ""
        self.authorName = (try? c.decode(String.self, forKey: .authorName)) ?? "User"
        self.userId = try? c.decode(String.self, forKey: .userId)
        self.createdAt = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
    }
}

struct InsideTalkRepliesResponse: Decodable {
    let success: Bool
    let replies: [InsideTalkReply]?
    let data: [InsideTalkReply]?
    var resolvedReplies: [InsideTalkReply] { replies ?? data ?? [] }

    enum CodingKeys: String, CodingKey {
        case success, replies, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let b = try? c.decode(Bool.self, forKey: .success) { success = b }
        else if let i = try? c.decode(Int.self, forKey: .success) { success = (i != 0) }
        else { success = false }
        replies = try? c.decode([InsideTalkReply].self, forKey: .replies)
        data = try? c.decode([InsideTalkReply].self, forKey: .data)
    }
}

struct InsideTalkReplyResponse: Decodable {
    let success: Bool
    let reply: InsideTalkReply?
    let data: InsideTalkReply?
    var resolvedReply: InsideTalkReply? { reply ?? data }

    enum CodingKeys: String, CodingKey {
        case success, reply, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let b = try? c.decode(Bool.self, forKey: .success) { success = b }
        else if let i = try? c.decode(Int.self, forKey: .success) { success = (i != 0) }
        else { success = false }
        reply = try? c.decode(InsideTalkReply.self, forKey: .reply)
        data = try? c.decode(InsideTalkReply.self, forKey: .data)
    }
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
        case id2 = "id"
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
        id = (try? c.decode(String.self, forKey: .id)) ?? (try? c.decode(String.self, forKey: .id2)) ?? UUID().uuidString
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

// MARK: - Buzz Board

enum BuzzCategory: String, CaseIterable, Identifiable {
    case all       = "all"
    case movies    = "movies"
    case boxOffice = "box_office"
    case rumors    = "rumors"
    case reviews   = "reviews"
    case general   = "general"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .all:       return "All"
        case .movies:    return "Movies"
        case .boxOffice: return "Box Office"
        case .rumors:    return "Rumors"
        case .reviews:   return "Reviews"
        case .general:   return "General"
        }
    }
    var icon: String {
        switch self {
        case .all:       return "square.grid.2x2.fill"
        case .movies:    return "film"
        case .boxOffice: return "chart.bar.fill"
        case .rumors:    return "megaphone.fill"
        case .reviews:   return "star.fill"
        case .general:   return "bubble.left.fill"
        }
    }
}


struct BuzzPost: Decodable, Identifiable {
    let id: String
    let userId: String
    let authorName: String
    let category: String
    let title: String
    let content: String
    let tags: [String]
    let media: [BuzzMedia]
    let likeCount: Int
    let commentCount: Int
    let viewCount: Int
    let isPinned: Bool
    var userLiked: Bool
    let showInterstitial: Bool
    let showRewarded: Bool
    let createdAt: String

    var buzzCategory: BuzzCategory { BuzzCategory(rawValue: category) ?? .general }

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case authorName  = "author_name"
        case category
        case title, content
        case tags
        case media
        case likeCount   = "like_count"
        case commentCount = "comment_count"
        case viewCount   = "view_count"
        case isPinned    = "is_pinned"
        case userLiked   = "user_liked"
        case showInterstitial = "show_interstitial"
        case showRewarded = "show_rewarded"
        case createdAt   = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        userId      = (try? c.decode(String.self, forKey: .userId)) ?? ""
        authorName  = (try? c.decode(String.self, forKey: .authorName)) ?? "User"
        category    = (try? c.decode(String.self, forKey: .category)) ?? "general"
        title       = ((try? c.decode(String.self, forKey: .title)) ?? "").replacingOccurrences(of: "\u{FFFC}", with: "").replacingOccurrences(of: "\u{FFFD}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        content     = ((try? c.decode(String.self, forKey: .content)) ?? "").replacingOccurrences(of: "\u{FFFC}", with: "").replacingOccurrences(of: "\u{FFFD}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Tags may be a JSON array or a JSON-string
        if let arr = try? c.decode([String].self, forKey: .tags) {
            tags = arr
        } else if let raw = try? c.decode(String.self, forKey: .tags),
                  let data = raw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) {
            tags = arr
        } else {
            tags = []
        }
        // Media may be a JSON array or a JSON-string
        if let arr = try? c.decode([BuzzMedia].self, forKey: .media) {
            media = arr
        } else if let raw = try? c.decode(String.self, forKey: .media),
                  let data = raw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([BuzzMedia].self, from: data) {
            media = arr
        } else {
            media = []
        }
        likeCount    = (try? c.decode(Int.self, forKey: .likeCount))    ?? 0
        commentCount = (try? c.decode(Int.self, forKey: .commentCount)) ?? 0
        viewCount    = (try? c.decode(Int.self, forKey: .viewCount))    ?? 0
        createdAt    = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        func decodeBool(_ key: CodingKeys) -> Bool {
            if let b = try? c.decode(Bool.self, forKey: key) { return b }
            if let i = try? c.decode(Int.self, forKey: key) { return i != 0 }
            return false
        }
        isPinned  = decodeBool(.isPinned)
        userLiked = decodeBool(.userLiked)
        showInterstitial = decodeBool(.showInterstitial)
        showRewarded = decodeBool(.showRewarded)
    }

    // Copy initializer for optimistic updates
    init(from existing: BuzzPost, likeCount: Int? = nil, commentCount: Int? = nil, userLiked: Bool? = nil) {
        self.id           = existing.id
        self.userId       = existing.userId
        self.authorName   = existing.authorName
        self.category     = existing.category
        self.title        = existing.title
        self.content      = existing.content
        self.tags         = existing.tags
        self.media        = existing.media
        self.likeCount    = likeCount    ?? existing.likeCount
        self.commentCount = commentCount ?? existing.commentCount
        self.viewCount    = existing.viewCount
        self.isPinned     = existing.isPinned
        self.userLiked    = userLiked    ?? existing.userLiked
        self.showInterstitial = existing.showInterstitial
        self.showRewarded = existing.showRewarded
        self.createdAt    = existing.createdAt
    }

    func resolvedMediaUrls() -> [String] {
        return media.map { m in
            let path = m.url
            if path.hasPrefix("http") {
                return path
            } else {
                let safePath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
                return APIConfig.baseURL + (safePath.hasPrefix("/") ? safePath : "/" + safePath)
            }
        }
    }
}

struct BuzzMedia: Decodable {
    let url: String
    let type: String?
}

struct BuzzPostsResponse: Decodable {
    let success: Bool
    let posts: [BuzzPost]
    let total: Int?
    let hasMore: Bool?
    enum CodingKeys: String, CodingKey {
        case success, posts, total
        case hasMore = "hasMore"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decode(Bool.self, forKey: .success)) ?? false
        posts   = (try? c.decode([BuzzPost].self, forKey: .posts)) ?? []
        total   = try? c.decode(Int.self, forKey: .total)
        if let b = try? c.decode(Bool.self, forKey: .hasMore) { hasMore = b }
        else if let i = try? c.decode(Int.self, forKey: .hasMore) { hasMore = (i != 0) }
        else { hasMore = nil }
    }
}

struct BuzzComment: Decodable, Identifiable {
    let id: String
    let postId: String
    let userId: String
    let authorName: String
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case postId     = "post_id"
        case userId     = "user_id"
        case authorName = "author_name"
        case content
        case createdAt  = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = (try? c.decode(String.self, forKey: .id))         ?? UUID().uuidString
        postId     = (try? c.decode(String.self, forKey: .postId))     ?? ""
        userId     = (try? c.decode(String.self, forKey: .userId))     ?? ""
        authorName = (try? c.decode(String.self, forKey: .authorName)) ?? "User"
        content    = ((try? c.decode(String.self, forKey: .content)) ?? "").replacingOccurrences(of: "\u{FFFC}", with: "").replacingOccurrences(of: "\u{FFFD}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        createdAt  = (try? c.decode(String.self, forKey: .createdAt))  ?? ""
    }
}

struct BuzzCommentsResponse: Decodable {
    let success: Bool
    let comments: [BuzzComment]
    enum CodingKeys: String, CodingKey { case success, comments }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success  = (try? c.decode(Bool.self, forKey: .success)) ?? false
        comments = (try? c.decode([BuzzComment].self, forKey: .comments)) ?? []
    }
}

struct BuzzToggleLikeResponse: Decodable {
    let success: Bool
    let liked: Bool?
    let action: String?
    enum CodingKeys: String, CodingKey { case success, liked, action }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decode(Bool.self, forKey: .success)) ?? false
        if let b = try? c.decode(Bool.self, forKey: .liked) { liked = b }
        else if let i = try? c.decode(Int.self, forKey: .liked) { liked = (i != 0) }
        else { liked = nil }
        action = try? c.decode(String.self, forKey: .action)
    }
}

struct BuzzCreatePostResponse: Decodable {
    let success: Bool
    let post: BuzzPost?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success, post, data, message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decode(Bool.self, forKey: .success)) ?? false
        message = try? c.decode(String.self, forKey: .message)
        // Server returns created post under "data", not "post"
        post = (try? c.decode(BuzzPost.self, forKey: .data))
            ?? (try? c.decode(BuzzPost.self, forKey: .post))
    }
}


struct BuzzAddCommentResponse: Decodable {
    let success: Bool
    let comment: BuzzComment?
    let message: String?
}

struct AdConfigResponse: Decodable, Sendable {
    let success: Bool
    let enabled: Bool
    let appOpenEnabled: Bool
    let nativeAdvancedEnabled: Bool
    let adInterval: Int
    let cooldownHours: Double
    let adUnits: AdUnitsConfig?

    enum CodingKeys: String, CodingKey {
        case success, enabled
        case appOpenEnabled = "appOpenEnabled"
        case nativeAdvancedEnabled = "nativeAdvancedEnabled"
        case adInterval = "adInterval"
        case cooldownHours = "cooldownHours"
        case adUnits = "adUnits"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decode(Bool.self, forKey: .success)) ?? false
        enabled = (try? c.decode(Bool.self, forKey: .enabled)) ?? true
        appOpenEnabled = (try? c.decode(Bool.self, forKey: .appOpenEnabled)) ?? false
        nativeAdvancedEnabled = (try? c.decode(Bool.self, forKey: .nativeAdvancedEnabled)) ?? false
        adInterval = (try? c.decode(Int.self, forKey: .adInterval)) ?? 5
        cooldownHours = (try? c.decode(Double.self, forKey: .cooldownHours)) ?? 4.0
        adUnits = try? c.decode(AdUnitsConfig.self, forKey: .adUnits)
    }
}

struct AdUnitsConfig: Decodable, Sendable {
    let android: PlatformAdUnits?
    let ios: PlatformAdUnits?
}

struct PlatformAdUnits: Decodable, Sendable {
    let appOpen: String?
    let nativeAdvanced: String?
}

// MARK: - Tech Deals

struct TechDealCategory: Decodable, Identifiable {
    let id: String
    let name: String
}

struct TechDealsResponse: Decodable {
    let success: Bool
    let deals: [TechDeal]?
    let hasMore: Bool?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, deals, error
        case hasMore = "has_more"
    }
}

struct TechDeal: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let originalPrice: Double?
    let dealPrice: Double
    let discountPercentage: Int?
    let affiliateUrl: String
    let imageUrl: String?
    let platform: String
    let category: String
    let isFeatured: Bool
    let isActive: Bool
    let expiresAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, platform, category
        case originalPrice = "original_price"
        case dealPrice = "deal_price"
        case discountPercentage = "discount_percentage"
        case affiliateUrl = "affiliate_url"
        case imageUrl = "image_url"
        case isFeatured = "is_featured"
        case isActive = "is_active"
        case expiresAt = "expires_at"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = try? c.decode(String.self, forKey: .description)
        
        // Handle prices coming as numbers or strings from JSON/MySQL
        if let orig = try? c.decode(Double.self, forKey: .originalPrice) { originalPrice = orig }
        else if let origStr = try? c.decode(String.self, forKey: .originalPrice), let parsed = Double(origStr) { originalPrice = parsed }
        else { originalPrice = nil }
        
        if let deal = try? c.decode(Double.self, forKey: .dealPrice) { dealPrice = deal }
        else if let dealStr = try? c.decode(String.self, forKey: .dealPrice), let parsed = Double(dealStr) { dealPrice = parsed }
        else { dealPrice = 0.0 }
        
        if let disc = try? c.decode(Int.self, forKey: .discountPercentage) { discountPercentage = disc }
        else if let discStr = try? c.decode(String.self, forKey: .discountPercentage), let parsed = Int(discStr) { discountPercentage = parsed }
        else { discountPercentage = nil }
        
        affiliateUrl = (try? c.decode(String.self, forKey: .affiliateUrl)) ?? ""
        imageUrl = try? c.decode(String.self, forKey: .imageUrl)
        platform = (try? c.decode(String.self, forKey: .platform)) ?? "amazon"
        category = (try? c.decode(String.self, forKey: .category)) ?? "general"
        
        // Handle TINYINT booleans
        func decodeBool(_ key: CodingKeys) -> Bool {
            if let b = try? c.decode(Bool.self, forKey: key) { return b }
            if let i = try? c.decode(Int.self, forKey: key) { return i != 0 }
            return false
        }
        
        isFeatured = decodeBool(.isFeatured)
        isActive = decodeBool(.isActive)
        expiresAt = try? c.decode(String.self, forKey: .expiresAt)
    }
}
