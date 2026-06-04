import SwiftUI

struct MenuView: View {
    @Binding var selectedTab: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.clear.edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 48)
                
                Text("The Hub")
                    .font(.custom("ClashDisplay-Bold", size: 32, relativeTo: .largeTitle))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                
                Text("Discover more features and manage your account.")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                
                VStack(spacing: 8) {
                    MenuRowView(title: "Box Office", iconName: "chart.bar.fill", isPremium: false) {
                        isPresented = false
                        selectedTab = 5
                    }
                    MenuRowView(title: "Buzz Board", iconName: "flame.fill", isPremium: false) {
                        isPresented = false
                        selectedTab = 6
                    }
                    MenuRowView(title: "Distributors", iconName: "briefcase.fill", isPremium: true) {
                        isPresented = false
                        selectedTab = 7
                    }
                    MenuRowView(title: "BoAnalyst Pro", iconName: "star.fill", isPremium: true) {
                        isPresented = false
                        selectedTab = 8
                    }
                    MenuRowView(title: "Profile & Settings", iconName: "person.fill", isPremium: false) {
                        isPresented = false
                        selectedTab = 9 // Will open ProfileView sheet or tab
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
        }
    }
}

struct MenuRowView: View {
    let title: String
    let iconName: String
    let isPremium: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isPremium ? AppTheme.goldPrimary.opacity(0.15) : Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 24))
                        .foregroundColor(isPremium ? AppTheme.goldPrimary : .white)
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isPremium {
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.goldPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.goldPrimary.opacity(0.1))
                        .cornerRadius(6)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.3))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    colors: [Color(white: 0.15).opacity(0.8), Color(white: 0.08).opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
