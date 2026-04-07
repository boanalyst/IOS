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
    // Rough URL finder
    let urlPattern = try! NSRegularExpression(pattern: #"https?://\S+"#)
    let nsText = text as NSString
    let matches = urlPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))

    for m in matches {
        var raw = nsText.substring(with: m.range)
        // Trim trailing punctuation like Android does
        let trailing: Set<Character> = [".", ",", ")", "]", ">"]
        while let last = raw.last, trailing.contains(last) { raw.removeLast() }

        if let embed = parseSocialEmbed(url: raw) {
            results.append(embed)
        }
    }
    return results
}

private func parseSocialEmbed(url: String) -> SocialEmbed? {
    // ── Twitter / X ──────────────────────────────────────────────────────
    let twitterPat = try! NSRegularExpression(
        pattern: #"(?:https?://)?(?:www\.)?(?:twitter\.com|x\.com)/\w+/status/(\d+)"#,
        options: .caseInsensitive
    )
    if let m = twitterPat.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
       let r = Range(m.range(at: 1), in: url) {
        return SocialEmbed(id: String(url[r]), originalUrl: url, type: .twitter)
    }

    // ── YouTube ──────────────────────────────────────────────────────────
    let youtubePat = try! NSRegularExpression(
        pattern: #"(?:https?://)?(?:www\.)?(?:youtube\.com/(?:watch\?(?:[^&\s]*&)*v=|shorts/|embed/)|youtu\.be/)([A-Za-z0-9_-]{11})"#,
        options: .caseInsensitive
    )
    if let m = youtubePat.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
       let r = Range(m.range(at: 1), in: url) {
        return SocialEmbed(id: String(url[r]), originalUrl: url, type: .youtube)
    }

    // ── Instagram ────────────────────────────────────────────────────────
    let igPat = try! NSRegularExpression(
        pattern: #"(?:https?://)?(?:www\.)?instagram\.com/(?:reel|p|tv)/([A-Za-z0-9_-]+)/?"#,
        options: .caseInsensitive
    )
    if let m = igPat.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
       let r = Range(m.range(at: 1), in: url) {
        return SocialEmbed(id: String(url[r]), originalUrl: url, type: .instagram)
    }

    return nil
}

// MARK: - Strip embed URLs from text (so they don't appear as raw links)

func stripEmbedUrls(from text: String, embeds: [SocialEmbed]) -> String {
    var result = text
    for embed in embeds {
        result = result.replacingOccurrences(of: embed.originalUrl, with: "")
    }
    // Collapse repeated newlines
    while result.contains("\n\n\n") {
        result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Social Embeds Section (main entry point for post cards)

struct SocialEmbedsSection: View {
    let embeds: [SocialEmbed]

    var body: some View {
        if embeds.isEmpty { EmptyView() } else {
            VStack(spacing: 8) {
                ForEach(embeds) { embed in
                    SocialEmbedCard(embed: embed)
                }
            }
        }
    }
}

// MARK: - Individual embed card dispatcher

private struct SocialEmbedCard: View {
    let embed: SocialEmbed

    var body: some View {
        switch embed.type {
        case .youtube:
            YouTubeThumbnailCard(videoId: embed.id, originalUrl: embed.originalUrl)
        case .twitter:
            XEmbedWebView(tweetId: embed.id)
        case .instagram:
            InstagramEmbedWebView(postUrl: embed.originalUrl)
        }
    }
}

// MARK: - YouTube Thumbnail Card (native — no WKWebView required)
// Mimics Android's YouTubeThumbnailCard; tapping opens m.youtube.com
// in SFSafariViewController for full in-app playback.

private struct YouTubeThumbnailCard: View {
    let videoId: String
    let originalUrl: String
    @State private var showSafari = false

    var body: some View {
        let thumbUrl = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")
        ZStack {
            // Thumbnail
            AsyncImage(url: thumbUrl) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(16/9, contentMode: .fill)
                default:
                    Rectangle().fill(Color.black.opacity(0.6))
                }
            }
            .clipped()

            // Dark overlay
            Color.black.opacity(0.22)

            // Red YouTube play circle
            Circle()
                .fill(Color(red: 1, green: 0, blue: 0))
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .offset(x: 2)
                )

            // "▶ YouTube" badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("▶  YouTube")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(8)
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { showSafari = true }
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: "https://m.youtube.com/watch?v=\(videoId)") {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - X / Twitter Embed using WKWebView

private struct XEmbedWebView: View {
    let tweetId: String

    var body: some View {
        TwitterWebView(tweetId: tweetId)
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct TwitterWebView: UIViewRepresentable {
    let tweetId: String

    private func html() -> String {
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
            <a href="https://twitter.com/x/status/\(tweetId)"></a>
          </blockquote>
        </div>
        <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
        </body>
        </html>
        """
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.loadHTMLString(html(), baseURL: URL(string: "https://twitter.com"))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {}
}

// MARK: - Instagram Embed using WKWebView

private struct InstagramEmbedWebView: View {
    let postUrl: String

    var body: some View {
        InstagramWebView(postUrl: postUrl)
            .frame(height: 560)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct InstagramWebView: UIViewRepresentable {
    let postUrl: String

    private func html() -> String {
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

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.loadHTMLString(html(), baseURL: URL(string: "https://www.instagram.com"))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {}
}

// MARK: - Safari View Controller Wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
