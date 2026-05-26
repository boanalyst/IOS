// SharedComponents.swift
// Shared utility views used across multiple screens
// This file fixes FlockPostCard to use the correct FlockPost model fields
// (authorName / likeCount / replyCount instead of post.author.name / post.likes etc.)

import SwiftUI

// MARK: - Relative Date Formatter
// Converts ISO-8601 date strings to human-readable relative time
// e.g. "2 min ago", "3h ago", "Yesterday", "Apr 28"

fileprivate let iso8601Formatter1: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

fileprivate let iso8601Formatter2: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

fileprivate let fallbackDF1: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    return f
}()

fileprivate let fallbackDF2: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return f
}()

fileprivate let fallbackDF3: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()

// Static cached formatters for the display output — never instantiated per-call
fileprivate let timeOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"   // e.g. "3:45 PM"
    return f
}()

fileprivate let monthDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"    // e.g. "May 1"
    return f
}()

func formatRelativeDate(_ isoString: String) -> String {
    let trimmed = isoString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    // Try multiple statically cached parse formats
    var date = iso8601Formatter1.date(from: trimmed)
    if date == nil { date = iso8601Formatter2.date(from: trimmed) }
    if date == nil { date = fallbackDF1.date(from: trimmed) }
    if date == nil { date = fallbackDF2.date(from: trimmed) }
    if date == nil { date = fallbackDF3.date(from: trimmed) }

    guard let parsed = date else {
        return String(trimmed.prefix(10))  // fallback: raw date portion
    }

    let now = Date()
    let diff = now.timeIntervalSince(parsed)
    let calendar = Calendar.current

    // Under 1 minute
    if diff < 60 { return "Just now" }

    // Under 1 hour → "5 min ago"
    if diff < 3600 { return "\(Int(diff / 60)) min ago" }

    let timeStr = timeOnlyFormatter.string(from: parsed)

    // Same calendar day → "Today at 3:45 PM"
    if calendar.isDateInToday(parsed) {
        return "Today at \(timeStr)"
    }

    // Yesterday → "Yesterday at 3:45 PM"
    if calendar.isDateInYesterday(parsed) {
        return "Yesterday at \(timeStr)"
    }

    // Within the last 7 days → "May 1 at 3:45 PM"
    if diff < 604800 {
        return "\(monthDayFormatter.string(from: parsed)) at \(timeStr)"
    }

    // Older: check if same year
    let postYear = calendar.component(.year, from: parsed)
    let nowYear  = calendar.component(.year, from: now)
    if postYear == nowYear {
        // "May 1 at 3:45 PM"
        return "\(monthDayFormatter.string(from: parsed)) at \(timeStr)"
    }

    // Different year → "May 1, 2024 at 3:45 PM"
    let yearFormatter = DateFormatter()
    yearFormatter.dateFormat = "MMM d, yyyy"
    return "\(yearFormatter.string(from: parsed)) at \(timeStr)"
}

class ImageLoaderCache {
    static let shared = NSCache<NSURL, UIImage>()
}

enum CachedImagePhase {
    case empty
    case success(Image)
    case failure(Error)
}

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (CachedImagePhase) -> Content
    
    @State private var phase: CachedImagePhase = .empty
    
    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }
    
    private func load() async {
        guard let url = url else {
            phase = .failure(URLError(.badURL))
            return
        }
        if let cached = ImageLoaderCache.shared.object(forKey: url as NSURL) {
            phase = .success(Image(uiImage: cached))
            return
        }
        phase = .empty
        do {
            var request = URLRequest(url: url)
            // Attach authentication token for protected media routes (e.g. Inside Talk, Distributors)
            if let token = KeychainManager.shared.getToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                phase = .failure(URLError(.badServerResponse))
                return
            }
            
            if let uiImage = UIImage(data: data) {
                ImageLoaderCache.shared.setObject(uiImage, forKey: url as NSURL)
                phase = .success(Image(uiImage: uiImage))
            } else {
                phase = .failure(URLError(.cannotDecodeRawData))
            }
        } catch {
            phase = .failure(error)
        }
    }
}

