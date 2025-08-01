import SwiftUI
import NDKSwift
import NDKSwiftUI

struct FeedView: View {
    @Environment(NostrManager.self) private var nostrManager
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = FeedViewModel()
    @Namespace private var animation
    @State private var showAccountDrawer = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle animated gradient background
                TimeBasedGradient()
                    .ignoresSafeArea()
                    .opacity(0.1)
                
                OlasDesign.Colors.background
                    .ignoresSafeArea()
                
                // Always show the scroll view immediately - never wait
                ScrollView {
                    if viewModel.items.isEmpty {
                        // Empty state - show immediately while data streams in
                        emptyStateView
                            .padding(.top, 100)
                    } else {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            // Stories section
                            Section {
                                // Empty section content
                            } header: {
                                VStack(spacing: 0) {
                                    StoriesView()
                                        .background(OlasDesign.Colors.background)
                                }
                            }
                            
                            // Feed items
                            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                                FeedItemView(item: item)
                                    .id(item.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)
                                    ))
                                
                                if index < viewModel.items.count - 1 {
                                    Rectangle()
                                        .fill(OlasDesign.Colors.divider)
                                        .frame(height: 1)
                                }
                            }
                        }
                        .padding(.top, 0)
                    }
                }
            }
            .navigationTitle("Olas")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                // Current user avatar button - leading
                ToolbarItem(placement: .navigationBarLeading) {
                    if let session = nostrManager.authManager?.activeSession {
                        Button(action: { 
                            OlasDesign.Haptic.selection()
                            showAccountDrawer = true 
                        }) {
                            NDKUIProfilePicture(
                                ndk: nostrManager.ndk,
                                pubkey: session.pubkey,
                                size: 32
                            )
                            .overlay(
                                Circle()
                                    .stroke(OlasDesign.Colors.primary, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Create post button - trailing  
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: CreatePostView()) {
                        Image(systemName: "camera.fill")
                            .onTapGesture {
                                OlasDesign.Haptic.selection()
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    colors: OlasDesign.Colors.primaryGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                #endif
            }
            .refreshable {
                await handleRefresh()
            }
            .onAppear {
                let ndk = nostrManager.ndk
                viewModel.startFeed(with: ndk)
            }
            .onChange(of: viewModel.pendingItemsCount) { _, newValue in
                // Removed live indicator logic
            }
            .sheet(isPresented: $showAccountDrawer) {
                AccountDrawerView()
                    .environment(nostrManager)
                    .environmentObject(appState)
            }
        }
    }
    
    private var emptyStateView: some View {
        EmptyFeedView()
    }
    
    private func handleRefresh() async {
        #if os(iOS)
        OlasDesign.Haptic.impact(.medium)
        #endif
        await viewModel.refresh()
    }
    
    private func loadPendingItems() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            viewModel.loadPendingItems()
        }
        
        // Haptic feedback
        #if os(iOS)
        OlasDesign.Haptic.impact(.medium)
        #endif
    }
}

