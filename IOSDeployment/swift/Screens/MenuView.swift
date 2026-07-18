import SwiftUI

struct MenuView: View {
    @Binding var selectedTab: Int
    @Binding var isPresented: Bool
    @EnvironmentObject var rewardedAdManager: RewardedAdManager
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("THE HUB")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.goldPrimary)
                    .tracking(1.5)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .background(AppTheme.goldPrimary.opacity(0.2))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            // Menu Items
            VStack(spacing: 4) {
                MenuRowView(title: "Box Office", iconName: "chart.bar.fill", isPremium: false) {
                    if rewardedAdManager.isAdLoaded {
                        RewardedAdController.showAd(manager: rewardedAdManager) {
                            rewardedAdManager.loadAd()
                            isPresented = false
                            selectedTab = 5
                        }
                    } else {
                        rewardedAdManager.loadAd()
                        isPresented = false
                        selectedTab = 5
                    }
                }
                
                MenuRowView(title: "Buzz Board", iconName: "flame.fill", isPremium: false) {
                    isPresented = false
                    selectedTab = 6
                }
                
                MenuRowView(title: "BoAnalyst Pro", iconName: "star.fill", isPremium: true) {
                    isPresented = false
                    selectedTab = 8
                }
                
                MenuRowView(title: "Profile", iconName: "person.fill", isPremium: false) {
                    isPresented = false
                    authViewModel.showProfileSheet = true
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.surface.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.goldPrimary.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 8)
    }
}

struct MenuRowView: View {
    let title: String
    let iconName: String
    let isPremium: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isPremium ? AppTheme.goldPrimary : AppTheme.textSecondary)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                if isPremium {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.goldPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.goldPrimary.opacity(0.15))
                        .cornerRadius(4)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.textMuted.opacity(0.5))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
