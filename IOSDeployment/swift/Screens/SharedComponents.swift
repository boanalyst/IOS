// SharedComponents.swift
// Shared utility views used across multiple screens
// This file fixes FlockPostCard to use the correct FlockPost model fields
// (authorName / likeCount / replyCount instead of post.author.name / post.likes etc.)

import SwiftUI

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
        if phase != .empty { phase = .empty }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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

    var body: some View {
        ZStack {
            // 1. Black circle background fills the full frame
            Color.black

            // 2. Logo image centered and padded inside the circle
            CachedAsyncImage(url: URL(string: "https://boanalyst.com/Logo/download.jpeg")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(padding)
                case .failure:
                    // Fallback: gold "B" initial on dark background
                    Text("B")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(AppTheme.goldGradient)
                default:
                    // Loading state: subtle gold shimmer ring
                    Circle()
                        .stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1.5)
                        .padding(padding)
                }
            }
        }
        .frame(width: size, height: size)
        // 3. Clip the ENTIRE ZStack to a circle — this is the key:
        //    the black background + image are both cut together,
        //    giving a perfectly round avatar at any image aspect ratio.
        .clipShape(Circle())
        // Subtle gold ring border (same as Android's optional border)
        .overlay(Circle().stroke(AppTheme.goldPrimary.opacity(0.25), lineWidth: 1))
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
    var onTap: () -> Void = {}
    var onLike: () -> Void = {}
    var onComment: () -> Void = {}
    var onDelete: () -> Void = {}
    var onPin: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
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
                        Text(post.createdAt.prefix(10).description)
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
                let socialEmbeds = extractSocialEmbeds(from: post.content)
                let cleanContent = stripEmbedUrls(from: post.content, embeds: socialEmbeds)

                let attrString = parseBoAnalystHTML(cleanContent)
                Text(attrString)
                    .tint(AppTheme.goldPrimary)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(nil)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                // ── Uploaded Media ───────────────────────────────────────
                let mediaUrls = post.media.map { $0.url }
                if !mediaUrls.isEmpty {
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

                    Spacer()
                }
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Text("Add preview components here")
}

// MARK: - Global Content Parser (HTML to Markdown & AttributedString)
// Matches Android's buildHashtagAnnotatedString exact parsing tree
// DB stores bold as <b>...</b>, Android/Web use **...** markdown.
// This parser handles BOTH formats uniformly.

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

    // ── Step 6: Bullets (Android compatibility) ──
    clean = clean.replacingOccurrences(of: "(?m)^\\s*\\*\\*\\*(?!\\*)\\s+", with: "**• ", options: .regularExpression)
    clean = clean.replacingOccurrences(of: "(?m)^\\s*\\*(?!\\*)\\s+", with: "• ", options: .regularExpression)

    // ── Step 7: Fix bad bold markers ──
    // CRITICAL FIX: \s+ matches newlines in Swift regex! We must use [ \t]+ to only strip spaces
    clean = clean.replacingOccurrences(
        of: "\\*\\*[ \\t]+(.*?)[ \\t]+\\*\\*",
        with: "**$1**",
        options: .regularExpression
    )

    // ── NATIVE ANNOTATION PARSING ──
    // Completely bypasses Apple's buggy Markdown API and replicates Android's loop renderer 1:1.
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
    
    // Fallback if parsing completely stripped string visually
    if attrResult.characters.isEmpty {
        attrResult = AttributedString(clean.replacingOccurrences(of: "**", with: ""))
    }

    // ── Step 10: Apply HashTag Links Natively ──
    let plainText = String(attrResult.characters)
    if let regex = try? NSRegularExpression(pattern: "(#[\\p{L}\\p{N}_]+)") {
        let matches = regex.matches(in: plainText, range: NSRange(location: 0, length: plainText.utf16.count))
        for match in matches {
            if let strRange = Range(match.range, in: plainText) {
                // Safely translate String UTF-index bounds to AttributedString bounds
                let startOffset = plainText.distance(from: plainText.startIndex, to: strRange.lowerBound)
                let lengthOffset = plainText.distance(from: strRange.lowerBound, to: strRange.upperBound)
                
                let startIdx = attrResult.index(attrResult.startIndex, offsetByCharacters: startOffset)
                let endIdx = attrResult.index(startIdx, offsetByCharacters: lengthOffset)
                
                if startIdx < endIdx {
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

    var body: some View {
        if !urls.isEmpty {
            if urls.count == 1 {
                // Single large full-width image
                if let urlString = urls.first, let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://boanalyst.com/\(urlString.hasPrefix("/") ? String(urlString.dropFirst()) : urlString)") {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().fill(AppTheme.surfaceVariant)
                                .overlay(ProgressView().tint(AppTheme.goldPrimary))
                        case .success(let image):
                            image.resizable()
                                .scaledToFit()
                        case .failure:
                            Rectangle().fill(AppTheme.surfaceVariant)
                                .overlay(Image(systemName: "photo").foregroundColor(AppTheme.textMuted))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 4)
                }
            } else {
                // Grid of multiple images
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(urls, id: \.self) { urlString in
                            if let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://boanalyst.com/\(urlString.hasPrefix("/") ? String(urlString.dropFirst()) : urlString)") {
                                CachedAsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle().fill(AppTheme.surfaceVariant)
                                            .overlay(ProgressView().tint(AppTheme.goldPrimary))
                                    case .success(let image):
                                        image.resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure:
                                        Rectangle().fill(AppTheme.surfaceVariant)
                                            .overlay(Image(systemName: "photo").foregroundColor(AppTheme.textMuted))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(width: 220, height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
