//
//  BuzzPostDetailView.swift
//  BoAnalyst
//
//  Created by BoAnalyst on 2026.
//  Updated: markdown rendering, delete post/comment, share button, relative timestamps.
//

import SwiftUI

struct BuzzPostDetailView: View {
    @State var post: BuzzPost
    let onUpdate: (BuzzPost) -> Void

    @State private var comments: [BuzzComment] = []
    @State private var newCommentText = ""
    @State private var isLoadingComments = true
    @State private var isSubmitting = false
    @State private var isLiking = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeletePostAlert = false
    @State private var commentToDelete: BuzzComment? = nil
    @State private var showDeleteCommentAlert = false
    @State private var isDeletingPost = false

    @AppStorage("userToken") private var userToken: String = ""
    @AppStorage("currentUserId") private var currentUserId: String = ""
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    @Environment(\.presentationMode) var presentationMode

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "0D0D0D"), Color(hex: "1A1A1A")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        postHeader
                        Divider().background(Color.white.opacity(0.08)).padding(.vertical, 8)
                        commentsSection
                    }
                }

                // Comment Input Bar
                commentInputBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Discussion")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Share button
                Button {
                    sharePost()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(Color(hex: "D4AF37"))
                }

                // Delete post (admin or own post)
                if isAdmin || post.userId == currentUserId {
                    Button {
                        showDeletePostAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
        }
        .onAppear { loadComments() }
        .alert("Delete Post", isPresented: $showDeletePostAlert) {
            Button("Delete", role: .destructive) { deletePost() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the post and all its comments.")
        }
        .alert("Delete Comment", isPresented: $showDeleteCommentAlert) {
            Button("Delete", role: .destructive) {
                if let c = commentToDelete { deleteComment(c) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete this comment?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Post Header

    @ViewBuilder
    private var postHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Author row
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "D4AF37"), Color(hex: "FFDF00")]),
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(post.authorName.prefix(1).uppercased()))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.authorName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Text(post.buzzCategory.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(hex: "D4AF37").opacity(0.2))
                            .foregroundColor(Color(hex: "D4AF37"))
                            .cornerRadius(6)
                        Text(formatRelativeDate(post.createdAt))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                Spacer()

                if post.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(Color(hex: "D4AF37"))
                        .font(.system(size: 13))
                }
            }

            // Title
            Text(post.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            // Content — full markdown rendering
            BuzzFormattedText(text: post.content, color: Color(hex: "E0E0E0"), fontSize: 16)

            // Tags
            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "D4AF37"))
                        }
                    }
                }
                .padding(.top, 4)
            }

            // Interaction row
            HStack(spacing: 24) {
                Button(action: toggleLike) {
                    HStack(spacing: 6) {
                        Image(systemName: post.userLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.userLiked ? .red : .gray)
                            .font(.system(size: 20))
                        Text("\(post.likeCount)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(post.userLiked ? .red : .gray)
                    }
                }
                .disabled(isLiking || userToken.isEmpty)

                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.gray)
                    Text("\(post.commentCount)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                    Text("\(post.viewCount)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color(hex: "1A1A1A"))
    }

    // MARK: - Comments Section

    @ViewBuilder
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Comments")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
                Text("\(comments.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color(hex: "D4AF37"))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if isLoadingComments {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "D4AF37")))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if comments.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No comments yet. Be the first to reply!")
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(comments) { comment in
                    commentRow(comment)
                }
            }

            Spacer(minLength: 80)
        }
    }

    @ViewBuilder
    private func commentRow(_ comment: BuzzComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: "D4AF37").opacity(0.8))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(comment.authorName.prefix(1).uppercased()))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    )

                Text(comment.authorName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "D4AF37"))

                Spacer()

                Text(formatRelativeDate(comment.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                // Delete button (admin or own comment)
                if isAdmin || comment.userId == currentUserId {
                    Button {
                        commentToDelete = comment
                        showDeleteCommentAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }

            BuzzFormattedText(text: comment.content, color: Color(hex: "D0D0D0"), fontSize: 14)
                .padding(.leading, 36)
        }
        .padding(12)
        .background(Color(hex: "222222"))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - Comment Input Bar

    @ViewBuilder
    private var commentInputBar: some View {
        if userToken.isEmpty {
            Text("Log in to like and comment")
                .foregroundColor(.gray)
                .font(.system(size: 14))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(hex: "1A1A1A"))
        } else {
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.08))
                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $newCommentText)
                        .padding(12)
                        .background(Color(hex: "2A2A2A"))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                        .disabled(isSubmitting)
                        .submitLabel(.send)
                        .onSubmit { submitComment() }

                    Button(action: submitComment) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .frame(width: 44, height: 44)
                                .background(Color(hex: "D4AF37"))
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.black)
                                .frame(width: 44, height: 44)
                                .background(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.gray.opacity(0.4)
                                    : Color(hex: "D4AF37"))
                                .clipShape(Circle())
                        }
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
                .padding()
                .background(Color(hex: "1A1A1A"))
            }
        }
    }

    // MARK: - Networking

    private func loadComments() {
        isLoadingComments = true
        let endpoint = APIEndpoint.getBuzzComments(postId: post.id, offset: 0, limit: 100)
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = endpoint.method.rawValue
        if !userToken.isEmpty { request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization") }

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLoadingComments = false
                guard let data, error == nil else { return }
                if let res = try? JSONDecoder().decode(BuzzCommentsResponse.self, from: data), res.success {
                    self.comments = res.comments
                }
            }
        }.resume()
    }

    private func toggleLike() {
        guard !userToken.isEmpty, !isLiking else { return }
        isLiking = true

        // Optimistic update
        let wasLiked = post.userLiked
        post = BuzzPost(from: post,
                        likeCount: post.likeCount + (wasLiked ? -1 : 1),
                        userLiked: !wasLiked)
        onUpdate(post)

        let endpoint = APIEndpoint.toggleBuzzLike(postId: post.id)
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLiking = false
                if error != nil {
                    // Revert
                    self.post = BuzzPost(from: self.post,
                                        likeCount: self.post.likeCount + (wasLiked ? 1 : -1),
                                        userLiked: wasLiked)
                    self.onUpdate(self.post)
                }
            }
        }.resume()
    }

    private func submitComment() {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !userToken.isEmpty, !isSubmitting else { return }
        isSubmitting = true

        do {
            let endpoint = try APIEndpoint.addBuzzComment(postId: post.id, content: trimmed)
            var request = URLRequest(url: endpoint.url)
            request.httpMethod = endpoint.method.rawValue
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = endpoint.body

            URLSession.shared.dataTask(with: request) { data, _, error in
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    guard let data, error == nil else {
                        self.errorMessage = error?.localizedDescription ?? "Failed to post comment"
                        self.showError = true
                        return
                    }
                    if let res = try? JSONDecoder().decode(BuzzAddCommentResponse.self, from: data),
                       res.success, let newComment = res.comment {
                        self.comments.append(newComment)
                        self.newCommentText = ""
                        self.post = BuzzPost(from: self.post, commentCount: self.post.commentCount + 1)
                        self.onUpdate(self.post)
                    } else {
                        self.errorMessage = "Failed to post comment"
                        self.showError = true
                    }
                }
            }.resume()
        } catch {
            isSubmitting = false
        }
    }

    private func deletePost() {
        guard !userToken.isEmpty else { return }
        isDeletingPost = true

        let endpoint = APIEndpoint.deleteBuzzPost(postId: post.id)
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                self.isDeletingPost = false
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    self.presentationMode.wrappedValue.dismiss()
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Failed to delete post"
                    self.showError = true
                }
            }
        }.resume()
    }

    private func deleteComment(_ comment: BuzzComment) {
        guard !userToken.isEmpty else { return }

        let endpoint = APIEndpoint.deleteBuzzComment(postId: post.id, commentId: comment.id)
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    self.comments.removeAll { $0.id == comment.id }
                    self.post = BuzzPost(from: self.post,
                                        commentCount: max(0, self.post.commentCount - 1))
                    self.onUpdate(self.post)
                }
            }
        }.resume()
    }

    private func sharePost() {
        let url = "https://boanalyst.com/#buzz-board?post=\(post.id)"
        let av = UIActivityViewController(activityItems: [post.title, url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    // MARK: - Date Helpers

    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
        guard let date else { return "Recently" }
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60    { return "Just now" }
        if diff < 3600  { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        if diff < 7 * 86400 { return "\(diff / 86400)d ago" }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}
