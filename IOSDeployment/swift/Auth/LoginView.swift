// LoginView.swift
// iOS port of Android's LoginScreen.kt — SwiftUI with Gold & Black theme

import SwiftUI
import SafariServices

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    // SECURITY: OAuth opens in-app SFSafariViewController (like Android Chrome Custom Tab)
    @State private var oauthURL: URL? = nil
    // Forgot Password: native in-app sheet — no external URL needed
    @State private var showForgotPassword = false

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    var body: some View {
        ZStack {
            // Background
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // ── Logo & Branding ────────────────────────────────────
                    VStack(spacing: 8) {
                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Text("Bo")
                                .font(.custom("Cinzel-Regular", size: 56))
                                .foregroundStyle(AppTheme.goldGradient)
                            Text("Analyst")
                                .font(.custom("Cinzel-Regular", size: 40))
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Rectangle()
                            .fill(AppTheme.goldGradient)
                            .frame(width: 60, height: 1)
                            .padding(.top, 8)

                        Text("India's Film Analysis Platform")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 16)

                    // ── Login Card ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Welcome Back")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        // Error message
                        if let error = authViewModel.uiState.error {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.error)
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.error)
                            }
                            .padding(12)
                            .background(AppTheme.error.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Email field
                        GoldTextField(
                            placeholder: "Email",
                            text: $email,
                            icon: "envelope"
                        )
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)

                        // Password field
                        GoldSecureField(
                            placeholder: "Password",
                            text: $password,
                            showPassword: $showPassword
                        )
                        .textContentType(.password)

                        // Forgot password — opens native in-app sheet
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.goldGradient)
                        }

                        // Login button
                        GoldButton(
                            title: "Sign In",
                            isLoading: authViewModel.uiState.isLoading
                        ) {
                            Task {
                                await authViewModel.login(email: email, password: password)
                            }
                        }
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            Text("or").font(.system(size: 12)).foregroundColor(AppTheme.textMuted)
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }

                        // Google OAuth button
                        Button {
                            openGoogleOAuth()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                    .font(.system(size: 16))
                                Text("Continue with Google")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.surfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }

                        // X (Twitter) OAuth button
                        Button {
                            openTwitterOAuth()
                        } label: {
                            HStack(spacing: 10) {
                                // X logo glyph — closest available SF Symbol
                                Text("𝕏")
                                    .font(.system(size: 17, weight: .bold))
                                Text("Continue with X")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.surfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }

                        // Register link
                        HStack {
                            Text("Don't have an account?")
                                .foregroundColor(AppTheme.textSecondary)
                                .font(.system(size: 14))
                            NavigationLink("Sign Up", destination: RegisterView())
                                .foregroundStyle(AppTheme.goldGradient)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(24)
                    .cardStyle()

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: authViewModel.uiState.error) { newError in
            guard newError != nil else { return }
            // Error auto-clears after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                authViewModel.clearError()
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet()
                .presentationDetents([.medium])
        }
        // OAuth Safari sheet — dismisses when boanalyst:// deep link fires
        .sheet(item: $oauthURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
    }

    private func openGoogleOAuth() {
        // Opens in-app SFSafariViewController — same as Android Chrome Custom Tab.
        // Server redirects to boanalyst://auth?token=... which closes this sheet
        // and triggers BoAnalystApp.handleDeepLink.
        oauthURL = URL(string: "https://boanalyst.com/api/auth/google?platform=ios")
    }

    private func openTwitterOAuth() {
        // Same flow as Google OAuth — server redirects back via boanalyst:// deep link.
        oauthURL = URL(string: "https://boanalyst.com/api/auth/twitter?platform=ios")
    }
}

// MARK: - Reusable Gold Text Field

struct GoldTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.goldGradient)
                    .frame(width: 20)
            }
            TextField(placeholder, text: $text)
                .foregroundColor(AppTheme.textPrimary)
                .tint(AppTheme.goldPrimary)
        }
        .padding(16)
        .background(AppTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(text.isEmpty ? Color.white.opacity(0.08) : AppTheme.goldPrimary.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Reusable Gold Secure Field

struct GoldSecureField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.goldGradient)
                .frame(width: 20)

            if showPassword {
                TextField(placeholder, text: $text)
                    .foregroundColor(AppTheme.textPrimary)
                    .tint(AppTheme.goldPrimary)
            } else {
                SecureField(placeholder, text: $text)
                    .foregroundColor(AppTheme.textPrimary)
                    .tint(AppTheme.goldPrimary)
            }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(16)
        .background(AppTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(text.isEmpty ? Color.white.opacity(0.08) : AppTheme.goldPrimary.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - SFSafariViewController Wrapper (for in-app OAuth)

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// Conform URL to Identifiable so it can be used with .sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - ForgotPasswordSheet (native in-app — no browser redirect)
// Calls POST /api/auth/forgot-password with the user's email.
// The server sends a reset link to the email; we show a success confirmation in-app.

struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var errorMsg: String? = nil

    private let api = APIClient.shared

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 28) {

                    if sent {
                        // Success state
                        VStack(spacing: 16) {
                            Image(systemName: "envelope.badge.checkmark.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(AppTheme.goldGradient)
                            Text("Check your email")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("If an account exists for **\(email)**, you\'ll receive a password reset link shortly.")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                        }
                        GoldButton(title: "Done") { dismiss() }
                            .padding(.horizontal, 24)
                    } else {
                        // Input state
                        VStack(spacing: 8) {
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 44))
                                .foregroundStyle(AppTheme.goldGradient)
                            Text("Reset Password")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Enter your email and we'll send you a reset link.")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        if let err = errorMsg {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.error)
                                .padding(10)
                                .background(AppTheme.error.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        GoldTextField(placeholder: "Email address", text: $email, icon: "envelope")
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .textContentType(.emailAddress)
                            .padding(.horizontal, 24)

                        GoldButton(title: "Send Reset Link", isLoading: isSending) {
                            Task { await sendReset() }
                        }
                        .disabled(!isEmailValid || isSending)
                        .opacity(!isEmailValid ? 0.6 : 1)
                        .padding(.horizontal, 24)
                    }

                    Spacer()
                }
                .padding(.top, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("FORGOT PASSWORD")
                        .font(.custom("Cinzel-Regular", size: 12))
                        .foregroundStyle(AppTheme.goldGradient)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    private func sendReset() async {
        isSending = true
        errorMsg = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        // POST /api/auth/forgot-password with { "email": "..." }
        if let body = try? JSONSerialization.data(withJSONObject: ["email": trimmedEmail]) {
            let endpoint = APIEndpoint(path: "/api/auth/forgot-password", method: .POST, body: body)
            _ = try? await api.requestRaw(endpoint)
        }
        // Always show success (security: don't reveal if email exists)
        isSending = false
        sent = true
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environmentObject(AuthViewModel())
}
