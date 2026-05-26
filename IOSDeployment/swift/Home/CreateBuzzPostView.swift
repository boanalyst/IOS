//
//  CreateBuzzPostView.swift
//  BoAnalyst
//
//  Created by BoAnalyst on 2026.
//  Rewritten: added BIU formatting toolbar, media picker, markdown preview.
//

import SwiftUI
import PhotosUI

// MARK: - BuzzMarkdown Helper

/// Strips markdown markers for plain-text previews and renders AttributedString
/// for full-fidelity display. Supports **bold**, _italic_, __underline__, #hashtag.
extension String {
    /// Returns a plain string with all markdown markers removed (for TextEditor display).
    func strippingBuzzMarkdown() -> String {
        var s = self
        s = s.replacingOccurrences(of: "**", with: "")
        s = s.replacingOccurrences(of: "__", with: "")
        // leave single _ alone — would mangle underscores
        return s
    }

    /// Returns an AttributedString rendering **bold**, _italic_, __underline__ and #hashtags.
    func asBuzzAttributedString(baseColor: UIColor = .white) -> AttributedString {
        var result = AttributedString()
        let goldUIColor = UIColor(red: 0.831, green: 0.686, blue: 0.216, alpha: 1)
        // Build segments
        var segments: [(text: String, style: String)] = [] // (text, "bold"/"italic"/"underline"/"hashtag"/"plain")

        let combined = "\\*\\*(.*?)\\*\\*|__(.*?)__|_(.*?)_"
        guard let regex = try? NSRegularExpression(pattern: combined, options: [.dotMatchesLineSeparators]) else {
            return AttributedString(self)
        }
        let ns = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: ns.length))

        var cursor = 0
        for match in matches {
            let start = match.range.location
            if start > cursor {
                let plain = ns.substring(with: NSRange(location: cursor, length: start - cursor))
                segments.append((plain, "plain"))
            }
            if match.range(at: 1).location != NSNotFound {
                segments.append((ns.substring(with: match.range(at: 1)), "bold"))
            } else if match.range(at: 2).location != NSNotFound {
                segments.append((ns.substring(with: match.range(at: 2)), "underline"))
            } else if match.range(at: 3).location != NSNotFound {
                segments.append((ns.substring(with: match.range(at: 3)), "italic"))
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            segments.append((ns.substring(from: cursor), "plain"))
        }

        for seg in segments {
            // Split by words to colour #hashtags
            let words = seg.text.components(separatedBy: CharacterSet.whitespaces)
            for (i, word) in words.enumerated() {
                var chunk = AttributedString(word)
                let isHashtag = word.hasPrefix("#") && word.count > 1
                switch seg.style {
                case "bold":
                    chunk.font = .init(.system(size: 15, weight: .bold))
                case "italic":
                    chunk.font = .init(.system(size: 15).italic())
                case "underline":
                    chunk.underlineStyle = .single
                default: break
                }
                if isHashtag {
                    chunk.foregroundColor = Color(uiColor: goldUIColor)
                    chunk.font = .init(.system(size: 15, weight: .semibold))
                }
                result.append(chunk)
                if i < words.count - 1 {
                    result.append(AttributedString(" "))
                }
            }
        }

        return result
    }
}

// MARK: - BuzzFormattedText

/// A SwiftUI Text view that renders Buzz markdown (bold/italic/underline/#hashtag).
struct BuzzFormattedText: View {
    let text: String
    var color: Color = Color(hex: "E0E0E0")
    var fontSize: CGFloat = 15
    var lineLimit: Int? = nil

    var body: some View {
        Text(ParsedTextCache.shared.parseBuzz(text))
            .foregroundColor(color)
            .font(.system(size: fontSize))
            .lineSpacing(4)
            .lineLimit(lineLimit)
    }
}

// MARK: - CreateBuzzPostView

struct CreateBuzzPostView: View {
    @Environment(\.presentationMode) var presentationMode
    let onPostCreated: (BuzzPost) -> Void

