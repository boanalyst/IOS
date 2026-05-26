// SocialEmbedView.swift
// iOS port of Android's SocialEmbedView.kt
// Parses X/Twitter, YouTube, Instagram URLs from post content and renders
// them as rich inline media cards — matching the Android experience exactly.

import SwiftUI
import WebKit
import SafariServices

// MARK: - Data Model

struct SocialEmbed: Identifiable {
    enum EmbedType { case twitter, youtube, instagram }
    let id: String       // tweet id / youtube video id / instagram shortcode
    let originalUrl: String
    let type: EmbedType
}

// MARK: - URL Extraction (matches Android extractSocialEmbeds exactly)

func extractSocialEmbeds(from text: String) -> [SocialEmbed] {
    var results: [SocialEmbed] = []
    guard let urlPattern = try? NSRegularExpression(pattern: #"https?://\S+"#) else { return [] }
    let nsText = text as NSString
    let matches = urlPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))

    for m in matches {
        var raw = nsText.substring(with: m.range)
        // Trim trailing punctuation (mirrors Android)
        while let last = raw.last, ".,)>]".contains(last) { raw.removeLast() }
        if !raw.isEmpty, let embed = parseSocialEmbed(url: raw) {
            results.append(embed)
        }
    }
    return results
}

private func parseSocialEmbed(url: String) -> SocialEmbed? {
    let nsUrl = url as NSString
    let fullRange = NSRange(location: 0, length: nsUrl.length)

    // ── Twitter / X ──────────────────────────────────────────────────────
    if let pat = try? NSRegularExpression(
        pattern: #"(?:https?://)?(?:www\.)?(?:twitter\.com|x\.com)/(\w+)/status/(\d+)"#,
        options: .caseInsensitive
    ), let m = pat.firstMatch(in: url, range: fullRange) {
        let userRange = m.range(at: 1)
        let idRange = m.range(at: 2)
        if userRange.location != NSNotFound, let swiftUserRange = Range(userRange, in: url),
           idRange.location != NSNotFound, let swiftIdRange = Range(idRange, in: url) {
            let username = String(url[swiftUserRange])
            let tweetId = String(url[swiftIdRange])
            return SocialEmbed(id: "\(username)|\(tweetId)", originalUrl: url, type: .twitter)
        }
    }

    // ── YouTube ──────────────────────────────────────────────────────────
    if let pat = try? NSRegularExpression(
        pattern: #"(?:https?://)?(?:www\.)?(?:youtube\.com/(?:watch\?(?:[^&\s]*&)*v=|shorts/|embed/)|youtu\.be/)([A-Za-z0-9_-]{11})"#,
        options: .caseInsensitive
    ), let m = pat.firstMatch(in: url, range: fullRange) {
        let r = m.range(at: 1)
        if r.location != NSNotFound, let swiftRange = Range(r, in: url) {
            return SocialEmbed(id: String(url[swiftRange]), originalUrl: url, type: .youtube)
        }
    }

    // ── Instagram ────────────────────────────────────────────────────────
    if let pat = try? NSRegularExpression(
        pattern: #"(?:https?://)?(?:www\.)?instagram\.com/(?:reel|p|tv)/([A-Za-z0-9_-]+)/?"#,
        options: .caseInsensitive
    ), let m = pat.firstMatch(in: url, range: fullRange) {
        let r = m.range(at: 1)
        if r.location != NSNotFound, let swiftRange = Range(r, in: url) {
            return SocialEmbed(id: String(url[swiftRange]), originalUrl: url, type: .instagram)
        }
    }

    return nil
}

// MARK: - Strip embed URLs from text (so they don't appear as raw links)

