import SwiftUI
import NDKSwift
import NDKSwiftUI

struct FollowersListView: View {
    let pubkey: String
    let mode: FollowMode
    @Environment(\.dismiss) private var dismiss
    @Environment(NostrManager.self) private var nostrManager
    @StateObject private var viewModel = FollowersViewModel()
    @State private var searchText = ""
    
    enum FollowMode {
        case followers
        case following
        
        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                OlasDesign.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Search bar
                        searchBar
                            .padding(.horizontal, OlasDesign.Spacing.md)
                            .padding(.vertical, OlasDesign.Spacing.sm)
                        
                        // Users list
                        if viewModel.isLoading {
                            loadingView
                        } else if filteredUsers.isEmpty && !searchText.isEmpty {
                            noResultsView
                        } else if filteredUsers.isEmpty {
                            emptyStateView
                        } else {
                            usersList
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                if nostrManager.isInitialized {
                    await viewModel.loadUsers(pubkey: pubkey, mode: mode, ndk: nostrManager.ndk)
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: OlasDesign.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(OlasDesign.Colors.textSecondary)
                .font(.system(size: 16))
            
            TextField("Search", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(OlasDesign.Typography.body)
                .foregroundColor(OlasDesign.Colors.text)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    OlasDesign.Haptic.selection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(OlasDesign.Colors.textSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, OlasDesign.Spacing.md)
        .padding(.vertical, OlasDesign.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.full)
                .fill(OlasDesign.Colors.surface)
        )
    }
    
    private var filteredUsers: [FollowUser] {
        if searchText.isEmpty {
            return viewModel.users
        } else {
            return viewModel.users.filter { user in
                user.metadata?.name?.localizedCaseInsensitiveContains(searchText) ?? false ||
                user.metadata?.displayName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                user.pubkey.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var usersList: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredUsers) { user in
                FollowUserRow(user: user)
                
                if user.id != filteredUsers.last?.id {
                    Divider()
                        .padding(.leading, 70)
                }
            }
        }
        .padding(.horizontal, OlasDesign.Spacing.md)
    }
    
    private var loadingView: some View {
        VStack(spacing: OlasDesign.Spacing.md) {
            ForEach(0..<10) { _ in
                HStack(spacing: OlasDesign.Spacing.md) {
                    Circle()
                        .fill(OlasDesign.Colors.surface)
                        .frame(width: 50, height: 50)
                        .shimmer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(OlasDesign.Colors.surface)
                            .frame(width: 120, height: 16)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(OlasDesign.Colors.surface)
                            .frame(width: 80, height: 14)
                            .shimmer()
                    }
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.full)
                        .fill(OlasDesign.Colors.surface)
                        .frame(width: 90, height: 32)
                        .shimmer()
                }
                .padding(.vertical, OlasDesign.Spacing.sm)
            }
        }
        .padding(.horizontal, OlasDesign.Spacing.md)
    }
    