struct FeedItemView: View {
    let item: FeedItem
    @Environment(NostrManager.self) private var nostrManager
    @EnvironmentObject var appState: AppState
    @State private var isLiked = false
    @State private var scale: CGFloat = 1.0
    @State private var isZoomed = false
    @State private var showProfile = false
    @State private var showingReplies = false
    @State private var showingLikeAnimation = false
    @State private var showingZap = false
    @State private var doubleTapLocation: CGPoint = .zero
    @State private var navigateToProfile = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: OlasDesign.Spacing.md) {
                Button(action: { navigateToProfile = true }) {
                    HStack(spacing: OlasDesign.Spacing.md) {
                        NDKUIProfilePicture(
                            ndk: nostrManager.ndk,
                            pubkey: item.event.pubkey,
                            size: 40
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(item.metadata?.displayName ?? item.metadata?.name ?? String(item.event.pubkey.prefix(8)) + "...")
                                    .font(OlasDesign.Typography.bodyMedium)
                                    .foregroundColor(OlasDesign.Colors.text)
                                    .olasTextShadow()
                                
                                if let clientInfo = item.event.clientTag {
                                    Text("via \(clientInfo.name)")
                                        .font(OlasDesign.Typography.caption)
                                        .foregroundColor(OlasDesign.Colors.textTertiary)
                                        .olasTextShadow()
                                }
                            }
                            
                            Text("@\(item.metadata?.name ?? String(item.event.pubkey.prefix(8)))")
                                .font(OlasDesign.Typography.caption)
                                .foregroundColor(OlasDesign.Colors.textSecondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: { OlasDesign.Haptic.selection() }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(OlasDesign.Colors.textSecondary)
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, OlasDesign.Spacing.md)
            .padding(.vertical, OlasDesign.Spacing.md)
            
            // Image display with multi-image support
            if !item.imageURLs.isEmpty {
                OlasMultiImageView(imageURLs: item.imageURLs, blurhashes: item.blurhashes)
                    .onTapGesture(count: 2) { location in
                        // Double tap to like
                        doubleTapLocation = location
                        showingLikeAnimation = true
                        if !isLiked {
                            toggleLike()
                        }
                    }
                    .onTapGesture {
                        OlasDesign.Haptic.selection()
                        // Single tap - show full screen (handled in OlasMultiImageView)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                if value.translation.height < -50 {
                                    // Swipe up - View user profile
                                    OlasDesign.Haptic.selection()
                                    showProfile = true
                                }
                                // TODO: Add other swipe gestures
                                // Left: Quick share sheet
                                // Right: Save to collection
                                // Down: Dismiss if in preview
                            }
                    )
            } else {
                // No image found
                Rectangle()
                    .fill(OlasDesign.Colors.surface)
                    .aspectRatio(4/5, contentMode: .fit)
                    .overlay(
                        VStack(spacing: OlasDesign.Spacing.sm) {
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(OlasDesign.Colors.textTertiary)
                            Text("No Image")
                                .font(OlasDesign.Typography.caption)
                                .foregroundColor(OlasDesign.Colors.textTertiary)
                        }
                    )
            }
            
            // Actions
            HStack(spacing: OlasDesign.Spacing.lg) {
                // Like button with count
                Button(action: { toggleLike() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(isLiked ? OlasDesign.Colors.error : OlasDesign.Colors.text)
                            .scaleEffect(isLiked ? 1.1 : 1.0)
                            .olasTextShadow()
                        
                        if item.likeCount > 0 {
                            Text("\(item.likeCount)")
                                .font(OlasDesign.Typography.caption)
                                .foregroundColor(OlasDesign.Colors.textSecondary)
                                .olasTextShadow()
                        }
                    }
                }
                
                // Reply button with count
                Button(action: { 
                    OlasDesign.Haptic.selection()
                    showingReplies.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.title2)
                            .foregroundColor(OlasDesign.Colors.text)
                            .olasTextShadow()
                        
                        if item.replyCount > 0 {
                            Text("\(item.replyCount)")
                                .font(OlasDesign.Typography.caption)
                                .foregroundColor(OlasDesign.Colors.textSecondary)
                                .olasTextShadow()
                        }
                    }
                }
                
                // Zap button with amount
                Button(action: { sendZap() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt")
                            .font(.title2)
                            .foregroundColor(item.zapAmount > 0 ? OlasDesign.Colors.warning : OlasDesign.Colors.text)
                            .olasTextShadow()
                        
                        if item.zapAmount > 0 {
                            Text("\(item.zapAmount)")
                                .font(OlasDesign.Typography.caption)
                                .foregroundColor(OlasDesign.Colors.textSecondary)
                                .olasTextShadow()
                        }
                    }
                }
                
                Spacer()
                
                // Share button
                Button(action: { sharePost() }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(OlasDesign.Colors.text)
                        .olasTextShadow()
                }
            }
            .padding(.horizontal, OlasDesign.Spacing.md)
            .padding(.vertical, OlasDesign.Spacing.md)
            
            // Content with rich text
            if !item.event.content.isEmpty {
                NDKUIRichTextView(
                    ndk: nostrManager.ndk,
                    content: item.event.content,
                    tags: item.event.tags.map { Tag($0) },
                    showLinkPreviews: false,
                    style: .compact
                )
                .font(OlasDesign.Typography.body)
                .foregroundColor(OlasDesign.Colors.text)
                .tint(Color.white)
                .padding(.horizontal, OlasDesign.Spacing.md)
                .padding(.bottom, OlasDesign.Spacing.md)
            }
        }
        .background(OlasDesign.Colors.background)
        .overlay(
            // Like animation overlay
            Group {
                if showingLikeAnimation {
                    LikeAnimationView(location: doubleTapLocation)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                showingLikeAnimation = false
                            }
                        }
                }
            }
        )
        .sheet(isPresented: $showingReplies) {
            ReplyView(parentEvent: item.event)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingZap) {
            ZapView(event: item.event, nostrManager: nostrManager)
                .environmentObject(appState)
        }
        .navigationDestination(isPresented: $navigateToProfile) {
            ProfileView(pubkey: item.event.pubkey)
        }
        .navigationDestination(isPresented: $showProfile) {
            ProfileView(pubkey: item.event.pubkey)
        }
        .task {
            await loadEngagementCounts()
        }
    }
    
    // MARK: - Engagement Actions
    
    private func toggleLike() {
        guard nostrManager.isInitialized,
              let signer = nostrManager.authManager?.activeSigner else { return }
        
        let ndk = nostrManager.ndk
        
        #if os(iOS)
        OlasDesign.Haptic.impact(.light)
        #else
        OlasDesign.Haptic.impact(0)
        #endif
        
        withAnimation(OlasDesign.Animation.spring) {
            isLiked.toggle()
        }
        
        Task {
            do {
                if isLiked {
                    // Create like reaction (kind 7)
                    let reaction = try await NDKEventBuilder(ndk: ndk)
                        .kind(7)
                        .content("+")
                        .tags([
                            ["e", item.event.id],
                            ["p", item.event.pubkey]
                        ])
                        .build(signer: signer)
                    _ = try await ndk.publish(reaction)
                } else {
                    // TODO: Delete reaction event
                }
            } catch {
                print("Error toggling like: \(error)")
                // Revert on error
                withAnimation {
                    isLiked.toggle()
                }
            }
        }
    }
    
    private func sendZap() {
        OlasDesign.Haptic.selection()
        showingZap = true
    }
    
    private func sharePost() {
        OlasDesign.Haptic.selection()
        
        #if os(iOS)
        let noteLink = "nostr:\(item.event.id)"
        let activityVC = UIActivityViewController(
            activityItems: [noteLink],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #else
        // macOS sharing
        let noteLink = "nostr:\(item.event.id)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(noteLink, forType: .string)
        #endif
    }
    
    private func loadEngagementCounts() async {
        guard nostrManager.isInitialized else { return }
        let ndk = nostrManager.ndk
        
        // Check if we already liked this - reactive pattern
        if let signer = nostrManager.authManager?.activeSigner,
           let myPubkey = try? await signer.pubkey {
            let likeFilter = NDKFilter(
                authors: [myPubkey],
                kinds: [7],
                events: [item.event.id]
            )
            
            // Use reactive observe pattern - check cache first
            let likeDataSource = ndk.subscribe(
                filter: likeFilter,
                maxAge: 3600, // 1 hour cache
                cachePolicy: .cacheOnly // Only check cache, don't fetch from network
            )
            
            // Check first event to see if we liked it
            for await reaction in likeDataSource.events {
                if reaction.content == "+" || reaction.content == "🤙" {
                    await MainActor.run {
                        isLiked = true
                    }
                }
                break // Only need to check if any exist
            }
        }
        
        // Engagement counts are already being loaded reactively by FeedViewModel
        // No need to duplicate that logic here
    }
}

