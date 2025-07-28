import Foundation
import NDKSwift
import SwiftUI
import Combine

// MARK: - User Profile Data Source

/// Data source for user profile metadata
@MainActor
public class UserProfileDataSource: ObservableObject {
    @Published public private(set) var profile: NDKUserProfile?
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let ndk: NDK
    private let pubkey: String
    private var observationTask: Task<Void, Never>?
    
    public init(ndk: NDK, pubkey: String) {
        self.ndk = ndk
        self.pubkey = pubkey
        
        observationTask = Task { [weak self] in
            await self?.observeProfile()
        }
    }
    
    private func observeProfile() async {
        isLoading = true
        
        // Use NDK's profile manager instead of custom data source
        for await profile in await ndk.profileManager.observe(for: pubkey, maxAge: 0) {
            await MainActor.run { [weak self] in
                self?.profile = profile
                self?.isLoading = false
            }
        }
    }
    
    deinit {
        observationTask?.cancel()
    }
}

// MARK: - Image Feed Data Source

/// Data source for image posts (kind 1 with image tags)
@MainActor
public class ImageFeedDataSource: ObservableObject {
    @Published public private(set) var posts: [NDKEvent] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let ndk: NDK
    private let filter: NDKFilter
    private var observationTask: Task<Void, Never>?
    
    public init(ndk: NDK, authors: [String]? = nil, limit: Int = 50) {
        self.ndk = ndk
        var filter = NDKFilter(kinds: [EventKind.textNote])
        filter.authors = authors
        filter.limit = limit
        self.filter = filter
        
        observationTask = Task { [weak self] in
            await self?.observePosts()
        }
    }
    
    private func observePosts() async {
        isLoading = true
        
        let dataSource = ndk.observe(
            filter: filter,
            maxAge: 0,
            cachePolicy: .cacheWithNetwork
        )
        
        var collectedPosts: [NDKEvent] = []
        
        for await event in dataSource.events {
            // Filter for events with image tags
            if event.tags.contains(where: { tag in
                tag.count >= 2 && (tag[0] == "imeta" || 
                                 (tag[0] == "r" && isImageURL(tag[1])))
            }) {
                collectedPosts.append(event)
                
                await MainActor.run { [weak self] in
                    self?.posts = collectedPosts.sorted { $0.createdAt > $1.createdAt }
                    self?.isLoading = false
                }
            }
        }
    }
    
    private func isImageURL(_ url: String) -> Bool {
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp"]
        return imageExtensions.contains { url.lowercased().hasSuffix($0) }
    }
    
    deinit {
        observationTask?.cancel()
    }
}

// MARK: - Hashtag Feed Data Source

/// Data source for posts with specific hashtags
@MainActor
public class HashtagFeedDataSource: ObservableObject {
    @Published public private(set) var posts: [NDKEvent] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let ndk: NDK
    private let filter: NDKFilter
    private var observationTask: Task<Void, Never>?
    
    public init(ndk: NDK, hashtag: String, limit: Int = 50) {
        self.ndk = ndk
        let cleanHashtag = hashtag.lowercased().replacingOccurrences(of: "#", with: "")
        
        self.filter = NDKFilter(
            kinds: [EventKind.textNote],
            limit: limit,
            tags: ["t": Set([cleanHashtag])]
        )
        
        observationTask = Task { [weak self] in
            await self?.observePosts()
        }
    }
    
    private func observePosts() async {
        isLoading = true
        
        let dataSource = ndk.observe(
            filter: filter,
            maxAge: 0,
            cachePolicy: .cacheWithNetwork
        )
        
        var collectedPosts: [NDKEvent] = []
        
        for await event in dataSource.events {
            collectedPosts.append(event)
            
            await MainActor.run { [weak self] in
                self?.posts = collectedPosts.sorted { $0.createdAt > $1.createdAt }
                self?.isLoading = false
            }
        }
    }
    
    deinit {
        observationTask?.cancel()
    }
}

// MARK: - User Posts Data Source

/// Data source for a specific user's posts
@MainActor
public class UserPostsDataSource: ObservableObject {
    @Published public private(set) var posts: [NDKEvent] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let ndk: NDK
    private let filter: NDKFilter
    private let includeReplies: Bool
    private var observationTask: Task<Void, Never>?
    
    public init(ndk: NDK, pubkey: String, includeReplies: Bool = false) {
        self.ndk = ndk
        self.includeReplies = includeReplies
        self.filter = NDKFilter(
            authors: [pubkey],
            kinds: [EventKind.textNote]
        )
        
        observationTask = Task { [weak self] in
            await self?.observePosts()
        }
    }
    
    private func observePosts() async {
        isLoading = true
        
        let dataSource = ndk.observe(
            filter: filter,
            maxAge: 0,
            cachePolicy: .cacheWithNetwork
        )
        
        var collectedPosts: [NDKEvent] = []
        
        for await event in dataSource.events {
            // Filter based on reply status
            if !includeReplies && event.isReply {
                continue
            }
            
            // Filter for events with images
            if event.tags.contains(where: { tag in
                tag.count >= 2 && (tag[0] == "imeta" || 
                                 (tag[0] == "r" && isImageURL(tag[1])))
            }) {
                collectedPosts.append(event)
                
                await MainActor.run { [weak self] in
                    self?.posts = collectedPosts.sorted { $0.createdAt > $1.createdAt }
                    self?.isLoading = false
                }
            }
        }
    }
    
    private func isImageURL(_ url: String) -> Bool {
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp"]
        return imageExtensions.contains { url.lowercased().hasSuffix($0) }
    }
    
    deinit {
        observationTask?.cancel()
    }
}

// MARK: - Extensions

extension NDKEvent {
    var isReply: Bool {
        // Check for reply markers
        tags.contains { tag in
            (tag.count >= 2 && tag[0] == "e" && tag.count >= 4 && tag[3] == "reply") ||
            (tag.count >= 2 && tag[0] == "e" && !tags.contains { $0[0] == "e" && $0.count >= 4 && $0[3] == "root" })
        }
    }
}