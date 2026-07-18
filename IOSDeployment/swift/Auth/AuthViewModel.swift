// AuthViewModel.swift
// iOS port of Android's AuthViewModel.kt
// Uses @MainActor + async/await instead of ViewModelScope + coroutines

import Foundation
import SwiftUI

// MARK: - Auth UI State

struct AuthUiState {
    var isLoading: Bool = false
    var isAuthenticated: Bool = false
    var user: User? = nil
    var error: String? = nil
}

// MARK: - AuthViewModel

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var uiState = AuthUiState() {
        didSet {
            UserDefaults.standard.set(uiState.user?.isPro == true, forKey: "is_user_pro")
        }
    }

    var isAuthenticated: Bool { uiState.isAuthenticated }
    var currentUser: User? { uiState.user }

    @Published var showProfileSheet = false

    private let api = APIClient.shared
    private let keychain = KeychainManager.shared

    // MARK: - Check Saved Token (replaces Android's init block token check)

    func checkSavedToken() async {
        guard keychain.hasToken() else {
            uiState.isAuthenticated = false
            return
        }
        do {
            let response = try await api.requestRaw(.getMe)
            if let success = response["success"] as? Bool, success,
               let userData = response["user"] as? [String: Any] {
                // Try to decode user, but authenticate even if decode partially fails
                if let userJSON = try? JSONSerialization.data(withJSONObject: userData),
                   let user = try? JSONDecoder().decode(User.self, from: userJSON) {
                    uiState.user = user
                }
                uiState.isAuthenticated = true
            } else {
                // Token is invalid on the server
                keychain.deleteToken()
                uiState.isAuthenticated = false
            }
        } catch APIError.unauthorized {
            // 401 = token expired or revoked
            keychain.deleteToken()
            uiState.isAuthenticated = false
        } catch {
            // Network error — keep token, show as unauthenticated for now
            // User can retry by opening the app again with connectivity
            uiState.isAuthenticated = false
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        uiState.isLoading = true
        uiState.error = nil
        do {
            let endpoint = try APIEndpoint.login(email: email, password: password)
            let response = try await api.requestRaw(endpoint)
            if let success = response["success"] as? Bool, success,
               let token = response["token"] as? String {
                keychain.saveToken(token)
                // Parse user if present — ignore decode failure, still authenticate
                if let userData = response["user"] as? [String: Any],
                   let userJSON = try? JSONSerialization.data(withJSONObject: userData),
                   let user = try? JSONDecoder().decode(User.self, from: userJSON) {
                    uiState.user = user
                }                                                                               
                uiState.isAuthenticated = true
                await IAPManager.shared.refreshSubscriptionStatus()
                // Sync Apple entitlements with this backend account.
                // If the Apple ID has an active subscription (from any account),
                // ensure this backend user gets the correct plan.
                await IAPManager.shared.syncSubscriptionWithBackend(backendPlan: uiState.user?.subscriptionPlan)
            } else {
                let message = response["message"] as? String
                uiState.error = message ?? "Invalid email or password. Please try again."
            }
        } catch APIError.unauthorized {
            uiState.error = "Invalid email or password. Please try again."
        } catch APIError.serverError(let code, let msg) {
            if code == 401 {
                uiState.error = "Invalid email or password. Please try again."
            } else {
                uiState.error = msg?.isEmpty == false ? msg! : "Login failed. Please try again."
            }
        } catch {
            uiState.error = "Unable to connect. Please check your internet and try again."
        }
        uiState.isLoading = false
    }

    // MARK: - Register

    func register(name: String, email: String, password: String) async {
        uiState.isLoading = true
        uiState.error = nil
        do {
            let endpoint = try APIEndpoint.register(email: email, password: password, name: name)
            let response = try await api.requestRaw(endpoint)
            if let success = response["success"] as? Bool, success,
               let token = response["token"] as? String {
                keychain.saveToken(token)
                // Parse user if present — ignore decode failure, still authenticate
                if let userData = response["user"] as? [String: Any],
                   let userJSON = try? JSONSerialization.data(withJSONObject: userData),
                   let user = try? JSONDecoder().decode(User.self, from: userJSON) {
                    uiState.user = user
                }
                uiState.isAuthenticated = true
                await IAPManager.shared.refreshSubscriptionStatus()
                await IAPManager.shared.syncSubscriptionWithBackend(backendPlan: uiState.user?.subscriptionPlan)
            } else {
                let message = response["message"] as? String
                uiState.error = message ?? "Registration failed. Please try again."
            }
        } catch APIError.serverError(let code, let msg) {
            if code == 409 {
                uiState.error = "An account with this email already exists. Please sign in."
            } else {
                uiState.error = msg?.isEmpty == false ? msg! : "Registration failed. Please try again."
            }
        } catch {
            uiState.error = "Unable to connect. Please check your internet and try again."
        }
        uiState.isLoading = false
    }

    // MARK: - Logout

    func logout() async {
        _ = try? await api.request(.logout, responseType: MessageResponse.self)
        keychain.deleteToken()
        uiState = AuthUiState()
        // Clear the IAP notified-transaction cache so the next account
        // gets a clean slate. This prevents a stale cache entry from
        // blocking a legitimate renewal notification for a different user.
        IAPManager.shared.clearNotifiedTransactions()
    }

    // MARK: - Delete Account (Guideline 5.1.1(v))
    // Permanently deletes the user's account on the server, then wipes the
    // local session so the app returns to the login screen.
    func deleteAccount() async throws {
        _ = try await api.requestRaw(.deleteAccount)
        keychain.deleteToken()
        uiState = AuthUiState()
    }

    // MARK: - OAuth Callback Handler
    // SECURITY: Mirrors Android's handleOAuthToken — token is saved tentatively,
    // then validated server-side. If rejected, it's wiped AND error is shown.
    func handleOAuthCallback(token: String) async {
        keychain.saveToken(token)
        do {
            let response = try await api.requestRaw(.getMe)
            if let success = response["success"] as? Bool, success,
               let userData = response["user"] as? [String: Any] {
                if let userJSON = try? JSONSerialization.data(withJSONObject: userData),
                   let user = try? JSONDecoder().decode(User.self, from: userJSON) {
                    uiState.user = user
                }
                uiState.isAuthenticated = true
                await IAPManager.shared.refreshSubscriptionStatus()
                await IAPManager.shared.syncSubscriptionWithBackend(backendPlan: uiState.user?.subscriptionPlan)
            } else {
                keychain.deleteToken()
                uiState.isAuthenticated = false
                uiState.error = "Sign-in failed. Please try again."
            }
        } catch {
            // Server rejected the token — wipe it so the user isn't stuck
            keychain.deleteToken()
            uiState.isAuthenticated = false
            uiState.error = "Sign-in failed. Please try again."
        }
    }

    // MARK: - Sign in with Apple (Guideline 4.8)
    // Sends the Apple identity token + nonce to POST /api/auth/apple.
    // The backend verifies the token via Apple's public keys and returns a session JWT.
    func handleAppleSignIn(identityToken: String, nonce: String, name: String, email: String) async {
        uiState.isLoading = true
        uiState.error = nil
        do {
            var payload: [String: Any] = ["identityToken": identityToken, "nonce": nonce]
            if !name.isEmpty  { payload["name"]  = name  }
            if !email.isEmpty { payload["email"] = email }
            let body = try JSONSerialization.data(withJSONObject: payload)
            let endpoint = APIEndpoint(path: "/api/auth/apple", method: .POST, body: body)
            let response = try await api.requestRaw(endpoint)
            if let success = response["success"] as? Bool, success,
               let token = response["token"] as? String {
                keychain.saveToken(token)
                if let userData = response["user"] as? [String: Any],
                   let userJSON = try? JSONSerialization.data(withJSONObject: userData),
                   let user = try? JSONDecoder().decode(User.self, from: userJSON) {
                    uiState.user = user
                }
                uiState.isAuthenticated = true
                await IAPManager.shared.refreshSubscriptionStatus()
                await IAPManager.shared.syncSubscriptionWithBackend(backendPlan: uiState.user?.subscriptionPlan)
            } else {
                uiState.error = "Backend Parsed OK but JSON was wrong: " + ((response["message"] as? String) ?? "No message")
            }
        } catch {
            uiState.error = "Catch block Network Error: \(error.localizedDescription)"
        }
        uiState.isLoading = false
    }

    // MARK: - Refresh User
    // Fetches fresh user data from /api/auth/me. Only logs out if the server
    // explicitly rejects the token (HTTP 401). Network errors, server errors
    // (500/403), and transient failures are silently ignored — the local
    // session stays intact because the JWT may still be valid; forcing a
    // logout during a transient backend hiccup (e.g. during a subscription
    // upgrade write) is what caused the "repeated sign-in" bug.
    func refreshUser() async {
        do {
            let response = try await api.requestRaw(.getMe)
            if let success = response["success"] as? Bool, success,
               let userData = response["user"] as? [String: Any],
               let userJSON = try? JSONSerialization.data(withJSONObject: userData),
               let user = try? JSONDecoder().decode(User.self, from: userJSON) {
                uiState.user = user
            }
        } catch APIError.unauthorized {
            // 401 = token definitively rejected by the server (expired or revoked).
            // This is the ONLY case where we should auto-logout.
            await logout()
        } catch {
            // Network errors, 403, 500, timeouts — do NOT logout.
            // The JWT might still be perfectly valid; the server may just be
            // temporarily unreachable or under load during a subscription update.
            print("⚠️ refreshUser failed (non-fatal, keeping session): \(error)")
        }
    }

    func clearError() {
        uiState.error = nil
    }
}