func stripEmbedUrls(from text: String, embeds: [SocialEmbed]) -> String {
    var result = text
    for embed in embeds {
        result = result.replacingOccurrences(of: embed.originalUrl, with: "")
    }
    // Collapse repeated blank lines
    while result.contains("\n\n\n") {
        result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Social Embeds Section (main entry point for post cards)

struct SocialEmbedsSection: View {
    let embeds: [SocialEmbed]

    var body: some View {
        if !embeds.isEmpty {
            VStack(spacing: 8) {
                ForEach(embeds) { embed in
                    SocialEmbedCard(embed: embed)
                }
            }
        }
    }
}

// MARK: - Individual embed card dispatcher
// NOTE: Must use AnyView in switch because each branch returns a distinct concrete type.

private struct SocialEmbedCard: View {
    let embed: SocialEmbed

    var body: some View {
        Group {
            if embed.type == .youtube {
                YouTubeThumbnailCard(videoId: embed.id, originalUrl: embed.originalUrl)
            } else if embed.type == .twitter {
                XEmbedWebView(tweetId: embed.id)
            } else {
                InstagramEmbedWebView(postUrl: embed.originalUrl)
            }
        }
    }
}

// MARK: - YouTube Thumbnail Card (native — no WKWebView needed)
// Tapping opens m.youtube.com inside SFSafariViewController for full playback.

private struct YouTubeThumbnailCard: View {
    let videoId: String
    let originalUrl: String
    @State private var showSafari = false

    private var thumbnailURL: URL? {
        URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")
    }

    private var playbackURL: URL? {
        URL(string: "https://m.youtube.com/watch?v=\(videoId)")
    }

    var body: some View {
        ZStack {
            // Thumbnail
            CachedAsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(16 / 9, contentMode: .fill)
                default:
                    Rectangle().fill(Color.black.opacity(0.7))
                }
            }
            .clipped()

            // Subtle dark scrim so the play button always reads clearly
            Color.black.opacity(0.22)

            // Red YouTube play button circle
            Circle()
                .fill(Color(red: 1, green: 0, blue: 0))
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .offset(x: 2)
                )

            // "▶ YouTube" badge — bottom-right
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    Text("▶  YouTube")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(8)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture { showSafari = true }
        .sheet(isPresented: $showSafari) {
            if let url = playbackURL {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }
}

// MARK: - X / Twitter Embed using WKWebView

private struct XEmbedWebView: View {
    let tweetId: String

    var body: some View {
        TwitterWebView(tweetId: tweetId)
            // Removed tight maxHeight limits, increased minHeight to accommodate media
            .frame(maxWidth: .infinity, minHeight: 480)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct TwitterWebView: UIViewRepresentable {
    let tweetId: String

    func makeCoordinator() -> EmbedNavigationDelegate {
        EmbedNavigationDelegate(allowedHosts: ["twitter.com", "x.com", "t.co", "twimg.com",
                                               "platform.twitter.com", "abs.twimg.com"])
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        
        // ALLOW SCROLLING so user can pan if tweet is very long
        wv.scrollView.isScrollEnabled = true
        wv.scrollView.bounces = false
        
        wv.navigationDelegate = context.coordinator
        let parts = tweetId.components(separatedBy: "|")
        let username = parts.count == 2 ? parts[0] : "x"
        let actualId = parts.count == 2 ? parts[1] : tweetId
        
        let html = twitterHTML(username: username, tweetId: actualId)
        wv.loadHTMLString(html, baseURL: URL(string: "https://twitter.com"))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {}
}

private func twitterHTML(username: String, tweetId: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
    <style>
      * { margin:0; padding:0; box-sizing:border-box; }
      body { background:transparent; font-family:sans-serif; }
      .wrap { display:flex; justify-content:center; padding:4px 0; }
    </style>
    </head>
    <body>
    <div class="wrap">
      <blockquote class="twitter-tweet" data-conversation="none" data-theme="dark"
                  data-cards="visible" data-media="visible" data-dnt="true" data-width="480">
        <a href="https://twitter.com/\(username)/status/\(tweetId)"></a>
      </blockquote>
    </div>
    <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
    </body>
    </html>
    """
}

// MARK: - Instagram Embed using WKWebView

private struct InstagramEmbedWebView: View {
    let postUrl: String

    var body: some View {
        InstagramWebView(postUrl: postUrl)
            .frame(maxWidth: .infinity, minHeight: 640)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct InstagramWebView: UIViewRepresentable {
    let postUrl: String

    func makeCoordinator() -> EmbedNavigationDelegate {
        EmbedNavigationDelegate(allowedHosts: ["instagram.com", "cdninstagram.com",
                                               "www.instagram.com", "graph.facebook.com"])
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        
        // ALLOW SCROLLING for vertical expansion of long captions
        wv.scrollView.isScrollEnabled = true
        wv.scrollView.bounces = false
        
        wv.navigationDelegate = context.coordinator
        let html = instagramHTML(postUrl: postUrl)
        wv.loadHTMLString(html, baseURL: URL(string: "https://www.instagram.com"))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {}
}

// MARK: - WKNavigationDelegate: block all navigation outside allowed domains
// SECURITY: Prevents malicious embed JS from navigating the WKWebView to arbitrary URLs.
// Any navigation to a non-whitelisted host is cancelled. Only the initial HTML load
// (data: scheme) is allowed unconditionally.

final class EmbedNavigationDelegate: NSObject, WKNavigationDelegate {
    private let allowedHosts: Set<String>

    init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let scheme = url.scheme ?? ""

        // Always allow the initial data/about/blob load
        if scheme == "about" || scheme == "data" || scheme == "blob" {
            decisionHandler(.allow)
            return
        }

        // Allow HTTPS requests to whitelisted embed domains
        if scheme == "https",
           let host = url.host,
           allowedHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            decisionHandler(.allow)
            return
        }

        // Block everything else — including link-click navigations
        decisionHandler(.cancel)
    }
}

private func instagramHTML(postUrl: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
    <style>
      * { margin:0; padding:0; box-sizing:border-box; }
      body { background:transparent; font-family:sans-serif; }
      .wrap { display:flex; justify-content:center; padding:4px 0; }
      .instagram-media { min-width:280px !important; width:100% !important; }
    </style>
    </head>
    <body>
    <div class="wrap">
      <blockquote class="instagram-media"
        data-instgrm-permalink="\(postUrl)"
        data-instgrm-version="14"
        style="border:0;border-radius:3px;
               box-shadow:0 0 1px 0 rgba(0,0,0,.5),0 1px 10px 0 rgba(0,0,0,.15);
               margin:1px;max-width:480px;min-width:280px;padding:0;width:calc(100% - 2px);">
      </blockquote>
    </div>
    <script async src="https://www.instagram.com/embed.js"></script>
    </body>
    </html>
    """
}

// NOTE: SafariView (UIViewControllerRepresentable) is defined in LoginView.swift.
// It is shared across the module — do NOT redefine it here.
