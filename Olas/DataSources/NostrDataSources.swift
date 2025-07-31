import Foundation
import NDKSwift
import NDKSwiftUI
import SwiftUI
import Combine

// MARK: - Type Aliases for Compatibility

typealias UserProfileDataSource = NDKUIUserProfileDataSource

// MARK: - Image Feed Data Source

/// Data source for image posts (kind 1 with image tags) - uses NDKEventDataSource
@MainActor
public class ImageFeedDataSource: ObservableObject {
    @Published public private(set) var posts: [NDKEvent] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let eventDataSource: NDKEventDataSource
    
    public init(ndk: NDK, authors: [String]? = nil, limit: Int = 50) {
        var filter = NDKFilter(kinds: [EventKind.textNote])
        filter.authors = authors
        filter.limit = limit
        
        self.eventDataSource = NDKEventDataSource(ndk: ndk, filter: filter)
        
        // Filter for events with image tags
        eventDataSource.$events
            .map { events in
                events.filter { event in
                    event.tags.contains { tag in
                        tag.count >= 2 && (tag[0] == "imeta" || 
                        (tag[0] == "r" && Self.isImageURL(tag[1])))
                    }
                }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$posts)
        
        eventDataSource.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        eventDataSource.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }
    
    private static func isImageURL(_ url: String) -> Bool {
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp"]
        return imageExtensions.contains { url.lowercased().hasSuffix($0) }
    }
}

// MARK: - Hashtag Feed Data Source

/// Data source for posts with specific hashtags - uses NDKEventDataSource
@MainActor
public class HashtagFeedDataSource: ObservableObject {
    @Published public private(set) var posts: [NDKEvent] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let eventDataSource: NDKEventDataSource
    
    public init(ndk: NDK, hashtag: String, limit: Int = 50) {
        let cleanHashtag = hashtag.lowercased().replacingOccurrences(of: "#", with: "")
        
        let filter = NDKFilter(
            kinds: [EventKind.textNote],
            limit: limit,
            tags: ["t": Set([cleanHashtag])]
        )
        
        self.eventDataSource = NDKEventDataSource(ndk: ndk, filter: filter)
        
        // Bind properties from NDKEventDataSource
        eventDataSource.$events
            .receive(on: DispatchQueue.main)
            .assign(to: &$posts)
        
        eventDataSource.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        eventDataSource.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }
}

// MARK: - User Posts Data Source

/// Data source for a specific user's posts - uses NDKEventDataSource
@MainActor
public class UserPostsDataSource: ObservableObject {
    @Published public private(set) var posts: [NDKEvent] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let eventDataSource: NDKEventDataSource
    private let includeReplies: Bool
    
    public init(ndk: NDK, pubkey: String, includeReplies: Bool = false) {
        self.includeReplies = includeReplies
        
        let filter = NDKFilter(
            authors: [pubkey],
            kinds: [EventKind.textNote]
        )
        
        self.eventDataSource = NDKEventDataSource(ndk: ndk, filter: filter)
        
        // Filter based on reply status and image content
        eventDataSource.$events
            .map { [includeReplies] events in
                events.filter { event in
                    // Filter replies if needed
                    if !includeReplies && event.isReply {
                        return false
                    }
                    
                    // Filter for events with images
                    return event.tags.contains { tag in
                        tag.count >= 2 && (tag[0] == "imeta" || 
                        (tag[0] == "r" && Self.isImageURL(tag[1])))
                    }
                }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$posts)
        
        eventDataSource.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        eventDataSource.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }
    
    private static func isImageURL(_ url: String) -> Bool {
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp"]
        return imageExtensions.contains { url.lowercased().hasSuffix($0) }
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