// BoxOfficeView.swift
// iOS port of Android's BoxOfficeScreen.kt
// Displays live BMS ticket data + box office collection table

import SwiftUI

// MARK: - BoxOfficeViewModel

@MainActor
final class BoxOfficeViewModel: ObservableObject {
    @Published var boxOfficeEntries: [BoxOfficeEntry] = []
    @Published var bmsLive: BmsLiveData? = nil
    @Published var isLoading = false
    @Published var error: String? = nil

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        error = nil

        async let entriesTask = api.request(.getBoxOfficeEntries, responseType: BoxOfficeResponse.self)
        async let bmsTask     = api.request(.getBmsLiveTickets,   responseType: BmsLiveResponse.self)

        if let r = try? await entriesTask { boxOfficeEntries = r.data }
        if let r = try? await bmsTask     { bmsLive = r.data }

        if boxOfficeEntries.isEmpty {
            error = "Could not load box office data."
        }
        isLoading = false
    }
}

// MARK: - BoxOfficeView

struct BoxOfficeView: View {
    @StateObject private var viewModel = BoxOfficeViewModel()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.boxOfficeEntries.isEmpty {
                LoadingView()
            } else {
                ScrollView {
                    VStack(spacing: 20) {

                        // ── BMS Live Ticket Counter ───────────────────────
                        if let live = viewModel.bmsLive {
                            BMSLiveCard(data: live)
                                .padding(.horizontal, 16)
                        }

                        // ── Collection Table ──────────────────────────────
                        SectionHeader(title: "Box Office Collection", icon: "indianrupeesign.circle.fill")

                        if viewModel.boxOfficeEntries.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 0) {
                                // Header row
                                HStack {
                                    Text("FILM")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("COLLECTION")
                                        .frame(width: 100, alignment: .trailing)
                                    Text("VERDICT")
                                        .frame(width: 80, alignment: .trailing)
                                }
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(AppTheme.textMuted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppTheme.surface)

                                ForEach(viewModel.boxOfficeEntries) { entry in
                                    BoxOfficeTableRow(entry: entry)
                                    Divider()
                                        .background(Color.white.opacity(0.05))
                                        .padding(.horizontal, 16)
                                }
                            }
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppTheme.goldPrimary.opacity(0.12), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 12)
                }
                .refreshable { await viewModel.load() }
            }
        }
        .task { await viewModel.load() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("BOX OFFICE")
                    .font(.custom("Cinzel-Regular", size: 14))
                    .foregroundStyle(AppTheme.goldGradient)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.goldGradient)
            Text("No data available")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            Text("Box office data will appear here once available.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - BMS Live Card

struct BMSLiveCard: View {
    let data: BmsLiveData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.success)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(AppTheme.success.opacity(0.3), lineWidth: 4))
                Text("LIVE — BookMyShow Tickets")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(AppTheme.success)
                Spacer()
                Text("\(data.total) total")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.goldGradient)
            }

            // Top shows
            VStack(spacing: 8) {
                ForEach(data.shows.prefix(5)) { show in
                    HStack {
                        Text(show.movie)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(show.tickets) 🎟")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.goldGradient)
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Box Office Table Row

struct BoxOfficeTableRow: View {
    let entry: BoxOfficeEntry

    private var verdictColor: Color {
        switch entry.verdictColor.lowercased() {
        case "green":  return AppTheme.success
        case "red":    return AppTheme.error
        case "yellow": return AppTheme.warning
        default:       return AppTheme.goldPrimary
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text("Budget: ₹\(entry.budget) Cr")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("₹\(entry.collection) Cr")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.goldGradient)
                .frame(width: 100, alignment: .trailing)

            Text(entry.verdict)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(verdictColor)
                .frame(width: 80, alignment: .trailing)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
