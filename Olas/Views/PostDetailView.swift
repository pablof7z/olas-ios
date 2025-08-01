import SwiftUI
import NDKSwift
import NDKSwiftUI

struct PostDetailView: View {
    let event: NDKEvent
    @Environment(NostrManager.self) private var nostrManager
    @EnvironmentObject var appState: AppState
    
    @State private var metadata: NDKUserMetadata?
    @State private var imageUrls: [String] = []
    @State private var likeCount = 0
    @State private var replyCount = 0
    @State private var hasLiked = false
    @State private var showingReplies = false
    @State private var showingZap = false
    
    var body: some View {
        ZStack {
            OlasDesign.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Images
                    if !imageUrls.isEmpty {
                        OlasMultiImageView(imageURLs: imageUrls)
                            .padding(.bottom, OlasDesign.Spacing.lg)
                    }
                    
                    VStack(alignment: .leading, spacing: OlasDesign.Spacing.md) {
                        // Author info
                        HStack(spacing: OlasDesign.Spacing.sm) {
                            NavigationLink(destination: ProfileView(pubkey: event.pubkey)) {
                                HStack(spacing: OlasDesign.Spacing.sm) {
                                    NDKUIProfilePicture(
                                        ndk: nostrManager.ndk,
                                        pubkey: event.pubkey,
                                        size: 40
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(metadata?.displayName ?? metadata?.name ?? "...")
                                            .font(OlasDesign.Typography.bodyMedium)
                                            .foregroundColor(OlasDesign.Colors.text)
                                        
                                        Text(formatDate(Date(timeIntervalSince1970: TimeInterval(event.createdAt))))
                                            .font(OlasDesign.Typography.caption)
                                            .foregroundColor(OlasDesign.Colors.textSecondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Content
                        NDKUIRichTextView(
                            ndk: nostrManager.ndk,
                            content: event.content,
                            tags: event.tags.map { Tag($0) },
                            showLinkPreviews: false,
                            style: .compact
                        )
                        .font(OlasDesign.Typography.body)
                        .foregroundColor(OlasDesign.Colors.text)
                        .tint(Color.white)
                        .padding(.vertical, OlasDesign.Spacing.sm)
                        
                        Divider()
                            .padding(.vertical, OlasDesign.Spacing.md)
                        
                        // Engagement buttons
                        HStack(spacing: OlasDesign.Spacing.xl) {
                            // Like
                            Button(action: toggleLike) {
                                HStack(spacing: OlasDesign.Spacing.xs) {
                                    Image(systemName: hasLiked ? "heart.fill" : "heart")
                                        .foregroundColor(hasLiked ? OlasDesign.Colors.like : OlasDesign.Colors.textSecondary)
                                    
                                    if likeCount > 0 {
                                        Text("\(likeCount)")
                                            .font(OlasDesign.Typography.caption)
                                            .foregroundColor(OlasDesign.Colors.textSecondary)
                                    }
                                }
                            }
                            
                            // Reply
                            Button(action: { showingReplies = true }) {
                                HStack(spacing: OlasDesign.Spacing.xs) {
                                    Image(systemName: "bubble.left")
                                        .foregroundColor(OlasDesign.Colors.textSecondary)
                                    
                                    if replyCount > 0 {
                                        Text("\(replyCount)")
                                            .font(OlasDesign.Typography.caption)
                                            .foregroundColor(OlasDesign.Colors.textSecondary)
                                    }
                                }
                            }
                            
                            // Zap
                            Button(action: { showingZap = true }) {
                                Image(systemName: "bolt")
                                    .foregroundColor(OlasDesign.Colors.textSecondary)
                            }
                            
                            // Share
                            Button(action: sharePost) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(OlasDesign.Colors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .font(.system(size: 20))
                    }
                    .padding(.horizontal, OlasDesign.Spacing.lg)
                }
            }
        }
        .navigationTitle("Post")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadProfile()
            await loadEngagementCounts()
            imageUrls = extractImageUrls(from: event.content)
        }
        .sheet(isPresented: $showingReplies) {
            ReplyView(parentEvent: event)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingZap) {
            ZapView(event: event, nostrManager: nostrManager)
                .environmentObject(appState)
        }
    }
    
    private func loadProfile() async {
        guard nostrManager.isInitialized,
              let profileManager = nostrManager.ndk.profileManager else { return }
        
        for await metadata in await profileManager.subscribe(for: event.pubkey, maxAge: 3600) {
            await MainActor.run {
                self.metadata = metadata
            }
            break
        }
    }
    
    private func loadEngagementCounts() async {
        guard nostrManager.isInitialized else { return }
        let ndk = nostrManager.ndk
        
        // Load reactions
        let reactionFilter = NDKFilter(
            kinds: [EventKind.reaction],
            events: [event.id]
        )
        
        // Load replies
        let replyFilter = NDKFilter(
            kinds: [EventKind.textNote],
            tags: ["e": Set([event.id])]
        )
        
        Task {
            // Count reactions
            let reactionDataSource = ndk.subscribe(filter: reactionFilter)
            let reactions = await reactionDataSource.collect(timeout: 2.0)
            
            var likes = 0
            var userLiked = false
            let currentUserPubkey = appState.currentUser?.pubkey
            
            for reaction in reactions.prefix(100) {
                if reaction.content == "+" || reaction.content == "❤️" {
                    likes += 1
                    if reaction.pubkey == currentUserPubkey {
                        userLiked = true
                    }
                }
            }
            
            await MainActor.run {
                self.likeCount = likes
                self.hasLiked = userLiked
            }
        }
        
        Task {
            // Count replies
            let replyDataSource = ndk.subscribe(filter: replyFilter)
            let replies = await replyDataSource.collect(timeout: 2.0)
            
            await MainActor.run {
                self.replyCount = replies.count
            }
        }
    }
    
    private func toggleLike() {
        guard nostrManager.isInitialized,
              let signer = nostrManager.authManager?.activeSigner else { return }
        let ndk = nostrManager.ndk
        
        hasLiked.toggle()
        likeCount += hasLiked ? 1 : -1
        #if os(iOS)
        OlasDesign.Haptic.impact(.light)
        #else
        OlasDesign.Haptic.impact(0)
        #endif
        
        Task {
            do {
                let reaction = try await NDKEventBuilder(ndk: ndk)
                    .content("+")
                    .kind(EventKind.reaction)
                    .tag(["e", event.id])
                    .tag(["p", event.pubkey])
                    .build(signer: signer)
                
                _ = try await ndk.publish(reaction)
            } catch {
                // Revert on error
                await MainActor.run {
                    hasLiked.toggle()
                    likeCount += hasLiked ? 1 : -1
                }
                OlasDesign.Haptic.error()
            }
        }
    }
    
    private func sharePost() {
        let nostrLink = "nostr:\(event.id)"
        
        #if canImport(UIKit)
        let activityViewController = UIActivityViewController(
            activityItems: [nostrLink],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(nostrLink, forType: .string)
        #endif
        
        OlasDesign.Haptic.success()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func extractImageUrls(from content: String) -> [String] {
        let pattern = "(https?://[^\\s]+\\.(jpg|jpeg|png|gif|webp)[^\\s]*)"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let matches = regex?.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content)) ?? []
        
        return matches.compactMap { match in
            guard let range = Range(match.range, in: content) else { return nil }
            return String(content[range])
        }
    }
}