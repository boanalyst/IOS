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
    @Published var uiState = AuthUiState()

    var isAuthenticated: Bool { uiState.isAuthenticated }
    var currentUser: User? { uiState.user }

    private let api = APIClient.shared
    private let keychain = KeychainManager.shared

    // MARK: - Check Saved Token (replaces Android's init block token check)

    func checkSavedToken() async {
        guard keychain.hasToken() else {
            uiState.isAuthenticated = false
            return
        }
        do {
            let response = try await api.request(.getMe, responseType: ProfileResponse.self)
            if let user = response.user {
                uiState.user = user
                uiState.isAuthenticated = true
            } else {
                keychain.deleteToken()
                uiState.isAuthenticated = false
            }
        } catch {
            keychain.deleteToken()
            uiState.isAuthenticated = false
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        uiState.isLoading = true
        uiState.error = nil
        do {
            let endpoint = try APIEndpoint.login(email: email, password: password)
            let response = try await api.request(endpoint, responseType: AuthResponse.self)
            if response.success, let token = response.token {
                keychain.saveToken(token)
                uiState.user = response.user
                uiState.isAuthenticated = true
            } else {
                uiState.error = response.message ?? "Login failed. Please try again."
            }
        } catch APIError.unauthorized {
            // Token was somehow invalid at login time — clear state
            keychain.deleteToken()
            uiState.isAuthenticated = false
            uiState.error = "Session expired. Please log in again."
        } catch {
            uiState.error = error.localizedDescription
        }
        uiState.isLoading = false
    }

    // MARK: - Register

    func register(name: String, email: String, password: String) async {
        uiState.isLoading = true
        uiState.error = nil
        do {
            let endpoint = try APIEndpoint.register(email: email, password: password, name: name)
            let response = try await api.request(endpoint, responseType: AuthResponse.self)
            if response.success, let token = response.token {
                keychain.saveToken(token)
                uiState.user = response.user
                uiState.isAuthenticated = true
            } else {
                uiState.error = response.message ?? "Registration failed."
            }
        } catch {
            uiState.error = error.localizedDescription
        }
        uiState.isLoading = false
    }

    // MARK: - Logout

    func logout() async {
        try? await api.request(.logout, responseType: MessageResponse.self)
        keychain.deleteToken()
        uiState = AuthUiState()
    }

    // MARK: - OAuth Callback Handler
    // SECURITY: Mirrors Android's handleOAuthToken — token is saved tentatively,
    // then validated server-side. If rejected, it's wiped AND error is shown.
    func handleOAuthCallback(token: String) async {
        keychain.saveToken(token)
        do {
            let response = try await api.request(.getMe, responseType: ProfileResponse.self)
            if let user = response.user {
                uiState.user = user
                uiState.isAuthenticated = true
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

    // MARK: - Refresh User
    // If token is expired (401), auto-logout so the user gets the login screen.
    func refreshUser() async {
        do {
            let response = try await api.request(.getMe, responseType: ProfileResponse.self)
            uiState.user = response.user
        } catch APIError.unauthorized {
            await logout()
        } catch {}
    }

    func clearError() {
        uiState.error = nil
    }
}