// MARK: - BoAnalystAvatarView
// Canonical avatar component — mirrors Android's:
//   Box(modifier = Modifier.size(x).clip(CircleShape).background(Color.Black)) {
//     SubcomposeAsyncImage(contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize().padding(4.dp))
//   }
//
// KEY FIX: The ZStack with Color.black first, then the image inside, then
// .clipShape(Circle()) on the whole ZStack ensures the circle is always
// completely filled with black — the image scales to fit inside it with
// a small inset padding. This is what makes it look "round and perfect"
// (no white/transparent bars on the sides like .background() on the image does).

struct BoAnalystAvatarView: View {
    var size: CGFloat = 40
    var padding: CGFloat = 5

    private let logoUrl = URL(string: "https://boanalyst.com/Logo/download.jpeg")
    @State private var loadedImage: UIImage? = nil

    var body: some View {
        ZStack {
            // 1. Dark elegant background
            Color.black

            // 2. Resolve image
            if let uiImage = loadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding(padding)
            } else if let localImage = UIImage(named: "Logo") {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFit()
                    .padding(padding)
            } else {
                // Premium fallback placeholder: Gold text 'B' with subtle gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppTheme.goldPrimary.opacity(0.3),
                        AppTheme.goldSecondary.opacity(0.15)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Text("B")
                    .font(.system(size: size * 0.45, weight: .bold, design: .serif))
                    .foregroundColor(AppTheme.goldPrimary)
            }
        }
        .frame(width: size, height: size)
        // 3. Clip the ENTIRE ZStack to a circle — this is the key:
        //    the black background + image are both cut together,
        //    giving a perfectly round avatar at any image aspect ratio.
        .clipShape(Circle())
        // Subtle gold ring border (same as Android's optional border)
        .overlay(Circle().stroke(AppTheme.goldPrimary.opacity(0.25), lineWidth: 1))
        .onAppear {
            loadAvatar()
        }
    }

    private func loadAvatar() {
        if loadedImage != nil { return }
        if UIImage(named: "Logo") != nil { return }
        guard let url = logoUrl else { return }
        
        // Fast synchronous cache lookup
        if let cached = ImageLoaderCache.shared.object(forKey: url as NSURL) {
            self.loadedImage = cached
            return
        }

        // Asynchronous load in background
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    ImageLoaderCache.shared.setObject(uiImage, forKey: url as NSURL)
                    await MainActor.run {
                        withAnimation(.easeIn(duration: 0.2)) {
                            self.loadedImage = uiImage
                        }
                    }
                }
            } catch {
                // Fail silently, keep the premium placeholder
            }
        }
    }
}

// MARK: - FlockPostCard (canonical — used by FlockFeedView and HomeView)
// isLiked drives heart.fill / heart state.
// onLike and onComment are separated from onTap so gesture areas don't clash.
// isAdmin enables admin context menu (delete / pin) — Bug #1 fix.

