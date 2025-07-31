import SwiftUI
import NDKSwift

struct MainTabView: View {
    @Environment(NostrManager.self) private var nostrManager
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showCreatePost = false
    @State private var tabBarOpacity = 1.0
    @State private var tabBarOffset: CGFloat = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Feed
            NavigationStack {
                FeedView()
            }
            .tabItem {
                Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
            }
            .tag(0)
            .accessibilityIdentifier("feedTab")
            
            // Explore/Search
            NavigationStack {
                ExploreView()
            }
            .tabItem {
                Label("Explore", systemImage: selectedTab == 1 ? "magnifyingglass.circle.fill" : "magnifyingglass")
            }
            .tag(1)
            .accessibilityIdentifier("exploreTab")
            
            // Create Post - presented as sheet
            Color.clear
                .tabItem {
                    Label("Create", systemImage: "plus.square")
                }
                .tag(2)
                .accessibilityIdentifier("createTab")
                .onAppear {
                    if selectedTab == 2 {
                        showCreatePost = true
                        // Reset to previous tab
                        selectedTab = previousTab
                    }
                }
            
            // Profile Tab with Wallet & Analytics Access
            profileTab
            .tabItem {
                Label("Profile", systemImage: selectedTab == 3 ? "person.circle.fill" : "person.circle")
            }
            .tag(3)
            .accessibilityIdentifier("profileTab")
        }
        .accessibilityIdentifier("mainTabBar")
        .tint(OlasDesign.Colors.primary)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue != 2 {
                previousTab = oldValue
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
                .environmentObject(appState)
                .environment(nostrManager)
        }
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    @ViewBuilder
    private var profileTab: some View {
        if let session = nostrManager.authManager?.activeSession {
            NavigationStack {
                ProfileView(pubkey: session.pubkey)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            profileToolbarContent
                        }
                    }
            }
        } else {
            Text("Profile")
        }
    }
    
    @ViewBuilder
    private var profileToolbarContent: some View {
        HStack(spacing: 16) {
            // Analytics
            NavigationLink(destination: AnalyticsDashboardView().environment(nostrManager)) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(OlasDesign.Colors.primary)
            }
            
            // Wallet
            walletToolbarItem
        }
    }
    
    @ViewBuilder
    private var walletToolbarItem: some View {
        if nostrManager.cashuWallet != nil {
            NavigationLink(destination: OlasWalletView()) {
                Image(systemName: "bolt.circle")
                    .foregroundStyle(OlasDesign.Colors.primary)
            }
        } else {
            Image(systemName: "bolt.circle")
                .foregroundStyle(OlasDesign.Colors.textTertiary)
                .onTapGesture {
                    print("Wallet not initialized yet")
                }
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(OlasDesign.Colors.background)
        appearance.shadowColor = UIColor(OlasDesign.Colors.divider)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}