@MainActor
class FeedViewModel: ObservableObject {
    @Published var items: [FeedItem] = []
    @Published var pendingItems: [FeedItem] = []
    @Published var pendingItemsCount = 0
    private var profileTasks: [String: Task<Void, Never>] = [:]
    private var feedTask: Task<Void, Never>?
    private var engagementTasks: [String: Task<Void, Never>] = [:]
    private var lastEventTime: Timestamp?
    
    func startFeed(with ndk: NDK) {
        // Cancel any existing feed task
        feedTask?.cancel()
        
        // Start live immediately - no loading states
        
        feedTask = Task {
            
            // Subscribe to kind 20 picture posts (NIP-68)
            let filter = NDKFilter(kinds: [20])
            
            // Create data source using observe with reactive pattern
            let dataSource = ndk.subscribe(
                filter: filter,
                maxAge: 0,  // Real-time updates
                cachePolicy: .cacheWithNetwork
            )
            
            for await event in dataSource.events {
                // Process kind 20 events which use imeta tags
                if event.kind == 20 {
                    let feedItem = FeedItem(from: event)
                    
                    await MainActor.run {
                        // Check if this is a new post (arrived after initial load)
                        let isNewPost = lastEventTime != nil && event.createdAt > lastEventTime!
                        
                        if isNewPost {
                            // Add to pending items
                            if let insertIndex = pendingItems.firstIndex(where: { $0.event.createdAt < event.createdAt }) {
                                pendingItems.insert(feedItem, at: insertIndex)
                            } else {
                                pendingItems.append(feedItem)
                            }
                            pendingItemsCount = pendingItems.count
                            
                            // Haptic feedback for new posts
                            #if os(iOS)
                            OlasDesign.Haptic.impact(.light)
                            #endif
                        } else {
                            // Insert sorted by timestamp
                            if let insertIndex = items.firstIndex(where: { $0.event.createdAt < event.createdAt }) {
                                items.insert(feedItem, at: insertIndex)
                            } else {
                                items.append(feedItem)
                            }
                            
                            // Update last event time
                            if lastEventTime == nil || event.createdAt > lastEventTime! {
                                lastEventTime = event.createdAt
                            }
                        }
                        
                        // Limit feed size for performance
                        if items.count > 200 {
                            items.removeLast(items.count - 200)
                        }
                    }
                    
                    // Load profile reactively
                    loadProfileReactively(for: event.pubkey, ndk: ndk)
                    
                    // Load engagement counts reactively
                    loadEngagementReactively(for: event.id, ndk: ndk)
                }
            }
        }
    }
    