struct FlockPostCard: View {
    let post: FlockPost
    let isAdmin: Bool
    var isLiked: Bool = false
    var isUnlocked: Bool = false
    var onTap: () -> Void = {}
    var onLike: () -> Void = {}
    var onComment: () -> Void = {}
    var onDelete: () -> Void = {}
    var onPin: () -> Void = {}
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Author header
            HStack(spacing: 10) {
                // BoAnalystAvatarView: perfectly circular avatar (fixes flat/broken look)
                BoAnalystAvatarView(size: 40, padding: 5)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(post.authorName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    Text(formatRelativeDate(post.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()

                // Right side: pin indicator + admin menu
                HStack(spacing: 8) {
                    if post.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.goldGradient)
                    }
                    // Bug #1 fix: admin sees a context menu button
                    if isAdmin {
                        Menu {
                            if let edit = onEdit {
                                Button(action: edit) {
                                    Label("Edit Post", systemImage: "pencil")
                                }
                            }
                            Button(role: .destructive) { onDelete() } label: {
                                Label("Delete Post", systemImage: "trash")
                            }
                            Button { onPin() } label: {
                                Label(post.isPinned ? "Unpin Post" : "Pin Post",
                                      systemImage: post.isPinned ? "pin.slash" : "pin")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.textMuted)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Content — extract social embeds first, strip their URLs from text
            let isRewardedContent = post.showRewarded || post.content.lowercased().contains("#boanalystexclusive")
            let shouldObscure = isRewardedContent && !isUnlocked
            let socialEmbeds = shouldObscure ? [] : extractSocialEmbeds(from: post.content)
            let rawCleanContent = stripEmbedUrls(from: post.content, embeds: socialEmbeds)
            
            let cleanContent: String = (shouldObscure && rawCleanContent.count > 15)
                ? String(rawCleanContent.prefix(15)) + "... See more"
                : rawCleanContent

            let attrString = ParsedTextCache.shared.parseFlock(cleanContent, id: post.id)
            Text(attrString)
                .tint(AppTheme.goldPrimary)
                .font(.system(size: 14))
                .foregroundColor(shouldObscure ? AppTheme.goldPrimary : AppTheme.textPrimary)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(nil)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

            // ── Uploaded Media ───────────────────────────────────────
            let mediaUrls = post.media.map { $0.resolvedUrl() }.filter { !$0.isEmpty }
            if !mediaUrls.isEmpty && !shouldObscure {
                PostMediaView(urls: mediaUrls)
            }

            // ── Social Embeds (YouTube / X / Instagram) ──────────────
            if !socialEmbeds.isEmpty {
                SocialEmbedsSection(embeds: socialEmbeds)
            }

            // Hashtags
            if !post.tags.isEmpty {
                Text(post.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.goldGradient)
                    .lineLimit(1)
            }

            // Engagement row — separate buttons to prevent tap bleeding into parent
            HStack(spacing: 16) {
                Button { onLike() } label: {
                    Label("\(post.likeCount)",
                          systemImage: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 12))
                        .foregroundColor(isLiked ? AppTheme.goldPrimary : AppTheme.textMuted)
                }
                .buttonStyle(.plain)

                Button { onComment() } label: {
                    Label("\(post.replyCount)", systemImage: "bubble.left")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)

                if let shareUrl = URL(string: "https://boanalyst.com/flock/post/\(post.id)") {
                    ShareLink(item: shareUrl) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .padding(16)
        .cardStyle()
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    Text("Add preview components here")
}

// MARK: - ParsedTextCache
// Central thread-safe MainActor caching mechanism for heavy HTML and Markdown text parsing.
// Eliminates repetitive regular expression parsing and AttributedString recreation on every scroll frame.
@MainActor
final class ParsedTextCache {
    static let shared = ParsedTextCache()
    private init() {}
    
    private var flockCache: [String: AttributedString] = [:]
    private var buzzCache: [String: AttributedString] = [:]
    
    func parseFlock(_ text: String, id: String) -> AttributedString {
        let key = "\(id)-\(text.hashValue)"
        if let cached = flockCache[key] {
            return cached
        }
        let parsed = parseBoAnalystHTML(text)
        flockCache[key] = parsed
        return parsed
    }
    
    func parseBuzz(_ text: String) -> AttributedString {
        let key = "\(text.hashValue)"
        if let cached = buzzCache[key] {
            return cached
        }
        let parsed = text.asBuzzAttributedString()
        buzzCache[key] = parsed
        return parsed
    }
    
    func clear() {
        flockCache.removeAll()
        buzzCache.removeAll()
    }
}

// MARK: - Global Content Parser (HTML to Markdown & AttributedString)
// Matches Android's buildHashtagAnnotatedString exact parsing tree
// DB stores bold as <b>...</b>, Android/Web use **...** markdown.
// This parser handles BOTH formats uniformly.

fileprivate let hashtagRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "(#[\\p{L}\\p{N}_]+)")

func parseBoAnalystHTML(_ text: String) -> AttributedString {
    // ── Step 1: Normalise line endings ───────────────────────────────────────
    var clean = text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")

    // ── Step 2: Convert standard tags to intermediate markers ──
    clean = clean.replacingOccurrences(of: "(?is)<b>(.*?)</b>", with: "**$1**", options: .regularExpression)
    clean = clean.replacingOccurrences(of: "(?is)<i>(.*?)</i>", with: "₩₩$1₩₩", options: .regularExpression)
    clean = clean.replacingOccurrences(of: "(?is)<u>(.*?)</u>", with: "§§$1§§", options: .regularExpression)

    // Android markdown compat
    clean = clean.replacingOccurrences(of: "__([^_]+)__", with: "§§$1§§", options: .regularExpression)
    clean = clean.replacingOccurrences(of: "_([^_]+)_", with: "₩₩$1₩₩", options: .regularExpression)

    // ── Step 3: Block HTML to newlines ──
    clean = clean.replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
    clean = clean.replacingOccurrences(of: "(?i)</?p>", with: "\n\n", options: .regularExpression)
    clean = clean.replacingOccurrences(of: "(?i)<li>", with: "\n• ", options: .regularExpression)

    // ── Step 4: Strip all remaining HTML tags ──
    clean = clean.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

    // ── Step 5: HTML Entities ──
    clean = clean.replacingOccurrences(of: "&nbsp;", with: " ")
                 .replacingOccurrences(of: "&amp;", with: "&")
                 .replacingOccurrences(of: "&lt;", with: "<")
                 .replacingOccurrences(of: "&gt;", with: ">")

    clean = clean.replacingOccurrences(of: "(?m)^\\s*\\*\\*\\*(?!\\*)\\s+", with: "**• ", options: .regularExpression)
    clean = clean.replacingOccurrences(of: "(?m)^\\s*\\*(?!\\*)\\s+", with: "• ", options: .regularExpression)
    clean = clean.replacingOccurrences(
        of: "\\*\\*[ \\t]+(.*?)[ \\t]+\\*\\*",
        with: "**$1**",
        options: .regularExpression
    )

    var attrResult = AttributedString()
    let boldParts = clean.components(separatedBy: "**")
    
    for (i, bPart) in boldParts.enumerated() {
        if bPart.isEmpty { continue }
        let isBold = (i % 2 == 1 && boldParts.count > 1)
        
        let italicParts = bPart.components(separatedBy: "₩₩")
        for (j, iPart) in italicParts.enumerated() {
            if iPart.isEmpty { continue }
            let isItalic = (j % 2 == 1 && italicParts.count > 1)
            
            let underParts = iPart.components(separatedBy: "§§")
            for (k, uPart) in underParts.enumerated() {
                if uPart.isEmpty { continue }
                let isUnder = (k % 2 == 1 && underParts.count > 1)
                
                var attrPart = AttributedString(uPart)
                
                var intent: InlinePresentationIntent = []
                if isBold { intent.insert(.stronglyEmphasized) }
                if isItalic { intent.insert(.emphasized) }
                
                if !intent.isEmpty {
                    attrPart.inlinePresentationIntent = intent
                }
                
                if isUnder {
                    attrPart.underlineStyle = Text.LineStyle(pattern: .solid)
                }
                
                attrResult.append(attrPart)
            }
        }
    }
    
    if attrResult.characters.isEmpty {
        attrResult = AttributedString(clean.replacingOccurrences(of: "**", with: ""))
    }

    if let regex = hashtagRegex {
        let plainText = String(attrResult.characters)
        let matches = regex.matches(in: plainText, range: NSRange(location: 0, length: plainText.utf16.count))
        for match in matches.reversed() {
            if let swiftRange = Range(match.range, in: plainText) {
                if let startIdx = AttributedString.Index(swiftRange.lowerBound, within: attrResult),
                   let endIdx = AttributedString.Index(swiftRange.upperBound, within: attrResult) {
                    attrResult[startIdx..<endIdx].link = URL(string: "boanalyst://hashtag")
                }
            }
        }
    }

    return attrResult
}

// MARK: - Backward-compatibility alias so HomeView's existing FlockPostCardFull calls compile
typealias FlockPostCardFull = FlockPostCard


// MARK: - InsideTalkCard with Correct Model Field
// InsideTalkContent uses `.content` not `.text`; this card is already correct
// in StubViews.swift but included here for reference.

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.goldGradient)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - Toast / Snackbar

struct ToastView: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? AppTheme.error : AppTheme.success)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Shimmer Loading Placeholder

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.surface, location: phase - 0.3),
                        .init(color: AppTheme.surfaceVariant, location: phase),
                        .init(color: AppTheme.surface, location: phase + 0.3),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

// MARK: - Skeleton Card

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .overlay(ShimmerView().clipShape(Circle()))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    ShimmerView()
                        .frame(width: 120, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    ShimmerView()
                        .frame(width: 80, height: 10)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            ShimmerView()
                .frame(maxWidth: .infinity)
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            ShimmerView()
                .frame(width: 200, height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Generic Media View Helper (Used by all feeds)

struct PostMediaView: View {
    let urls: [String]
    @State private var fullScreenIndex: Int? = nil

    var body: some View {
        if !urls.isEmpty {
            if urls.count == 1 {
                // Single image — stable aspect-ratio card to prevent dynamic layout jumps during scrolling
                if let urlString = urls.first, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().fill(AppTheme.surfaceVariant)
                                .overlay(ProgressView().tint(AppTheme.goldPrimary))
                        case .success(let image):
                            image.resizable()
                                .scaledToFill()
                        case .failure:
                            Rectangle().fill(AppTheme.surfaceVariant)
                                .overlay(Image(systemName: "photo").foregroundColor(AppTheme.textMuted))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 240)
                    .contentShape(Rectangle())
                    .onTapGesture { fullScreenIndex = 0 }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 4)
                }
            } else {
                // Horizontal scroll - fixed 240pt height cards, tappable
                VStack(spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(urls.indices, id: \.self) { i in
                                if let url = URL(string: urls[i]) {
                                    CachedAsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            Rectangle().fill(AppTheme.surfaceVariant)
                                                .overlay(ProgressView().tint(AppTheme.goldPrimary))
                                        case .success(let image):
                                            image.resizable()
                                                .scaledToFill()
                                        case .failure:
                                            Rectangle().fill(AppTheme.surfaceVariant)
                                                .overlay(Image(systemName: "photo").foregroundColor(AppTheme.textMuted))
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .frame(width: UIScreen.main.bounds.width * 0.82, height: 320)
                                    .contentShape(Rectangle())
                                    .onTapGesture { fullScreenIndex = i }
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    // Page indicator dots
                    HStack(spacing: 5) {
                        ForEach(urls.indices, id: \.self) { i in
                            Circle()
                                .fill(AppTheme.goldPrimary.opacity(i == 0 ? 1 : 0.3))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        // Full-screen lightbox
        if let idx = fullScreenIndex {
            Color.black.opacity(0.001)
                .fullScreenCover(isPresented: Binding(
                    get: { fullScreenIndex != nil },
                    set: { if !$0 { fullScreenIndex = nil } }
                )) {
                    MediaLightboxView(urls: urls, startIndex: idx)
                }
        }
    }
}

// MARK: - Full-Screen Lightbox
struct MediaLightboxView: View {
    let urls: [String]
    let startIndex: Int
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int

    init(urls: [String], startIndex: Int) {
        self.urls = urls
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $currentIndex) {
                ForEach(urls.indices, id: \.self) { i in
                    Group {
                        if let url = URL(string: urls[i]) {
                            CachedAsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                case .empty:
                                    ProgressView().tint(.white)
                                default:
                                    Image(systemName: "photo").foregroundColor(.gray).font(.largeTitle)
                                }
                            }
                        } else {
                            Image(systemName: "photo").foregroundColor(.gray).font(.largeTitle)
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}
