import SwiftUI
import NDKSwift
import Observation

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    // UI state
    @Published var selectedTab = 0
    @Published var isCreatingPost = false
    @Published var selectedImage: Data?
    @Published var replyingTo: NDKEvent?
    
    // Reference to NostrManager for auth and wallet operations
    weak var nostrManager: NostrManager?
    
    // Computed properties for clean access
    var isAuthenticated: Bool { nostrManager?.authManager?.isAuthenticated ?? false }
    var currentUser: NDKUser? { 
        guard let pubkey = nostrManager?.authManager?.activeSession?.pubkey else { return nil }
        return NDKUser(pubkey: pubkey)
    }
    
    func setNostrManager(_ manager: NostrManager) {
        self.nostrManager = manager
    }
    
    func reset() {
        selectedImage = nil
        replyingTo = nil
        isCreatingPost = false
    }
}