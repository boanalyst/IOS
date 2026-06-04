import SwiftUI

struct MenuView: View {
    @Binding var selectedTab: Int
    
    // Tab Indices matching MainTabView
    // 0: Home, 1: Buzz, 2: Flock, 3: Inside, 4: Hub, 5: Pro, 6: Box Office, 7: Deals
    // Wait, the new tabs will be:
    // 0: Home, 1: Flock, 2: InsideTalk, 3: TechDeals, 4: Menu
    // We will route the others to new "hidden" indices in the ZStack:
    // 5: Box Office, 6: Buzz Board, 7: Distributors Hub, 8: Pro, 9: Profile
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor.edgesIgnoringSafeArea(.all)
            
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
                
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                    spacing: 16
                ) {
                    MenuCardView(title: "Box Office", iconName: "chart.bar.fill", isPremium: false) {
                        selectedTab = 5
                    }
                    MenuCardView(title: "Buzz Board", iconName: "flame.fill", isPremium: false) {
                        selectedTab = 6
                    }
                    MenuCardView(title: "Distributors", iconName: "briefcase.fill", isPremium: true) {
                        selectedTab = 7
                    }
                    MenuCardView(title: "BoAnalyst Pro", iconName: "star.fill", isPremium: true) {
                        selectedTab = 8
                    }
                    MenuCardView(title: "Profile & Settings", iconName: "person.fill", isPremium: false) {
                        selectedTab = 9 // Will open ProfileView sheet or tab
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
        }
    }
}

struct MenuCardView: View {
    let title: String
    let iconName: String
    let isPremium: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.15).opacity(0.8), Color(white: 0.08).opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                VStack(alignment: .leading) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: iconName)
                            .font(.system(size: 24))
                            .foregroundColor(isPremium ? AppTheme.goldPrimary : .white)
                    }
                    
                    Spacer()
                    
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