    private func loadProfileReactively(for pubkey: String, ndk: NDK) {
        // Cancel existing task if any
        profileTasks[pubkey]?.cancel()
        
        // Start new profile observation
        profileTasks[pubkey] = Task {
            guard let profileManager = ndk.profileManager else { return }
            
            for await metadata in await profileManager.subscribe(for: pubkey, maxAge: 3600) {
                if let metadata = metadata {
                    await MainActor.run {
                        updateItemsWithMetadata(pubkey: pubkey, metadata: metadata)
                    }
                }
            }
        }
    }
    
    private func updateItemsWithMetadata(pubkey: String, metadata: NDKUserMetadata) {
        for index in items.indices {
            if items[index].event.pubkey == pubkey {
                items[index].metadata = metadata
            }
        }
    }
    
    
    func refresh() async {
        // Clear items and restart subscription
        await MainActor.run {
            items.removeAll()
            pendingItems.removeAll()
            pendingItemsCount = 0
            lastEventTime = nil
        }
        // Cancel all tasks
        feedTask?.cancel()
        profileTasks.values.forEach { $0.cancel() }
        profileTasks.removeAll()
        engagementTasks.values.forEach { $0.cancel() }
        engagementTasks.removeAll()
        
        // Restart feed will happen when view calls startFeed again
    }
    
    func loadPendingItems() {
        // Move pending items to main feed
        let itemsToAdd = pendingItems
        pendingItems.removeAll()
        pendingItemsCount = 0
        
        // Insert all pending items with animation
        for item in itemsToAdd {
            if let insertIndex = items.firstIndex(where: { $0.event.createdAt < item.event.createdAt }) {
                items.insert(item, at: insertIndex)
            } else {
                items.append(item)
            }
        }
        
        // Update last event time
        if let latestItem = items.first {
            lastEventTime = latestItem.event.createdAt
        }
    }
    