    private var noResultsView: some View {
        VStack(spacing: OlasDesign.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(OlasDesign.Colors.textTertiary)
            
            Text("No users found")
                .font(OlasDesign.Typography.body)
                .foregroundColor(OlasDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OlasDesign.Spacing.xxl)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: OlasDesign.Spacing.lg) {
            Image(systemName: mode == .followers ? "person.2" : "person.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: OlasDesign.Colors.primaryGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(mode == .followers ? "No followers yet" : "Not following anyone")
                .font(OlasDesign.Typography.title)
                .foregroundColor(OlasDesign.Colors.text)
            
            Text(mode == .followers ? 
                 "When people follow this account, they'll appear here" : 
                 "Find interesting people to follow")
                .font(OlasDesign.Typography.body)
                .foregroundColor(OlasDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OlasDesign.Spacing.xxl)
        .padding(.horizontal, OlasDesign.Spacing.xl)
    }
}

// MARK: - Follow User Row
struct FollowUserRow: View {
    let user: FollowUser
    @Environment(NostrManager.self) private var nostrManager
    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var showProfile = false
    
    var body: some View {
        HStack(spacing: OlasDesign.Spacing.md) {
            // Avatar
            Button {
                showProfile = true
            } label: {
                NDKUIProfilePicture(
                    ndk: nostrManager.ndk,
                    pubkey: user.pubkey,
                    size: 50
                )
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.metadata?.displayName ?? user.metadata?.name ?? "User")
                    .font(OlasDesign.Typography.bodyMedium)
                    .foregroundColor(OlasDesign.Colors.text)
                    .lineLimit(1)
                
                Text("@\(user.metadata?.name ?? String(user.pubkey.prefix(16)))")
                    .font(OlasDesign.Typography.caption)
                    .foregroundColor(OlasDesign.Colors.textSecondary)
                    .lineLimit(1)
                
                if let about = user.metadata?.about {
                    Text(about)
                        .font(OlasDesign.Typography.caption)
                        .foregroundColor(OlasDesign.Colors.textSecondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Follow button
            if user.pubkey != nostrManager.authManager?.activeSession?.pubkey {
                Button {
                    Task {
                        await toggleFollow()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 90, height: 32)
                    } else {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(OlasDesign.Typography.caption.bold())
                            .foregroundStyle(isFollowing ? OlasDesign.Colors.text : .white)
                            .frame(width: 90, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.full)
                                    .stroke(isFollowing ? OlasDesign.Colors.divider : Color.clear, lineWidth: 1)
                                    .fill(isFollowing ? 
                                          AnyShapeStyle(Color.clear) :
                                          AnyShapeStyle(LinearGradient(
                                              colors: OlasDesign.Colors.primaryGradient,
                                              startPoint: .leading,
                                              endPoint: .trailing
                                          ))
                                    )
                            )
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFollowing)
                .disabled(isLoading)
            }
        }
        .padding(.vertical, OlasDesign.Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            showProfile = true
        }
        .navigationDestination(isPresented: $showProfile) {
            ProfileView(pubkey: user.pubkey)
        }
        .task {
            await checkFollowStatus()
        }
    }
    
    private func checkFollowStatus() async {
        guard nostrManager.isInitialized else { return }
        let ndk = nostrManager.ndk
        
        do {
            let contactList = try await ndk.fetchContactList()
            let follows = contactList?.tags.contains { tag in
                tag.count >= 2 && tag[0] == "p" && tag[1] == user.pubkey
            } ?? false
            
            await MainActor.run {
                isFollowing = follows
            }
        } catch {
            print("Failed to check follow status: \(error)")
        }
    }
    
    private func toggleFollow() async {
        guard nostrManager.isInitialized else { return }
        let ndk = nostrManager.ndk
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let user = NDKUser(pubkey: user.pubkey)
            
            if isFollowing {
                try await ndk.unfollow(user)
            } else {
                try await ndk.follow(user)
            }
            
            await MainActor.run {
                isFollowing.toggle()
                OlasDesign.Haptic.success()
            }
        } catch {
            print("Failed to toggle follow: \(error)")
            OlasDesign.Haptic.error()
        }
    }
}

// MARK: - View Model
@MainActor
class FollowersViewModel: ObservableObject {
    @Published var users: [FollowUser] = []
    @Published var isLoading = true
    
    func loadUsers(pubkey: String, mode: FollowersListView.FollowMode, ndk: NDK) async {
        isLoading = true
        
        switch mode {
        case .followers:
            await loadFollowers(pubkey: pubkey, ndk: ndk)
        case .following:
            await loadFollowing(pubkey: pubkey, ndk: ndk)
        }
        
        isLoading = false
    }
    
    private func loadFollowers(pubkey: String, ndk: NDK) async {
        // Load all contact lists that follow this user
        let filter = NDKFilter(
            kinds: [3], // Contact list
            limit: 1000
        )
        
        let dataSource = ndk.subscribe(
            filter: filter,
            maxAge: 0,
            cachePolicy: .cacheWithNetwork
        )
        
        var followers: [FollowUser] = []
        var processedPubkeys = Set<String>()
        
        for await event in dataSource.events {
            // Check if this contact list follows our target pubkey
            let pTags = event.tags.filter { $0.count >= 2 && $0[0] == "p" }
            let followsTarget = pTags.contains { $0[1] == pubkey }
            
            if followsTarget && !processedPubkeys.contains(event.pubkey) {
                processedPubkeys.insert(event.pubkey)
                let follower = FollowUser(pubkey: event.pubkey)
                followers.append(follower)
            }
        }
        
        self.users = followers
        
        // Load profiles
        await loadProfiles(ndk: ndk)
    }
    
    private func loadFollowing(pubkey: String, ndk: NDK) async {
        // Load contact list for this user
        let filter = NDKFilter(
            authors: [pubkey],
            kinds: [3]
        )
        
        let dataSource = ndk.subscribe(
            filter: filter,
            maxAge: 0,
            cachePolicy: .cacheWithNetwork
        )
        
        for await event in dataSource.events {
            // Extract followed users from p tags
            let following = event.tags.compactMap { tag -> FollowUser? in
                guard tag.count >= 2, tag[0] == "p" else { return nil }
                return FollowUser(pubkey: tag[1])
            }
            
            self.users = following
            
            // Load profiles
            await loadProfiles(ndk: ndk)
            
            // Break after first event since we only need one contact list
            break
        }
    }
    
    private func loadProfiles(ndk: NDK) async {
        guard let profileManager = ndk.profileManager else { return }
        
        for (index, user) in users.enumerated() {
            Task {
                for await metadata in await profileManager.subscribe(for: user.pubkey, maxAge: 3600) {
                    if let metadata = metadata {
                        await MainActor.run {
                            if index < self.users.count {
                                self.users[index].metadata = metadata
                            }
                        }
                    }
                    break
                }
            }
        }
    }
}

// MARK: - Models
struct FollowUser: Identifiable {
    let id = UUID()
    let pubkey: String
    var metadata: NDKUserMetadata?
}

// MARK: - Shimmer Modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase = 0.0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.2),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase * 200 - 100)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}