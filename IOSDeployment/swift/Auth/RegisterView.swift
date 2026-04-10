// RegisterView.swift
// iOS port of Android's RegisterScreen.kt

import SwiftUI
import SafariServices
import AuthenticationServices
import CryptoKit

struct RegisterView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var oauthURL: URL? = nil
    @State private var appleSignInNonce: String = ""

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 20)

                    // Title
                    VStack(spacing: 6) {
                        Text("Create Account")
                            .font(.custom("Cinzel-Regular", size: 28))
                            .foregroundStyle(AppTheme.goldGradient)
                        Text("Join BoAnalyst")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    // Form card
                    VStack(alignment: .leading, spacing: 20) {
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

                        GoldTextField(placeholder: "Full Name", text: $name, icon: "person")
                            .textContentType(.name)

                        GoldTextField(placeholder: "Email", text: $email, icon: "envelope")
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)

                        GoldSecureField(
                            placeholder: "Password (min 6 characters)",
                            text: $password,
                            showPassword: $showPassword
                        )
                        .textContentType(.newPassword)

                        GoldSecureField(
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            showPassword: $showConfirmPassword
                        )
                        .textContentType(.newPassword)

                        if passwordMismatch {
                            Text("Passwords do not match")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.error)
                        }

                        GoldButton(
                            title: "Create Account",
                            isLoading: authViewModel.uiState.isLoading
                        ) {
                            Task {
                                await authViewModel.register(
                                    name: name,
                                    email: email,
                                    password: password
                                )
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

                        // Google sign-up
                        Button { oauthURL = URL(string: "https://boanalyst.com/api/auth/google?platform=ios") } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "globe").font(.system(size: 16))
                                Text("Sign up with Google").font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(AppTheme.surfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }

                        // X (Twitter) sign-up
                        Button { oauthURL = URL(string: "https://boanalyst.com/api/auth/twitter?platform=ios") } label: {
                            HStack(spacing: 10) {
                                Text("𝕏").font(.system(size: 17, weight: .bold))
                                Text("Sign up with X").font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(AppTheme.surfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }

                        // Sign in with Apple (Guideline 4.8 — required when offering third-party login)
                        SignInWithAppleButton(.signUp) { request in
                            let nonce = randomNonceString()
                            appleSignInNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(nonce)
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Back to Login
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(AppTheme.textSecondary)
                                .font(.system(size: 14))
                            Button("Sign In") { dismiss() }
                                .foregroundStyle(AppTheme.goldGradient)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        // Terms
                        Text("By creating an account, you agree to our Terms of Service and Privacy Policy.")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .cardStyle()

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(AppTheme.goldGradient)
                }
            }
        }
        // In-app OAuth browser (dismisses when boanalyst:// deep link fires)
        .sheet(item: $oauthURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Sign in with Apple helpers

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = cred.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                authViewModel.uiState.error = "Sign in with Apple failed. Please try again."
                return
            }
            let firstName = cred.fullName?.givenName ?? ""
            let lastName  = cred.fullName?.familyName ?? ""
            let fullName  = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
            let email     = cred.email ?? ""
            Task {
                await authViewModel.handleAppleSignIn(
                    identityToken: identityToken,
                    nonce: appleSignInNonce,
                    name: fullName,
                    email: email
                )
            }
        case .failure(let error):
            let nsErr = error as NSError
            if nsErr.code != ASAuthorizationError.canceled.rawValue {
                authViewModel.uiState.error = "Sign in with Apple failed. Please try again."
            }
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
    .environmentObject(AuthViewModel())
}