    private func loadEngagementReactively(for eventId: String, ndk: NDK) {
        // Cancel existing task if any
        engagementTasks[eventId]?.cancel()
        
        engagementTasks[eventId] = Task {
            // Observe reactions (kind 7)
            let reactionsFilter = NDKFilter(
                kinds: [7],
                tags: [
                    "e": [eventId]
                ]
            )
            
            let reactionsDataSource = ndk.subscribe(
                filter: reactionsFilter,
                maxAge: 0,
                cachePolicy: .cacheWithNetwork
            )
            
            // Observe comments (NIP-22)
            let repliesFilter = NDKFilter(
                kinds: [EventKind.genericReply],
                tags: [
                    "E": Set([eventId])  // Comments on this root event
                ]
            )
            
            let repliesDataSource = ndk.subscribe(
                filter: repliesFilter,
                maxAge: 0,
                cachePolicy: .cacheWithNetwork
            )
            
            // Observe zaps (kind 9735)
            let zapsFilter = NDKFilter(
                kinds: [9735],  // NIP-57 zap receipts
                tags: [
                    "e": Set([eventId])  // Zaps for this event
                ]
            )
            
            let zapsDataSource = ndk.subscribe(
                filter: zapsFilter,
                maxAge: 0,
                cachePolicy: .cacheWithNetwork
            )
            
            // Update engagement counts reactively
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await reaction in reactionsDataSource.events {
                        if reaction.content == "+" || reaction.content == "🤙" {
                            await MainActor.run {
                                self.updateEngagement(for: eventId, type: .like, increment: true)
                            }
                        }
                    }
                }
                
                group.addTask {
                    for await _ in repliesDataSource.events {
                        await MainActor.run {
                            self.updateEngagement(for: eventId, type: .reply, increment: true)
                        }
                    }
                }
                
                group.addTask {
                    for await zapReceipt in zapsDataSource.events {
                        // Extract zap amount from bolt11 tag
                        let zapAmount = await self.extractZapAmount(from: zapReceipt)
                        if zapAmount > 0 {
                            await MainActor.run {
                                self.updateEngagement(for: eventId, type: .zap, amount: zapAmount)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func updateEngagement(for eventId: String, type: EngagementType, increment: Bool = true, amount: Int = 0) {
        guard let index = items.firstIndex(where: { $0.event.id == eventId }) else { return }
        
        switch type {
        case .like:
            items[index].likeCount += increment ? 1 : -1
        case .reply:
            items[index].replyCount += increment ? 1 : -1
        case .zap:
            items[index].zapAmount += amount
        }
    }
    
    enum EngagementType {
        case like, reply, zap
    }
    
    private func extractZapAmount(from zapReceiptEvent: NDKEvent) async -> Int {
        // Use NDKSwift's built-in NDKZapReceipt for proper NIP-57 parsing
        let zapReceipt = NDKZapReceipt(event: zapReceiptEvent)
        
        // Get amount in sats (NDKZapReceipt handles bolt11 parsing)
        if let amountSats = zapReceipt.amountSats {
            return Int(amountSats)
        }
        
        return 0
    }
}

struct FeedItem: Identifiable {
    let id: String
    let event: NDKEvent
    var metadata: NDKUserMetadata?
    let imageURLs: [String]
    let blurhashes: [String]
    var likeCount: Int = 0
    var replyCount: Int = 0
    var zapAmount: Int = 0
    
    init(from event: NDKEvent) {
        self.id = event.id
        self.event = event
        
        // Extract images and blurhashes from imeta tags (NIP-68 requires imeta tags)
        self.imageURLs = event.imageURLs
        
        // Extract blurhashes specifically from imeta tags, as NDKEvent.imageURLs only provides the URLs
        var hashes: [String] = []
        for tag in event.tags where tag.count >= 1 && tag[0] == "imeta" {
            var blurhash: String?
            
            // Parse imeta tag values
            for i in stride(from: 1, to: tag.count, by: 2) {
                if i + 1 < tag.count {
                    let key = tag[i]
                    let value = tag[i + 1]
                    
                    if key == "blurhash" {
                        blurhash = value
                    }
                }
            }
            
            if let hash = blurhash {
                hashes.append(hash)
            } else {
                hashes.append("") // Empty string for missing blurhash
            }
        }
        
        self.blurhashes = hashes
    }
    
}

// MARK: - Empty Feed View
struct EmptyFeedView: View {
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: OlasDesign.Spacing.xxxl) {
            Spacer()
            
            // Animated illustration
            ZStack {
                // Glowing background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: OlasDesign.Colors.primaryGradient.map { $0.opacity(0.2) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .scaleEffect(pulseAnimation ? 1.3 : 0.9)
                    .animation(
                        .easeInOut(duration: 3).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                
                // Camera icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: OlasDesign.Colors.primaryGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(pulseAnimation ? 10 : -10))
                    .animation(
                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
            }
            
            VStack(spacing: OlasDesign.Spacing.md) {
                Text("Your Feed is Empty")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Be the first to share a beautiful moment")
                    .font(OlasDesign.Typography.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: OlasDesign.Spacing.md) {
                Button {
                    #if os(iOS)
        OlasDesign.Haptic.impact(.medium)
        #else
        OlasDesign.Haptic.impact(0)
        #endif
                    // TODO: Navigate to create post
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Your First Post")
                    }
                    .font(OlasDesign.Typography.bodyBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, OlasDesign.Spacing.xl)
                    .padding(.vertical, OlasDesign.Spacing.md)
                    .background(
                        LinearGradient(
                            colors: OlasDesign.Colors.primaryGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: OlasDesign.CornerRadius.full))
                    .shadow(color: OlasDesign.Colors.primaryGradient[0].opacity(0.3), radius: 20, y: 10)
                }
                
                Button {
                    #if os(iOS)
                    OlasDesign.Haptic.impact(.light)
                    #else
                    OlasDesign.Haptic.impact(0)
                    #endif
                    // TODO: Navigate to discover
                } label: {
                    Text("Discover People to Follow")
                        .font(OlasDesign.Typography.body)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, OlasDesign.Spacing.xl)
        .onAppear {
            pulseAnimation = true
        }
    }
}

// MARK: - Like Animation View
struct LikeAnimationView: View {
    let location: CGPoint
    @State private var hearts: [HeartParticle] = []
    @State private var mainHeartScale: CGFloat = 0
    @State private var mainHeartOpacity: Double = 1
    
    struct HeartParticle: Identifiable {
        let id = UUID()
        var startPosition: CGPoint
        let endPosition: CGPoint
        let rotation: Double
        let scale: CGFloat
        let color: Color
    }
    
    var body: some View {
        ZStack {
            // Main heart
            Image(systemName: "heart.fill")
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(
                        colors: [OlasDesign.Colors.like, Color.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(mainHeartScale)
                .opacity(mainHeartOpacity)
                .position(location)
            
            // Particle hearts
            ForEach(hearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(heart.color)
                    .scaleEffect(heart.scale)
                    .rotationEffect(.degrees(heart.rotation))
                    .position(heart.startPosition)
                    .animation(.easeOut(duration: 1.5), value: heart.startPosition)
            }
        }
        .onAppear {
            // Animate main heart
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                mainHeartScale = 1.2
            }
            
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                mainHeartOpacity = 0
            }
            
            // Generate particles
            generateParticles()
            
            // Animate particles after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for i in hearts.indices {
                    withAnimation(.easeOut(duration: 1.5)) {
                        hearts[i].startPosition = hearts[i].endPosition
                    }
                }
            }
            
            // Haptic feedback
            OlasDesign.Haptic.success()
        }
    }
    
    private func generateParticles() {
        for _ in 0..<12 {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 100...200)
            let endX = location.x + cos(angle) * distance
            let endY = location.y + sin(angle) * distance - 50 // Bias upward
            
            let heart = HeartParticle(
                startPosition: location,
                endPosition: CGPoint(x: endX, y: endY),
                rotation: Double.random(in: -45...45),
                scale: CGFloat.random(in: 0.5...1.2),
                color: [OlasDesign.Colors.like, .pink, .red].randomElement()!
            )
            hearts.append(heart)
        }
    }
}