    @State private var title = ""
    @State private var content = ""
    @State private var contentFieldValue = ""   // mirrors content for cursor tracking
    @State private var selectedCategory: BuzzCategory = .general
    @State private var tagsText = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    // Keep a reference to the UITextView via a coordinator so we can insert text at cursor
    @State private var textViewCoordinator = TextViewCoordinator()

    private var userToken: String { KeychainManager.shared.getToken() ?? "" }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0D0D0D").edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── Category Picker ──────────────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(BuzzCategory.allCases.filter { $0 != .all }) { category in
                                        Button(action: { selectedCategory = category }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: category.icon)
                                                    .font(.system(size: 12))
                                                Text(category.displayName)
                                                    .font(.system(size: 13, weight: .semibold))
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedCategory == category ? Color(hex: "D4AF37") : Color.white.opacity(0.1))
                                            .foregroundColor(selectedCategory == category ? .black : .white)
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color(hex: "D4AF37").opacity(selectedCategory == category ? 0 : 0.3), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // ── Title ────────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                            TextField("Enter a title...", text: $title)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .font(.system(size: 17, weight: .semibold))
                        }

                        // ── BIU Toolbar + Content ────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Content")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)

                            // Formatting toolbar
                            HStack(spacing: 4) {
                                FormatToolbarButton(label: "B", font: .boldSystemFont(ofSize: 16)) {
                                    wrapSelectedText(with: "**")
                                }
                                FormatToolbarButton(label: "I", font: .italicSystemFont(ofSize: 16)) {
                                    wrapSelectedText(with: "_")
                                }
                                FormatToolbarButton(label: "U", font: .systemFont(ofSize: 16)) {
                                    wrapSelectedText(with: "__")
                                }
                                Spacer()
                                // Media picker
                                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 4 - selectedImages.count, matching: .images) {
                                    Label("Photo", systemImage: "photo")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(hex: "D4AF37"))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(hex: "D4AF37").opacity(0.12))
                                        .cornerRadius(8)
                                }
                                .disabled(selectedImages.count >= 4)
                                .onChange(of: selectedPhotos) { items in
                                    Task {
                                        for item in items {
                                            if let data = try? await item.loadTransferable(type: Data.self),
                                               let img = UIImage(data: data),
                                               selectedImages.count < 4 {
                                                selectedImages.append(img)
                                            }
                                        }
                                        selectedPhotos = []
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)

                            // Content TextEditor
                            BuzzContentEditor(text: $content, coordinator: textViewCoordinator)
                                .frame(minHeight: 180)
                                .padding(8)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)

                            // Character count hint
                            HStack {
                                Spacer()
                                Text("\(content.count) chars")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                        }

                        // ── Media previews ───────────────────────────────────
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(selectedImages.indices, id: \.self) { i in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: selectedImages[i])
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipped()
                                                .cornerRadius(10)
                                            Button {
                                                selectedImages.remove(at: i)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.5))
                                                    .clipShape(Circle())
                                            }
                                            .offset(x: 6, y: -6)
                                        }
                                    }
                                }
                            }
                        }

                        // ── Tags ─────────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags (comma separated, optional)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                            TextField("e.g. pushpa2, review, blockbuster", text: $tagsText)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        // Error inline
                        if showError {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSubmitting {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "D4AF37")))
                    } else {
                        Button("Post") {
                            submitPost()
                        }
                        .foregroundColor(canSubmit ? Color(hex: "D4AF37") : .gray)
                        .fontWeight(.bold)
                        .disabled(!canSubmit)
                    }
                }
            }
            .toolbarBackground(Color(hex: "1A1A1A"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - BIU Wrapping

    private func wrapSelectedText(with marker: String) {
        guard let tv = textViewCoordinator.textView else {
            // Fallback: just append markers
            content += "\(marker)\(marker)"
            return
        }
        guard let range = tv.selectedTextRange,
              let selectedText = tv.text(in: range) else { return }

        let wrapped = "\(marker)\(selectedText)\(marker)"
        tv.replace(range, withText: wrapped)
        content = tv.text ?? content
        // Move cursor inside markers if nothing was selected
        if selectedText.isEmpty, let pos = tv.position(from: range.start, offset: marker.count) {
            tv.selectedTextRange = tv.textRange(from: pos, to: pos)
        }
    }

    // MARK: - Submit (JSON, no media upload — server also accepts multipart for images)

    private func submitPost() {
        guard canSubmit else { return }
        isSubmitting = true
        showError = false

        let parsedTags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // If user picked images, use multipart upload; otherwise plain JSON
        if !selectedImages.isEmpty {
            submitWithMedia(tags: parsedTags)
        } else {
            submitJSON(tags: parsedTags)
        }
    }

    private func submitJSON(tags: [String]) {
        do {
            let endpoint = try APIEndpoint.createBuzzPost(
                title: title.trimmingCharacters(in: .whitespaces),
                content: content.trimmingCharacters(in: .whitespaces),
                category: selectedCategory.rawValue,
                tags: tags
            )
            guard let url = URL(string: APIConfig.baseURL + endpoint.path) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = endpoint.method.rawValue
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = endpoint.body

            URLSession.shared.dataTask(with: request) { data, _, error in
                DispatchQueue.main.async { handleCreateResponse(data: data, error: error) }
            }.resume()
        } catch {
            isSubmitting = false
            errorMessage = "Failed to encode request"
            showError = true
        }
    }

    private func submitWithMedia(tags: [String]) {
        guard let url = URL(string: APIConfig.baseURL + "/api/buzz/posts") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        let boundary = "BuzzBoardBoundary\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ field: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(field)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        append("title", title.trimmingCharacters(in: .whitespaces))
        append("content", content.trimmingCharacters(in: .whitespaces))
        append("category", selectedCategory.rawValue)
        if !tags.isEmpty {
            append("tags", (try? String(data: JSONEncoder().encode(tags), encoding: .utf8)) ?? "[]")
        }
        for (i, img) in selectedImages.enumerated() {
            if let jpeg = img.jpegData(compressionQuality: 0.75) {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"media\"; filename=\"image\(i).jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(jpeg)
                body.append("\r\n".data(using: .utf8)!)
            }
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async { handleCreateResponse(data: data, error: error) }
        }.resume()
    }

    private func handleCreateResponse(data: Data?, error: Error?) {
        isSubmitting = false
        guard let data = data, error == nil else {
            errorMessage = error?.localizedDescription ?? "Network error"
            showError = true
            return
        }
        do {
            let res = try JSONDecoder().decode(BuzzCreatePostResponse.self, from: data)
            if res.success, let newPost = res.post {
                onPostCreated(newPost)
                presentationMode.wrappedValue.dismiss()
            } else {
                errorMessage = res.message ?? "Failed to create post"
                showError = true
            }
        } catch {
            errorMessage = "Failed to parse server response"
            showError = true
        }
    }
}

// MARK: - FormatToolbarButton

struct FormatToolbarButton: View {
    let label: String
    let font: UIFont
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Font(font as CTFont))
                .foregroundColor(Color(hex: "D4AF37"))
                .frame(width: 36, height: 32)
                .background(Color(hex: "D4AF37").opacity(0.12))
                .cornerRadius(6)
        }
    }
}

// MARK: - BuzzContentEditor (UITextView wrapper to get cursor position for BIU)

class TextViewCoordinator: ObservableObject {
    weak var textView: UITextView?
}

struct BuzzContentEditor: UIViewRepresentable {
    @Binding var text: String
    var coordinator: TextViewCoordinator

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = .systemFont(ofSize: 15)
        tv.textColor = .white
        tv.tintColor = UIColor(red: 0.831, green: 0.686, blue: 0.216, alpha: 1)
        tv.text = text
        coordinator.textView = tv
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        coordinator.textView = uiView
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func textViewDidChange(_ textView: UITextView) { text = textView.text }
    }
}
